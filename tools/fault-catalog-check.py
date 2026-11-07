#!/usr/bin/env python3
"""fault-catalog-check — валидация каталога отказов и вердиктов аудита по нему.

Каталог отказов (`audit/fault-catalog/*.yaml`) — версионируемый чек-лист
известных классов дефектов по домену (security/contract/ui/data). Он отвечает на
вопрос «ЧТО обязано быть проверено». Аудит обязан вынести вердикт по каждому
пункту; неразобранный пункт — не «пропущено», а gap.

Канарейка (`--canary-root`, см. tools/audit-canary-check.py) отвечает на другой
вопрос — «ЛОВИТ ли проверяющий вообще» — и здесь линкуется через `canary_ref`.

Формат записи каталога:
  - id: UI-WIRE-CASING
    domain: ui
    title: "Wire snake_case не смаплен в camelCase → undefined-поля"
    detect: "cd nexus-ui && npx vitest run src/__tests__/contract-adapter.test.tsx"
    severity: high            # low|medium|high|critical
    canary_ref: "audit/canaries/patches/ui-wire-casing.patch"   # optional
    source: "F186 E8181, escaped 2026-10-10"                    # optional

Вердикты (JSON): {"<id>": {"verdict": "covered|gap|na",
                           "evidence": "<команда/файл:строка>",
                           "justification": "<обязательно для na/gap>"}}
  * covered — пункт проверен, дефекта нет;
  * gap     — дефект/непокрытие; прогон НЕ проходит;
  * na      — неприменимо к фиче (требует justification).

Режимы:
  --mode validate   схема, уникальность id, домен ∈ {security,contract,ui,data},
                    severity ∈ enum, (опц.) существование canary_ref-файлов.
  --mode verdicts   для каждого id каталога есть вердикт; gap/na-без-обоснования
                    => fail; --require-evidence требует evidence у covered.

Выход: 0 = pass, 1 = fail, 2 = ошибка использования/IO.
"""
from __future__ import annotations

import re
import argparse
import glob
import hashlib
import json
import os
import shlex
import shutil
import subprocess
import sys
import tempfile

try:
    import yaml  # type: ignore
except Exception:  # pragma: no cover
    yaml = None

DOMAINS = {"security", "contract", "ui", "data"}
SEVERITIES = {"low", "medium", "high", "critical"}
REQUIRED_FIELDS = ("id", "domain", "title", "detect", "severity")


def _die(msg: str, code: int = 2) -> int:
    print(f"fault-catalog-check: ERROR: {msg}", file=sys.stderr)
    return code


def _catalog_files(path: str):
    if os.path.isdir(path):
        return sorted(glob.glob(os.path.join(path, "*.yaml")) + glob.glob(os.path.join(path, "*.yml")))
    return [path]


def _load_catalog(path: str):
    if yaml is None:
        raise RuntimeError("PyYAML недоступен (нужен для чтения каталога)")
    files = _catalog_files(path)
    # Вакуумный проход запрещён: отсутствующий/пустой каталог — это НЕ «всё покрыто».
    # Иначе app-репо без audit/fault-catalog молча получал зелёный gate-fault-catalog.
    if not files:
        raise ValueError(f"каталог отказов не найден или пуст: {path}")
    entries = []
    for f in files:
        with open(f, "r", encoding="utf-8") as fh:
            doc = yaml.safe_load(fh) or []
        if not isinstance(doc, list):
            raise ValueError(f"{f}: корень должен быть списком записей")
        for e in doc:
            entries.append((f, e))
    if not entries:
        raise ValueError(f"каталог отказов пуст (нет ни одной записи): {path}")
    return entries


def _validate_entries(entries, repo_root, check_canary):
    errors = []
    seen = set()
    for f, e in entries:
        where = f"{f}:{e.get('id', '?') if isinstance(e, dict) else '?'}"
        if not isinstance(e, dict):
            errors.append(f"{f}: запись не объект")
            continue
        for k in REQUIRED_FIELDS:
            if not e.get(k):
                errors.append(f"{where}: missing field '{k}'")
        eid = e.get("id")
        if eid:
            if eid in seen:
                errors.append(f"{where}: duplicate id")
            seen.add(eid)
        if e.get("domain") not in DOMAINS:
            errors.append(f"{where}: domain '{e.get('domain')}' not in {sorted(DOMAINS)}")
        if e.get("severity") not in SEVERITIES:
            errors.append(f"{where}: severity '{e.get('severity')}' not in {sorted(SEVERITIES)}")
        if check_canary and e.get("canary_ref"):
            ref = os.path.join(repo_root, e["canary_ref"]) if repo_root else e["canary_ref"]
            if not os.path.exists(ref):
                errors.append(f"{where}: canary_ref not found: {e['canary_ref']}")
    return errors, seen


def cmd_validate(args) -> int:
    if yaml is None:
        return _die("PyYAML не установлен — установите pyyaml")
    try:
        entries = _load_catalog(args.catalog)
    except (OSError, ValueError, RuntimeError) as exc:
        return _die(str(exc))
    errors, ids = _validate_entries(entries, args.repo_root, args.check_canary)
    fields = {"catalog": args.catalog, "entries": len(entries), "unique_ids": len(ids)}
    if errors:
        fields["errors"] = len(errors)
    ok = not errors
    if args.json:
        print(json.dumps({"mode": "validate", "ok": ok, **fields, "error_list": errors}, ensure_ascii=False, sort_keys=True))
    else:
        print(f"fault-catalog[validate] {'PASS' if ok else 'FAIL'}: " +
              ", ".join(f"{k}={v}" for k, v in fields.items()))
        for err in errors:
            print(f"  - {err}")
    return 0 if ok else 1


def cmd_verdicts(args) -> int:
    if yaml is None:
        return _die("PyYAML не установлен — установите pyyaml")
    try:
        entries = _load_catalog(args.catalog)
    except (OSError, ValueError, RuntimeError) as exc:
        return _die(str(exc))
    _, ids = _validate_entries(entries, args.repo_root, False)

    verdicts = {}
    if args.verdicts:
        try:
            with open(args.verdicts, "r", encoding="utf-8") as fh:
                verdicts = json.load(fh)
        except (OSError, json.JSONDecodeError) as exc:
            return _die(f"verdicts: {exc}")

    errors = []
    for eid in sorted(ids):
        v = verdicts.get(eid)
        if not isinstance(v, dict) or not v.get("verdict"):
            errors.append(f"{eid}: no verdict")
            continue
        verdict = v["verdict"]
        if verdict not in {"covered", "gap", "na"}:
            errors.append(f"{eid}: verdict '{verdict}' not in covered|gap|na")
            continue
        if verdict == "gap":
            errors.append(f"{eid}: gap (unresolved defect)")
        if verdict in {"na", "gap"} and not v.get("justification"):
            errors.append(f"{eid}: verdict '{verdict}' requires justification")
        if verdict == "covered" and args.require_evidence and not v.get("evidence"):
            errors.append(f"{eid}: covered requires evidence")
        if verdict == "covered" and getattr(args, "require_proof", False):
            # F13: проверяем НАЛИЧИЕ ключа detector_exit (0 — валидное доказательство), не truthiness
            if not (("detector_exit" in v) or v.get("proof_run_id") or v.get("proof") or ("exit" in v)):
                errors.append(f"{eid}: covered requires proof (proof_run_id/detector_exit) — иначе вердикт на суждении")

    covered = sum(1 for v in verdicts.values() if isinstance(v, dict) and v.get("verdict") == "covered")
    gaps = sum(1 for v in verdicts.values() if isinstance(v, dict) and v.get("verdict") == "gap")
    ok = not errors
    fields = {"catalog": args.catalog, "items": len(ids),
              "covered": covered, "gaps": gaps, "verdicts_file": args.verdicts or "-"}
    if args.json:
        print(json.dumps({"mode": "verdicts", "ok": ok, **fields, "error_list": errors}, ensure_ascii=False, sort_keys=True))
    else:
        print(f"fault-catalog[verdicts] {'PASS' if ok else 'FAIL'}: " +
              ", ".join(f"{k}={v}" for k, v in fields.items()))
        for err in errors:
            print(f"  - {err}")
    return 0 if ok else 1


NOT_EXECUTED_MARKERS = (
    "no tests to run", "no test files", "no test files found",
    "no tests found", "no test suites found", "0 tests", "0 passed",
    "collected 0 items", "[no tests to run]",
)
_GO_SKIP_RE = re.compile(r"---\s*SKIP")
_GO_PASS_RE = re.compile(r"---\s*PASS")


def _not_executed(out: str) -> bool:
    """True, если тест фактически НЕ исполнялся (false-pass оракула).

    Помимо жёстких маркеров (no tests to run) ловит go-случай «явный SKIP и ни
    одного PASS» — иначе t.Skip при отсутствии DSN/контейнера даёт exit 0 + '--- SKIP'.
    """
    low = (out or "").lower()
    if any(m in low for m in NOT_EXECUTED_MARKERS):
        return True
    if _GO_SKIP_RE.search(out or "") and not _GO_PASS_RE.search(out or ""):
        return True
    return False


def _run_detect(cmd: str, cwd: str, env, timeout: int):
    import subprocess
    try:
        p = subprocess.run(["bash", "-c", cmd], cwd=cwd, env=env,
                           capture_output=True, text=True, timeout=timeout)
        return p.returncode, (p.stdout or "") + (p.stderr or "")
    except subprocess.TimeoutExpired as exc:
        out = exc.stdout if isinstance(exc.stdout, str) else ""
        return 124, f"TIMEOUT after {timeout}s\n{out}"
    except OSError as exc:
        return 127, f"spawn error: {exc}"


# ── gate-sandbox (E8267) ─────────────────────────────────────────────────────
# The gate command runs from the pinned gate-tools bundle (ORC_GATE_TOOLS_ROOT),
# but `detect` strings come from the product fault catalog and may reference
# `tools/...` paths plus package-script deps (vitest) that a fresh eval worktree
# does not have. The sandbox:
#   • pins `tools/<script>` tokens to the bundle copy (product tools/** is never
#     modified, the bundle copy is the verification plane);
#   • fail-closes on a missing tool instead of reporting a generic detector fail;
#   • installs the UI package deps a detector needs (npm ci, idempotent);
#   • rebuilds the generated UI graph into a temp file from its sources, so the
#     canonical check runs on a canonical artifact (E8267: checked-in UI-GRAPH.yaml
#     was corrupt while skeleton+detail were valid).
SANDBOX_TOOL_ROOT_ENV = "ORC_GATE_TOOLS_ROOT"
SANDBOX_DEFAULT_TOOL_ROOT = "/opt/gate-tools/tools"
SANDBOX_UI_GRAPH_MARKERS = ("tools/ui-graph/check.py", "tools/ui-graph/build.py")
SANDBOX_TOOL_RE = re.compile(r"\b(python3|python|bash|sh|git|go|node|npm|npx)\b")
SANDBOX_CD_RE = re.compile(r"(?:^|&&|;)\s*cd\s+([^\s&;]+)\s*(?:&&|;)")
SANDBOX_TOOLS_TOKEN_RE = re.compile(r"(?<![\w./~-])tools/([A-Za-z0-9_./-]+)")


def _sandbox_tool_root() -> str:
    root = (os.environ.get(SANDBOX_TOOL_ROOT_ENV) or "").strip()
    if root and os.path.isdir(root):
        return root
    if os.path.isdir(SANDBOX_DEFAULT_TOOL_ROOT):
        return SANDBOX_DEFAULT_TOOL_ROOT
    return ""


def _sandbox_missing_tools(commands, env) -> list[str]:
    required = set()
    for cmd in commands:
        required.update(m.group(1) for m in SANDBOX_TOOL_RE.finditer(cmd or ""))
    # A package-script detector needs the whole Node toolchain, not just the
    # binary that happens to appear in the command string (node/npx are used by
    # package scripts and by npx-style detectors).
    if required & {"npm", "npx", "node"}:
        required.update({"node", "npm", "npx"})
    return sorted(t for t in required if shutil.which(t, path=env.get("PATH")) is None)


def _package_has_vitest(pkg_dir: str) -> bool:
    if os.path.isfile(os.path.join(pkg_dir, "node_modules", ".bin", "vitest")):
        return True
    try:
        with open(os.path.join(pkg_dir, "package.json"), "r", encoding="utf-8") as fh:
            data = json.load(fh)
    except (OSError, ValueError):
        return False
    scripts = data.get("scripts") or {}
    if "vitest" in str(scripts.get("test", "")):
        return True
    return "vitest" in (data.get("devDependencies") or {})


def _sandbox_ui_dirs(commands, repo_root: str) -> list[str]:
    dirs: list[str] = []
    for cmd in commands:
        for m in SANDBOX_CD_RE.finditer(cmd or ""):
            rel = m.group(1).strip().strip("'\"")
            if not rel or rel.startswith("-"):
                continue
            path = os.path.normpath(os.path.join(repo_root, rel))
            if os.path.isfile(os.path.join(path, "package.json")) and path not in dirs:
                dirs.append(path)
    if not dirs and any(re.search(r"\b(npm|npx|node)\b", c or "") for c in commands):
        for name in ("nexus-ui", "frontend", "web", "app", "ui"):
            path = os.path.normpath(os.path.join(repo_root, name))
            if os.path.isfile(os.path.join(path, "package.json")) and _package_has_vitest(path):
                dirs.append(path)
    return dirs


def _sandbox_ensure_ui_deps(dirs, env, timeout: int) -> str:
    for path in dirs:
        if not _package_has_vitest(path):
            continue
        if os.path.isfile(os.path.join(path, "node_modules", ".bin", "vitest")):
            continue
        # ORC links the clone's gitignored node_modules into the eval worktree
        # (linkEvalSideDeps). Writing through that link would mutate the shared
        # clone and race other executions; the sandbox owns a real dir instead.
        node_modules = os.path.join(path, "node_modules")
        if os.path.islink(node_modules):
            try:
                os.unlink(node_modules)
            except OSError as exc:
                return f"cannot detach shared node_modules symlink {node_modules}: {exc}"
        has_lock = os.path.isfile(os.path.join(path, "package-lock.json"))
        cmd = ["npm", "ci", "--no-audit", "--no-fund", "--prefer-offline"]
        if not has_lock:
            cmd = ["npm", "install", "--no-audit", "--no-fund", "--prefer-offline"]
        try:
            p = subprocess.run(cmd, cwd=path, env=env, capture_output=True, text=True, timeout=timeout)
        except subprocess.TimeoutExpired:
            return f"ui deps timeout after {timeout}s in {path}"
        except OSError as exc:
            return f"ui deps spawn error in {path}: {exc}"
        if p.returncode != 0:
            tail = ((p.stdout or "") + (p.stderr or ""))[-2000:]
            return f"ui deps install failed in {path} (exit {p.returncode}): {tail}"
    return ""


def _sandbox_pin_tools(cmd: str, root: str) -> str:
    if not root:
        return cmd

    def repl(m):
        rel = m.group(1)
        candidate = os.path.join(root, rel)
        if os.path.isfile(candidate):
            return candidate
        return m.group(0)

    return SANDBOX_TOOLS_TOKEN_RE.sub(repl, cmd)


def _sandbox_prepare_ui_graph(repo_root: str, tool_root: str, env, timeout: int):
    if tool_root:
        build = os.path.join(tool_root, "ui-graph", "build.py")
        check = os.path.join(tool_root, "ui-graph", "check.py")
    else:
        build = os.path.join(repo_root, "tools", "ui-graph", "build.py")
        check = os.path.join(repo_root, "tools", "ui-graph", "check.py")
    if not os.path.isfile(build):
        return None, f"missing UI-graph build tool {build} (fail-close)"
    if not os.path.isfile(check):
        return None, f"missing UI-graph check tool {check} (fail-close)"
    gen_env = dict(env)
    gen_env["ORC_GATE_ROOT"] = repo_root
    try:
        p = subprocess.run([sys.executable, build, "--stdout"], cwd=repo_root,
                           env=gen_env, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return None, f"UI-graph build timeout after {timeout}s"
    except OSError as exc:
        return None, f"UI-graph build spawn error: {exc}"
    if p.returncode != 0:
        tail = ((p.stdout or "") + (p.stderr or ""))[-2000:]
        return None, f"UI-graph build failed (exit {p.returncode}): {tail}"
    fd, path = tempfile.mkstemp(prefix="ui-graph-", suffix=".yaml")
    with os.fdopen(fd, "w", encoding="utf-8") as fh:
        fh.write(p.stdout or "")
    return (check, path), ""


def cmd_execute(args) -> int:
    """Реально исполняет `detect` каждого пункта каталога (а не верит вердикту).

    Провал, если detect не проходит ИЛИ тест фактически не выполнялся
    (`no tests to run` — false-pass build-tagged/skip). Опц. пишет proof-артефакт.
    """
    if yaml is None:
        return _die("PyYAML не установлен — установите pyyaml")
    try:
        entries = _load_catalog(args.catalog)
    except (OSError, ValueError, RuntimeError) as exc:
        return _die(str(exc))
    _, ids = _validate_entries(entries, args.repo_root, False)

    env = dict(os.environ)
    # PATH для детекторов: в образе ORC go/npx лежат вне PATH (go — /usr/local/go/bin),
    # из-за чего 'go test' давал exit 1 и детекторы ложно «падали» (инцидент E8141).
    _extra_paths = ("/usr/local/go/bin", "/usr/lib/go/bin", os.path.expanduser("~/go/bin"))
    for _p in _extra_paths:
        if os.path.isdir(_p) and _p not in (env.get("PATH") or ""):
            env["PATH"] = _p + os.pathsep + (env.get("PATH") or "")
    if args.dsn_env and not env.get("TEST_DATABASE_URL") and env.get(args.dsn_env):
        env["TEST_DATABASE_URL"] = env[args.dsn_env]

    verdicts = {}
    if getattr(args, "verdicts", None):
        try:
            with open(args.verdicts, "r", encoding="utf-8") as fh:
                verdicts = json.load(fh)
        except (OSError, ValueError) as exc:
            return _die(f"verdicts: {exc}")

    # app-режим (явная декларация audit.oracles в контракте проекта): для covered-классов
    # гоняем oracle проекта, а не платформенный detect (nexus/findings в app-репо нет).
    oracles = {}
    if getattr(args, "oracles", ""):
        try:
            _o = json.loads(args.oracles)
            oracles = _o if isinstance(_o, dict) else {}
        except ValueError as exc:
            return _die(f"oracles: invalid JSON: {exc}")

    sandbox_tool_root = ""
    ui_graph = None
    sandbox_info = {}
    if getattr(args, "sandbox", False):
        detects = [
            (oracles.get(e.get("id")) or e.get("detect") or "").strip()
            for _f, e in entries
            if isinstance(e, dict)
            and (oracles.get(e.get("id")) or e.get("detect") or "").strip()
            and (verdicts.get(e.get("id")) or {}).get("verdict") != "na"
        ]
        missing = _sandbox_missing_tools(detects, env)
        if missing:
            print("fault-catalog[sandbox] FAIL — missing tool(s): "
                  + ", ".join(missing) + " (fail-close, no na)", file=sys.stderr)
            return 1
        sandbox_tool_root = _sandbox_tool_root()
        ui_dirs = _sandbox_ui_dirs(detects, args.repo_root)
        derr = _sandbox_ensure_ui_deps(ui_dirs, env, args.timeout)
        if derr:
            print(f"fault-catalog[sandbox] FAIL — {derr}", file=sys.stderr)
            return 1
        if any(any(marker in c for marker in SANDBOX_UI_GRAPH_MARKERS) for c in detects):
            ui_graph, gerr = _sandbox_prepare_ui_graph(args.repo_root, sandbox_tool_root, env, args.timeout)
            if gerr:
                print(f"fault-catalog[sandbox] FAIL — {gerr}", file=sys.stderr)
                return 1
        sandbox_info = {
            "tools_root": sandbox_tool_root or "<repo>",
            "ui_packages": [os.path.relpath(p, args.repo_root) for p in ui_dirs],
            "ui_graph_rebuilt": bool(ui_graph),
        }

    errors, results, skipped_na = [], [], []
    for f, e in entries:
        eid = e.get("id")
        v = verdicts.get(eid) or {}
        if v.get("verdict") == "na":
            results.append({"id": eid, "status": "skipped_na",
                            "justification": v.get("justification", "")})
            skipped_na.append({"id": eid, "justification": v.get("justification", "")})
            continue
        _oracle = (oracles.get(eid) or "").strip()
        detect = _oracle or (e.get("detect") or "").strip()
        if not detect:
            errors.append(f"{eid}: empty detect/oracle")
            results.append({"id": eid, "status": "error", "reason": "empty detect/oracle"})
            continue
        if "{run_id}" in detect and not args.run_id:
            errors.append(f"{eid}: detect needs {{run_id}} but --run-id missing")
            results.append({"id": eid, "status": "needs-run-id"})
            continue
        if str(e.get("kind", "")).strip().lower() == "static":
            results.append({"id": eid, "status": "static", "kind": "static",
                            "detect": detect.strip()})
            continue
        cmd = detect.replace("{run_id}", args.run_id or "")
        if getattr(args, "sandbox", False):
            cmd = _sandbox_pin_tools(cmd, sandbox_tool_root)
            if ui_graph and any(marker in detect for marker in SANDBOX_UI_GRAPH_MARKERS):
                check, graph = ui_graph
                cmd = f"{shlex.quote(sys.executable)} {shlex.quote(check)} --file {shlex.quote(graph)}"
        rc, out = _run_detect(cmd, args.repo_root, env, args.timeout)
        ne = _not_executed(out)
        if rc == 127:
            status = "missing-tool"
            errors.append(f"{eid}: detector tool missing (exit 127) — gate-sandbox fail-close")
        elif rc != 0:
            status = f"exit{rc}"
            errors.append(f"{eid}: detect failed (exit {rc})")
        elif ne:
            status = "not-executed"
            errors.append(f"{eid}: detect НЕ выполнялся ('no tests to run') — оракул слеп")
        else:
            status = "ok"
        results.append({"id": eid, "status": status, "exit": rc, "detect": cmd,
                        "stdout_sha256": hashlib.sha256((out or "").encode("utf-8", "ignore")).hexdigest()[:16]})

    if args.proof_out:
        payload = {"mode": "execute", "ok": not errors, "results": results, "skipped_na": skipped_na}
        if sandbox_info:
            payload["sandbox"] = sandbox_info
        try:
            with open(args.proof_out, "w", encoding="utf-8") as fh:
                json.dump(payload, fh, ensure_ascii=False, indent=2)
        except OSError as exc:
            return _die(f"proof-out: {exc}")

    ok = not errors
    fields = {"catalog": args.catalog, "items": len(ids), "executed": len(results)}
    if args.json:
        print(json.dumps({"mode": "execute", "ok": ok, **fields, "results": results, "error_list": errors},
                         ensure_ascii=False, sort_keys=True))
    else:
        print(f"fault-catalog[execute] {'PASS' if ok else 'FAIL'}: " +
              ", ".join(f"{k}={v}" for k, v in fields.items()))
        for r in results:
            print(f"  {r['id']}: {r.get('status')}")
        for err in errors:
            print(f"  - {err}")
    return 0 if ok else 1


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="Fault-catalog validate/verdicts/execute gate (ADR-KIT-090)")
    p.add_argument("--mode", required=True, choices=["validate", "verdicts", "execute"])
    p.add_argument("--catalog", default="audit/fault-catalog",
                   help="файл или каталог каталога отказов (default audit/fault-catalog)")
    p.add_argument("--verdicts", default=None, help="JSON с вердиктами по id")
    p.add_argument("--repo-root", default=".", help="корень для проверки canary_ref")
    p.add_argument("--check-canary", action="store_true", help="проверять существование canary_ref")
    p.add_argument("--require-evidence", action="store_true", help="covered обязан иметь evidence")
    p.add_argument("--require-proof", action="store_true",
                   help="covered обязан иметь proof (proof_run_id/detector_exit) — вердикт не на суждении")
    p.add_argument("--run-id", default=None, help="значение для {run_id} в detect (mode=execute)")
    p.add_argument("--dsn-env", default=None,
                   help="имя env-переменной с DSN стенда; копируется в TEST_DATABASE_URL при её отсутствии")
    p.add_argument("--sandbox", action="store_true",
                   help="gate-sandbox: pinned tools, fail-close on missing tool, UI deps, UI-graph rebuild")
    p.add_argument("--oracles", default="",
                   help="JSON {catalog_id: command} — app-оракулы для covered-классов (app-режим)")
    p.add_argument("--timeout", type=int, default=300, help="таймаут одного detect, сек (mode=execute)")
    p.add_argument("--proof-out", default=None, help="куда записать proof-артефакт execute (JSON)")
    p.add_argument("--json", action="store_true")
    return p


def main(argv=None) -> int:
    args = build_parser().parse_args(argv)
    if args.mode == "validate":
        return cmd_validate(args)
    if args.mode == "execute":
        return cmd_execute(args)
    return cmd_verdicts(args)


if __name__ == "__main__":
    sys.exit(main())
