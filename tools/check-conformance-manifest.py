#!/usr/bin/env python3
"""AC-CONF-ONE-OWNER oracle: validate orc/conformance/manifest.json (U02/S2).

The manifest is the single source of truth for T-01..T-29 ownership:

  * exactly one entry per T-ID; no duplicates;
  * one owning file per T and layer↔owner_file consistency;
  * the referenced test function exists in the owning file and nowhere else
    (no double ownership — T-17/T-28 belong to deploy-smoke.sh only);
  * green requires executed>0; red requires owning_unit + reason;
  * `status: skip` is rejected in every mode (SKIP is never a pass, ADR-3.2-04 D2).

Modes:
  --local    structural validation; red-baseline (annotated) accepted.
  --release  release-profile validation; the default CI/release check.
             A red T is accepted only as an explicit red-baseline annotation
             (owning_unit + reason); `--final` forbids red entirely.
  --final    final release gate (U17): every T green and executed>0.

  --run      additionally executes `go test -json` for the Go layers and
             reconciles real actions (pass/fail/skip/no-tests) with the
             manifest. A green entry that skipped or did not run is an error.
             Set ORC_CONFORMANCE_REPORT=<path> to persist the run report.

Exit codes: 0 = valid, 1 = violations, 2 = usage/IO error.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Sequence, Tuple

EXPECTED_IDS = [f"T-{i:02d}" for i in range(1, 30)]
STATUSES = {"green", "red"}
LAYERS = {"orc", "archd", "deploy"}

# layer -> allowed owner specs (owner, owner_file, package, ref_kind).
#
# ADR-3.2-04 D1 keeps T-18/T-19/T-26 as Go contracts in orc/conformance even
# though their layer is deploy: deploy-smoke.sh is the release companion for
# T-17/T-28 only and must not be declared as the owner of a Go oracle. The
# checker therefore accepts two deploy specs and keeps their test_ref disjoint.
OWNER_SPECS = {
    "orc": [
        ("orc/conformance", "orc/conformance/conformance_test.go", "orc/conformance", "go"),
    ],
    "archd": [
        ("archd/integration", "archd/integration/project_scope_test.go", "archd/integration", "go"),
    ],
    "deploy": [
        ("orc/conformance", "orc/conformance/conformance_test.go", "orc/conformance", "go"),
        ("deploy-smoke", "orc/conformance/deploy-smoke.sh", "orc/conformance", "smoke"),
    ],
}

# deploy-smoke owns exactly these T (T-17/T-28); Go deploy-layer contracts stay
# in orc/conformance (ADR-3.2-04 D1).
DEPLOY_SMOKE_IDS = {"T-17", "T-28"}

GO_REF_RE = re.compile(
    r"^cmd:go test \./(?P<pkg>[A-Za-z0-9_./-]+) -run '(?P<pattern>[^']+)' -count=1$"
)
DEPLOY_REF_RE = re.compile(
    r"^cmd:bash orc/conformance/deploy-smoke\.sh --release -run 'T-17\|T-28'$"
)
FUNC_RE = re.compile(r"^func (?P<name>[A-Za-z0-9_]+)\(t \*testing\.T\) \{$", re.MULTILINE)


class Violations:
    def __init__(self) -> None:
        self.items: List[str] = []

    def add(self, msg: str) -> None:
        self.items.append(msg)

    def extend(self, msgs: Iterable[str]) -> None:
        self.items.extend(msgs)

    def __bool__(self) -> bool:
        return bool(self.items)

    def report(self, prefix: str) -> None:
        for item in self.items:
            print(f"{prefix}: {item}", file=sys.stderr)


def _read_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        raise SystemExit(f"manifest not found: {path}")
    except json.JSONDecodeError as exc:
        raise SystemExit(f"manifest is not valid JSON: {path}: {exc}")


def _test_functions(path: Path) -> set[str]:
    if not path.is_file():
        return set()
    return set(FUNC_RE.findall(path.read_text(encoding="utf-8", errors="replace")))


def _candidate_test_files(repo_root: Path) -> List[Path]:
    files: List[Path] = []
    for pattern in ("orc/conformance/*_test.go", "archd/integration/*_test.go"):
        files.extend(sorted(repo_root.glob(pattern)))
    return files


def _owner_spec(
    tid: str, entry: Dict[str, Any], layer: str, v: Violations
) -> Tuple[str, str, str, str]:
    """Resolve the owner spec for a layer/owner pair (ADR-3.2-04 D1).

    Returns (owner, owner_file, package, ref_kind); ref_kind is "go" or "smoke".
    Unknown owners fall back to the first spec so the caller still reports the
    precise owner_file/package mismatch instead of guessing silently.
    """
    specs = OWNER_SPECS[layer]
    declared = entry.get("owner")
    for spec in specs:
        if declared == spec[0]:
            return spec
    allowed = ", ".join(spec[0] for spec in specs)
    v.add(f"{tid}: owner = {declared!r} is not allowed for layer {layer} (want one of {allowed})")
    return specs[0]


def _go_ref(entry: Dict[str, Any], v: Violations) -> Optional[Tuple[str, str]]:
    """Return (package, test_name) for a Go test_ref, or None."""
    tid = entry.get("id", "?")
    ref = entry.get("test_ref", "")
    m = GO_REF_RE.match(ref)
    if not m:
        v.add(f"{tid}: test_ref is not a canonical `cmd:go test ./<pkg> -run '<name>' -count=1`: {ref!r}")
        return None
    pattern = m.group("pattern")
    name = pattern.lstrip("^").rstrip("$")
    if not name.startswith("Test"):
        v.add(f"{tid}: test_ref -run pattern does not select a Go test function: {pattern!r}")
        return None
    return m.group("pkg"), name


def validate(
    data: Any,
    repo_root: Path,
    mode: str,
    expected_ids: Sequence[str],
    check_refs: bool = True,
) -> Violations:
    """Validate a parsed manifest. Returns all violations (never raises)."""
    v = Violations()
    if not isinstance(data, dict):
        v.add("manifest root must be an object")
        return v
    version = str(data.get("version", ""))
    if not version.startswith("0.2."):
        v.add(f"manifest version = {version!r}, want 0.2.x")
    tests = data.get("tests")
    if not isinstance(tests, list):
        v.add("manifest.tests must be a list")
        return v

    seen_ids: Dict[str, int] = {}
    seen_refs: Dict[str, str] = {}
    candidates = _candidate_test_files(repo_root) if check_refs else []

    for idx, entry in enumerate(tests):
        where = f"tests[{idx}]"
        if not isinstance(entry, dict):
            v.add(f"{where}: entry must be an object")
            continue
        tid = entry.get("id")
        if not isinstance(tid, str) or not tid:
            v.add(f"{where}: missing id")
            continue
        seen_ids[tid] = seen_ids.get(tid, 0) + 1
        if seen_ids[tid] > 1:
            v.add(f"{tid}: duplicate T-ID (owner/entry defined more than once)")

        layer = entry.get("layer")
        if layer not in LAYERS:
            v.add(f"{tid}: layer = {layer!r}, want one of {sorted(LAYERS)}")
            continue

        owner, owner_file, package, ref_kind = _owner_spec(tid, entry, layer, v)
        if ref_kind == "smoke" and tid not in DEPLOY_SMOKE_IDS:
            v.add(
                f"{tid}: deploy-smoke owns only {sorted(DEPLOY_SMOKE_IDS)}; "
                f"Go deploy-layer contracts (T-18/T-19/T-26) belong to orc/conformance"
            )
        if not isinstance(entry.get("owner"), str) or not entry.get("owner", "").strip():
            v.add(f"{tid}: owner is required")
        if entry.get("owner_file") != owner_file:
            v.add(f"{tid}: owner_file = {entry.get('owner_file')!r}, want {owner_file!r} for layer {layer}")
        if entry.get("package") != package:
            v.add(f"{tid}: package = {entry.get('package')!r}, want {package!r} for layer {layer}")
        if entry.get("owner") not in (None, owner):
            v.add(f"{tid}: owner = {entry.get('owner')!r}, want {owner!r} for layer {layer} (one owner per T)")

        invariant = entry.get("invariant")
        if not isinstance(invariant, str) or not invariant.startswith("INV-"):
            v.add(f"{tid}: invariant must be an INV-* string, got {invariant!r}")

        status = entry.get("status")
        if status not in STATUSES:
            v.add(f"{tid}: status = {status!r}, want green|red (skip is not a pass)")
            continue

        executed = entry.get("executed")
        if not isinstance(executed, int) or isinstance(executed, bool) or executed < 0:
            v.add(f"{tid}: executed must be a non-negative integer, got {executed!r}")
            executed = 0

        reason = entry.get("reason")
        owning_unit = entry.get("owning_unit")
        red_baseline = entry.get("red_baseline")
        if status == "green":
            if executed < 1:
                v.add(f"{tid}: status=green but executed={executed}; a green T must have executed>0")
            if owning_unit:
                v.add(f"{tid}: status=green must not carry owning_unit (green has no pending owner)")
            if isinstance(reason, str) and reason.strip():
                v.add(f"{tid}: status=green must not carry a pending reason")
            if red_baseline:
                v.add(f"{tid}: status=green must not carry red_baseline")
        else:  # red
            if not isinstance(owning_unit, str) or not owning_unit.strip():
                v.add(f"{tid}: status=red requires owning_unit (owning-unit annotation)")
            if not isinstance(reason, str) or not reason.strip():
                v.add(f"{tid}: status=red requires reason")
            if red_baseline is not True:
                v.add(
                    f"{tid}: status=red requires red_baseline=true — a failing T is an explicit "
                    f"recorded baseline, never an unmarked entry"
                )
            if executed == 0:
                if not isinstance(reason, str) or not reason.lower().startswith("skip:"):
                    v.add(
                        f"{tid}: red executed=0 requires an explicit `skip:` reason with the "
                        f"owner-descope (no unexplained zero)"
                    )
                if not isinstance(owning_unit, str) or not owning_unit.strip():
                    v.add(f"{tid}: red executed=0 requires owning_unit (owner-descope)")

        if mode == "final" and status != "green":
            v.add(f"{tid}: final release gate forbids red (owning unit {owning_unit or '?'})")
        if mode == "final" and executed < 1:
            v.add(f"{tid}: final release gate requires executed>0, got {executed}")

        ref = entry.get("test_ref", "")
        if not isinstance(ref, str) or not ref.strip():
            v.add(f"{tid}: test_ref is required")
            continue

        if ref_kind == "smoke":
            if not DEPLOY_REF_RE.match(ref):
                v.add(f"{tid}: deploy-smoke test_ref must run deploy-smoke.sh --release: {ref!r}")
            if check_refs and not (repo_root / "orc/conformance/deploy-smoke.sh").is_file():
                v.add(f"{tid}: owner_file orc/conformance/deploy-smoke.sh does not exist")
            continue

        parsed = _go_ref(entry, v)
        if not parsed or not check_refs:
            continue
        ref_pkg, name = parsed
        if ref_pkg != package:
            v.add(f"{tid}: test_ref package {ref_pkg!r} != owner package {package!r}")

        key = f"{ref_pkg}::{name}"
        if key in seen_refs:
            v.add(f"{tid}: test_ref {name} is already claimed by {seen_refs[key]} (one owner per oracle)")
        else:
            seen_refs[key] = tid

        owner_path = repo_root / owner_file
        if not owner_path.is_file():
            v.add(f"{tid}: owner_file {owner_file} does not exist")
            continue
        if name not in _test_functions(owner_path):
            v.add(f"{tid}: test function {name} not found in owner_file {owner_file}")
        for candidate in candidates:
            if candidate == owner_path:
                continue
            if name in _test_functions(candidate):
                v.add(
                    f"{tid}: double ownership — {name} also exists in "
                    f"{candidate.relative_to(repo_root)} (owner is {owner_file})"
                )

    expected = set(expected_ids)
    missing = sorted(expected - set(seen_ids))
    extra = sorted(set(seen_ids) - expected)
    for tid in missing:
        v.add(f"{tid}: missing from manifest (completeness)")
    for tid in extra:
        v.add(f"{tid}: unexpected T-ID (not part of T-01..T-29)")

    return v


# ── --run: reconcile the manifest with a real go test -json run ──────────────


def _run_go_tests(repo_root: Path) -> Tuple[Dict[str, Dict[str, str]], List[str]]:
    """Run the Go conformance layers and return {test: {pkg, action}} + errors."""
    cmd = ["go", "test", "./orc/conformance", "./archd/integration", "-json", "-count=1"]
    proc = subprocess.run(cmd, cwd=repo_root, capture_output=True, text=True)
    actions: Dict[str, Dict[str, str]] = {}
    errors: List[str] = []
    package_fail: Dict[str, str] = {}
    for line in proc.stdout.splitlines():
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            ev = json.loads(line)
        except json.JSONDecodeError:
            continue
        pkg = ev.get("Package", "")
        test = ev.get("Test", "")
        action = ev.get("Action", "")
        if test and action in {"pass", "fail", "skip"}:
            actions[test] = {"package": pkg, "action": action}
        if not test and action == "fail":
            package_fail[pkg] = ev.get("Output", "")
    if proc.returncode != 0:
        failed = sorted({p for p in package_fail if p})
        if not failed:
            errors.append(f"go test exited {proc.returncode}")
        for pkg in failed:
            detail = " ".join(package_fail[pkg].split())[:300]
            errors.append(f"package {pkg} failed: {detail}")
    return actions, errors


def reconcile(
    data: Dict[str, Any], repo_root: Path, actions: Dict[str, Dict[str, str]]
) -> Violations:
    v = Violations()
    report = {"executed": [], "skipped": [], "failed": [], "not_run": []}
    for entry in data.get("tests", []):
        tid = entry.get("id", "?")
        layer = entry.get("layer")
        status = entry.get("status")
        # deploy-smoke entries are reconciled by _deploy_smoke(); deploy-layer
        # Go contracts (T-18/T-19/T-26) run in `go test` like every other oracle.
        if layer == "deploy" and entry.get("owner") == "deploy-smoke":
            continue
        parsed = _go_ref(entry, v)
        if not parsed:
            continue
        _, name = parsed
        got = actions.get(name)
        if got is None:
            report["not_run"].append(tid)
            v.add(f"{tid}: {name} did not run (`no tests to run` / build-tag / filtered out)")
            continue
        action = got["action"]
        report[{"pass": "executed", "fail": "failed", "skip": "skipped"}[action]].append(tid)
        if status == "green" and action != "pass":
            v.add(f"{tid}: green in manifest but real action = {action} (SKIP is not a pass)")
        if status == "green" and int(entry.get("executed", 0)) < 1:
            v.add(f"{tid}: green in manifest but executed=0")
        if status == "red" and action == "pass":
            v.add(f"{tid}: red in manifest but the oracle passes — update status (no status fitting)")
        if status == "red" and action == "fail" and int(entry.get("executed", 0)) < 1:
            v.add(f"{tid}: red oracle failed but executed=0; record executed=1")
    path = os.environ.get("ORC_CONFORMANCE_REPORT")
    if path:
        Path(path).write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return v


def _deploy_smoke(repo_root: Path) -> List[str]:
    script = repo_root / "orc/conformance/deploy-smoke.sh"
    if not script.is_file():
        return ["deploy-smoke.sh is missing"]
    proc = subprocess.run(
        ["bash", str(script), "--release", "-run", "T-17|T-28"],
        cwd=repo_root,
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        detail = (proc.stderr or proc.stdout).strip().splitlines()
        return [f"deploy-smoke --release failed: {detail[-1] if detail else proc.returncode}"]
    return []


# ── --self-test: mutation fixtures for the checker itself ────────────────────


def _fixture_entry(tid: str, func: str, **overrides: Any) -> Dict[str, Any]:
    entry = {
        "id": tid,
        "layer": "orc",
        "owner": "orc/conformance",
        "owner_file": "orc/conformance/conformance_test.go",
        "package": "orc/conformance",
        "invariant": "INV-SELFTEST",
        "status": "green",
        "executed": 1,
        "test_ref": f"cmd:go test ./orc/conformance -run '^{func}$' -count=1",
        "oracle": "self-test fixture",
    }
    entry.update(overrides)
    return entry


def self_test() -> int:
    failures = 0
    cases = 0
    with tempfile.TemporaryDirectory(prefix="conf-manifest-selftest-") as tmp:
        root = Path(tmp)
        (root / "orc/conformance").mkdir(parents=True)
        (root / "archd/integration").mkdir(parents=True)
        (root / "orc/conformance/conformance_test.go").write_text(
            "package conformance\n\n"
            "func TestConformance_T01_A(t *testing.T) {\n}\n"
            "func TestConformance_T02_B(t *testing.T) {\n}\n",
            encoding="utf-8",
        )
        (root / "archd/integration/project_scope_test.go").write_text(
            "package integration\n", encoding="utf-8"
        )
        (root / "orc/conformance/deploy-smoke.sh").write_text("#!/usr/bin/env bash\n", encoding="utf-8")

        base = {
            "version": "0.2.0",
            "tests": [
                _fixture_entry("T-01", "TestConformance_T01_A"),
                _fixture_entry("T-02", "TestConformance_T02_B"),
            ],
        }

        def run(name: str, data: Any, want_error: Optional[str], mode: str = "release") -> None:
            nonlocal failures, cases
            cases += 1
            v = validate(data, root, mode, ["T-01", "T-02"])
            if want_error is None:
                if v:
                    failures += 1
                    print(f"SELFTEST FAIL [{name}]: unexpected violations: {v.items}", file=sys.stderr)
                return
            if not any(want_error in item for item in v.items):
                failures += 1
                print(
                    f"SELFTEST FAIL [{name}]: want error containing {want_error!r}, got {v.items}",
                    file=sys.stderr,
                )

        run("valid green manifest", base, None)
        run("duplicate T-ID", {"version": "0.2.0", "tests": base["tests"] + [_fixture_entry("T-01", "TestConformance_T01_A")]}, "duplicate T-ID")
        run("status skip", {"version": "0.2.0", "tests": [_fixture_entry("T-01", "TestConformance_T01_A", status="skip"), base["tests"][1]]}, "status = 'skip'")
        run("green executed=0", {"version": "0.2.0", "tests": [_fixture_entry("T-01", "TestConformance_T01_A", executed=0), base["tests"][1]]}, "executed=0")
        run("owner_file layer mismatch", {"version": "0.2.0", "tests": [_fixture_entry("T-01", "TestConformance_T01_A", layer="archd", owner_file="orc/conformance/conformance_test.go", package="archd/integration", owner="archd/integration"), base["tests"][1]]}, "owner_file =")
        run("missing test function", {"version": "0.2.0", "tests": [_fixture_entry("T-01", "TestConformance_T01_Missing"), base["tests"][1]]}, "not found in owner_file")
        run("red without owning_unit", {"version": "0.2.0", "tests": [_fixture_entry("T-01", "TestConformance_T01_A", status="red", executed=0, red_baseline=True, reason="skip: pending"), base["tests"][1]]}, "requires owning_unit")
        run("red executed=0 without skip reason", {"version": "0.2.0", "tests": [_fixture_entry("T-01", "TestConformance_T01_A", status="red", executed=0, red_baseline=True, owning_unit="U07", reason="pending"), base["tests"][1]]}, "explicit `skip:` reason")
        run("red executed=0 without red_baseline", {"version": "0.2.0", "tests": [_fixture_entry("T-01", "TestConformance_T01_A", status="red", executed=0, owning_unit="U07", reason="skip: pending"), base["tests"][1]]}, "requires red_baseline=true")
        run(
            "red executed=0 annotated baseline",
            {"version": "0.2.0", "tests": [_fixture_entry("T-01", "TestConformance_T01_A", status="red", executed=0, red_baseline=True, owning_unit="U07", reason="skip: pending fix"), base["tests"][1]]},
            None,
        )
        run("red in final gate", {"version": "0.2.0", "tests": [_fixture_entry("T-01", "TestConformance_T01_A", status="red", executed=0, red_baseline=True, owning_unit="U07", reason="skip: pending"), base["tests"][1]]}, "final release gate forbids red", mode="final")
        run("missing T-ID", {"version": "0.2.0", "tests": [base["tests"][0]]}, "missing from manifest")

        # ADR-3.2-04 D1: a deploy-layer Go contract stays in orc/conformance,
        # while deploy-smoke owns only T-17/T-28.
        deploy_go = _fixture_entry(
            "T-01", "TestConformance_T01_A",
            layer="deploy", owner="orc/conformance",
            owner_file="orc/conformance/conformance_test.go", package="orc/conformance",
        )
        run("deploy Go contract owner", {"version": "0.2.0", "tests": [deploy_go, base["tests"][1]]}, None)
        deploy_smoke = _fixture_entry(
            "T-01", "TestConformance_T01_A",
            layer="deploy", owner="deploy-smoke",
            owner_file="orc/conformance/deploy-smoke.sh", package="orc/conformance",
            test_ref="cmd:bash orc/conformance/deploy-smoke.sh --release -run 'T-17|T-28'",
        )
        run("deploy-smoke cannot own a Go T", {"version": "0.2.0", "tests": [deploy_smoke, base["tests"][1]]}, "deploy-smoke owns only")

        # Double ownership: the same test function in two candidate files.
        (root / "archd/integration/project_scope_test.go").write_text(
            "package integration\n\nfunc TestConformance_T01_A(t *testing.T) {\n}\n",
            encoding="utf-8",
        )
        run("double ownership", base, "double ownership")
        (root / "archd/integration/project_scope_test.go").unlink()

    total = cases
    if failures:
        print(f"SELFTEST: {total - failures}/{total} passed, {failures} failed", file=sys.stderr)
        return 1
    print(f"SELFTEST: {total}/{total} passed")
    return 0


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--manifest", default="orc/conformance/manifest.json")
    parser.add_argument("--repo-root", default=".")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--local", action="store_const", const="local", dest="mode")
    mode.add_argument("--release", action="store_const", const="release", dest="mode")
    mode.add_argument("--final", action="store_const", const="final", dest="mode")
    parser.add_argument("--run", action="store_true", help="execute go test -json and reconcile actions")
    parser.add_argument("--self-test", action="store_true", help="run checker mutation fixtures")
    parser.set_defaults(mode="local")
    args = parser.parse_args(argv)

    if args.self_test:
        return self_test()

    repo_root = Path(args.repo_root).resolve()
    manifest_path = (repo_root / args.manifest).resolve() if not Path(args.manifest).is_absolute() else Path(args.manifest)
    data = _read_json(manifest_path)

    v = validate(data, repo_root, args.mode, EXPECTED_IDS)
    if args.run:
        actions, run_errors = _run_go_tests(repo_root)
        v.extend(run_errors)
        v.extend(reconcile(data, repo_root, actions).items)
        v.extend(_deploy_smoke(repo_root))

    if v:
        v.report(f"FAIL[manifest:{args.mode}]")
        print(f"RESULT[manifest] mode={args.mode} status=FAIL violations={len(v.items)}", file=sys.stderr)
        return 1

    tests = data.get("tests", [])
    green = sum(1 for e in tests if e.get("status") == "green")
    red = sum(1 for e in tests if e.get("status") == "red")
    executed = sum(1 for e in tests if int(e.get("executed", 0)) > 0)
    skipped = [e.get("id", "?") for e in tests if int(e.get("executed", 0)) == 0]
    print(
        f"PASS[manifest:{args.mode}] total={len(tests)} green={green} red={red} "
        f"executed>0={executed} red_baseline_annotated={red} "
        f"executed=0_red_baseline={len(skipped)}"
    )
    if skipped:
        print(f"EXECUTED=0 (explicit red_baseline): {', '.join(skipped)}")
    print(f"RESULT[manifest] mode={args.mode} status=PASS executed={executed} green={green} red={red}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
