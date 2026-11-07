#!/usr/bin/env python3
"""path-1 design-system gates (s02a/s03/s03a/s22a/s24).

Fail-close checks for the contracts in kh_pg doc/процесс/design-system:
  ds-pin, unit-proto-coverage, unit-ds-lock, design-review (ui/ux),
  design-integrate, ds-usage, ux-audit, ds-drift.

Only structural/consistency checks; no network, no S3. Artifacts are read from
the evaluated worktree (ORC_GATE_ROOT) or --root.

Usage:
  check-design-gates.py ds-pin --root <repo> [--feature-dir <dir>]
  check-design-gates.py unit-proto-coverage --root <repo> --screen <id>
  check-design-gates.py unit-ds-lock --root <repo> --screen <id>
  check-design-gates.py design-review --root <repo> --kind ui|ux [--screen <id>]
  check-design-gates.py design-integrate --root <repo>
  check-design-gates.py ds-usage --root <repo>
  check-design-gates.py ux-audit --root <repo>
  check-design-gates.py ds-drift --root <repo> [--base <sha>]
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
from pathlib import Path

SEMVER = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+$")
SHA = re.compile(r"^sha256:[0-9a-f]{64}$")
HEX40 = re.compile(r"^[0-9a-f]{40}$")


def fail(gate: str, message: str) -> int:
    print(f"{gate}: FAIL — {message}", file=sys.stderr)
    return 1


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def load_json(path: Path, gate: str):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        raise SystemExit(fail(gate, f"не найден {path}"))
    except json.JSONDecodeError as exc:
        raise SystemExit(fail(gate, f"не JSON: {path}: {exc}"))


def resolve_feature(root: Path, explicit: str | None, gate: str) -> Path:
    if explicit:
        p = Path(explicit)
        if not p.is_absolute():
            p = root / p
        if not p.is_dir():
            raise SystemExit(fail(gate, f"feature dir не найден: {p}"))
        return p
    env = os.environ.get("ORC_FEATURE_DIR", "").strip()
    if env:
        return resolve_feature(root, env, gate)
    probes = ["ds-pin.json", "ds.lock.json", "component-refs.json", "design-impact.md", "design-gaps.json"]
    dirs = []
    for probe in probes:
        for p in root.glob(f"doc/идеи/*/{probe}"):
            d = p.parent
            if d not in dirs:
                dirs.append(d)
    if len(dirs) == 1:
        return dirs[0]
    if not dirs:
        raise SystemExit(fail(gate, "feature dir не найден (doc/идеи/<F>/ds-pin.json и др.)"))
    raise SystemExit(fail(gate, f"несколько feature dir ({len(dirs)}); задай ORC_FEATURE_DIR"))


def find_units(feature: Path, screen: str | None) -> list[Path]:
    units = feature / "units"
    if screen:
        candidates = [units / screen, units / screen.replace("/", "_")]
        for c in candidates:
            if c.is_dir():
                return [c]
        # fallback: artifact directly in feature dir with screen suffix
        return [feature]
    if units.is_dir():
        return sorted(p for p in units.iterdir() if p.is_dir())
    return [feature]


def unit_json(unit: Path, names: list[str]) -> tuple[dict | None, Path | None]:
    for name in names:
        p = unit / name
        if p.is_file():
            return json.loads(p.read_text(encoding="utf-8")), p
    return None, None


def check_ds_pin(root: Path, feature: Path, gate: str) -> list[str]:
    errs: list[str] = []
    p = feature / "ds-pin.json"
    d = load_json(p, gate)
    for key in ["schema_version", "feature_id", "artifact_path", "design_system_version", "ds_digest",
                "approved_by", "pinned_at", "fallback_used", "screens"]:
        if key not in d:
            errs.append(f"ds-pin.{key} отсутствует")
    if d.get("schema_version") != "1.0":
        errs.append("ds-pin.schema_version != 1.0")
    version = str(d.get("design_system_version", ""))
    digest = str(d.get("ds_digest", ""))
    if not SEMVER.match(version):
        errs.append("ds-pin.design_system_version не X.Y.Z (latest/dev запрещены)")
    if not SHA.match(digest):
        errs.append("ds-pin.ds_digest не sha256")
    if not isinstance(d.get("fallback_used"), bool):
        errs.append("ds-pin.fallback_used не bool")
    screens = d.get("screens")
    if not isinstance(screens, list) or not screens:
        errs.append("ds-pin.screens пуст")
        return errs
    seen = set()
    for i, s in enumerate(screens):
        for key in ["screen_id", "screen_brief", "platform", "feature_profile",
                    "design_system_version", "ds_digest"]:
            if key not in s:
                errs.append(f"ds-pin.screens[{i}].{key} отсутствует")
        sid = str(s.get("screen_id", ""))
        if not sid:
            errs.append(f"ds-pin.screens[{i}].screen_id пуст")
        elif sid in seen:
            errs.append(f"ds-pin.screens[{i}].screen_id дублируется: {sid}")
        seen.add(sid)
        if not str(s.get("screen_brief", "")).strip():
            errs.append(f"ds-pin.screens[{i}].screen_brief пуст")
        if s.get("platform") not in {"web", "mobile", "both"}:
            errs.append(f"ds-pin.screens[{i}].platform недопустим")
        if s.get("feature_profile") not in {"full", "frontend"}:
            errs.append(f"ds-pin.screens[{i}].feature_profile недопустим")
        if s.get("design_system_version") != version:
            errs.append(f"ds-pin.screens[{i}].design_system_version != верхнеуровневому")
        if s.get("ds_digest") != digest:
            errs.append(f"ds-pin.screens[{i}].ds_digest != верхнеуровневому")
    manifest = root / "design" / "releases" / version / "manifest.json"
    if not manifest.is_file():
        errs.append(f"approved DS release не найден: {manifest}")
    else:
        try:
            m = json.loads(manifest.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            errs.append(f"DS manifest не JSON: {exc}")
            return errs
        if m.get("release") != version:
            errs.append("DS manifest.release != design_system_version")
        if m.get("tag") and m.get("tag") != f"ds/v{version}":
            errs.append("DS manifest.tag != ds/v<version>")
        md = m.get("digest") or m.get("manifest_sha256") or sha256_file(manifest)
        if md != digest:
            errs.append("ds_digest не совпадает с DS manifest digest/sha256")
    return errs


def check_unit_proto(feature: Path, screen: str | None, gate: str) -> list[str]:
    errs: list[str] = []
    units = find_units(feature, screen)
    if not units:
        return ["units/<screen> не найдены"]
    for unit in units:
        d, p = unit_json(unit, ["proto.json", "unit-proto.json", f"proto.{unit.name}.json"])
        if d is None:
            # feature-level aggregate file may carry all screens
            agg, ap = unit_json(feature, ["unit-proto.json"])
            if agg is not None and isinstance(agg.get("screens"), list):
                matches = [s for s in agg["screens"] if s.get("screen_id") in {screen, unit.name}]
                if matches:
                    d, p = matches[0], ap
        if d is None:
            errs.append(f"нет proto.json/unit-proto.json в {unit}")
            continue
        sid = d.get("screen_id")
        if screen and sid and sid != screen:
            errs.append(f"{p}: screen_id={sid} != {screen}")
        states = d.get("states")
        if not isinstance(states, list) or not states:
            errs.append(f"{p}: states пуст")
        else:
            have = {str(x).lower() for x in states}
            for req in ("normal", "loading", "empty", "error"):
                if req not in have:
                    errs.append(f"{p}: нет state '{req}'")
        nodes = d.get("nodes")
        if nodes is not None and (not isinstance(nodes, list) or not nodes):
            errs.append(f"{p}: nodes пуст")
    return errs


def check_unit_ds_lock(feature: Path, screen: str | None, gate: str) -> list[str]:
    errs: list[str] = []
    pin = load_json(feature / "ds-pin.json", gate)
    version = pin.get("design_system_version")
    digest = pin.get("ds_digest")
    units = find_units(feature, screen)
    for unit in units:
        d, p = unit_json(unit, ["ds-lock.json", "unit-ds-lock.json", f"ds-lock.{unit.name}.json"])
        if d is None:
            errs.append(f"нет ds-lock.json в {unit}")
            continue
        if d.get("design_system_version") != version:
            errs.append(f"{p}: design_system_version != ds-pin")
        if d.get("ds_digest") != digest:
            errs.append(f"{p}: ds_digest != ds-pin")
        comps = d.get("components") or d.get("component_map")
        if not comps:
            errs.append(f"{p}: components/component_map пуст")
        sid = d.get("screen_id")
        if screen and sid and sid != screen:
            errs.append(f"{p}: screen_id={sid} != {screen}")
    return errs


def find_review_fragments(feature: Path) -> list[Path]:
    out = []
    for p in feature.rglob("design-review*.json"):
        if p.is_file():
            out.append(p)
    return sorted(set(out))


def check_design_review(feature: Path, kind: str, screen: str | None, gate: str) -> list[str]:
    errs: list[str] = []
    fragments = find_review_fragments(feature)
    if not fragments:
        return ["design-review.fragment.json не найден"]
    matched = 0
    for p in fragments:
        d = load_json(p, gate)
        if screen and d.get("screen_id") != screen:
            continue
        matched += 1
        if d.get("schema_version") != "1.0":
            errs.append(f"{p}: schema_version != 1.0")
        reviewers = d.get("reviewers") or {}
        r = reviewers.get(kind)
        if not isinstance(r, dict):
            errs.append(f"{p}: reviewers.{kind} отсутствует")
            continue
        if kind == "ui" and r.get("role") != "designer":
            errs.append(f"{p}: reviewers.ui.role != designer")
        if kind == "ux" and r.get("role") not in {"product-ux", "product"}:
            errs.append(f"{p}: reviewers.ux.role != product-ux")
        if not r.get("session_id") or not r.get("author_session_id"):
            errs.append(f"{p}: reviewers.{kind} session ids пусты")
        elif r.get("session_id") == r.get("author_session_id"):
            errs.append(f"{p}: reviewers.{kind}.session_id == author_session_id")
        if r.get("verdict") != "accept":
            errs.append(f"{p}: reviewers.{kind}.verdict != accept")
        if r.get("blockers") != 0:
            errs.append(f"{p}: reviewers.{kind}.blockers != 0")
        findings = d.get("findings") or []
        if not isinstance(findings, list):
            errs.append(f"{p}: findings не массив")
        else:
            for f in findings:
                if not isinstance(f, dict) or "severity" not in f or "text" not in f:
                    errs.append(f"{p}: finding без severity/text")
                elif f.get("severity") == "blocker" and f.get("status") not in {"fixed", "closed", "accepted"}:
                    errs.append(f"{p}: открытый finding blocker")
        if kind == "ui" and isinstance(reviewers.get("ux"), dict):
            if reviewers["ux"].get("session_id") == r.get("session_id"):
                errs.append(f"{p}: UI и UX закрыты одной сессией")
    if not matched:
        errs.append(f"design-review для screen={screen} не найден")
    return errs


def check_design_integrate(feature: Path, root: Path, gate: str) -> list[str]:
    errs: list[str] = []
    required = ["design-impact.md", "ds.lock.json", "component-refs.json", "component-map.yaml",
                "design-gaps.json", "design-review.fragment.json"]
    for name in required:
        if not (feature / name).is_file():
            errs.append(f"нет {name}")
    brief = feature / "visualized-brief.md"
    if not brief.is_file():
        alt = feature / "visualized-brief.json"
        if not alt.is_file():
            errs.append("нет visualized-brief.md/json")
    pin = load_json(feature / "ds-pin.json", gate)
    lock = load_json(feature / "ds.lock.json", gate) if (feature / "ds.lock.json").is_file() else {}
    if lock:
        rel = lock.get("release") or {}
        if lock.get("schema_version") != "1.0":
            errs.append("ds.lock.schema_version != 1.0")
        if rel.get("version") != pin.get("design_system_version"):
            errs.append("ds.lock.release.version != ds-pin")
        if lock.get("constraint") != f"={pin.get('design_system_version')}":
            errs.append("ds.lock.constraint != =<version>")
        mp = rel.get("manifest_path")
        if mp:
            path = root / mp if not Path(mp).is_absolute() else Path(mp)
            if not path.is_file():
                errs.append(f"ds.lock release manifest не найден: {path}")
            elif rel.get("manifest_sha256") and sha256_file(path) != rel.get("manifest_sha256"):
                errs.append("ds.lock.release.manifest_sha256 != sha256(manifest)")
    refs = load_json(feature / "component-refs.json", gate) if (feature / "component-refs.json").is_file() else {}
    if refs:
        if refs.get("ds_release") != pin.get("design_system_version"):
            errs.append("component-refs.ds_release != ds-pin")
        screens = refs.get("screens")
        if not isinstance(screens, list) or not screens:
            errs.append("component-refs.screens пуст")
        else:
            for s in screens:
                if not s.get("screen_id"):
                    errs.append("component-refs screen без screen_id")
                if s.get("local_instances") not in (None, []):
                    errs.append(f"component-refs {s.get('screen_id')}: local_instances не пуст")
        summary = refs.get("summary") or {}
        if summary.get("local_instances") not in (None, 0):
            errs.append("component-refs.summary.local_instances != 0")
    gaps = load_json(feature / "design-gaps.json", gate) if (feature / "design-gaps.json").is_file() else {}
    if gaps:
        items = gaps.get("items") or gaps.get("gaps") or []
        if not isinstance(items, list):
            errs.append("design-gaps.items не массив")
        else:
            for g in items:
                if g.get("status") == "open" and g.get("blocking") is True:
                    errs.append(f"design-gap open+blocking: {g.get('id')}")
    # review must accept both sides
    for kind in ("ui", "ux"):
        errs.extend(check_design_review(feature, kind, None, gate))
    return errs


def check_ds_usage(feature: Path, gate: str) -> list[str]:
    errs: list[str] = []
    p = feature / "ui-audit.json"
    if not p.is_file():
        return ["ui-audit.json не найден (s22a)"]
    d = load_json(p, gate)
    ds = d.get("design_system")
    if not isinstance(ds, dict):
        return ["ui-audit.design_system отсутствует (s22a DS block)"]
    for key in ["release", "manifest_sha256", "component_refs_sha256", "ds_usage_violations"]:
        if key not in ds:
            errs.append(f"ui-audit.design_system.{key} отсутствует")
    if ds.get("ds_usage_violations") != 0:
        errs.append("ui-audit.design_system.ds_usage_violations != 0")
    for key in ["manifest_sha256", "component_refs_sha256"]:
        if not SHA.match(str(ds.get(key, ""))):
            errs.append(f"ui-audit.design_system.{key} не sha256")
    pin = load_json(feature / "ds-pin.json", gate)
    if ds.get("release") != pin.get("design_system_version"):
        errs.append("ui-audit.design_system.release != ds-pin")
    return errs


def check_ux_audit(feature: Path, gate: str) -> list[str]:
    errs: list[str] = []
    p = feature / "ux-audit.json"
    d = load_json(p, gate)
    for key in ["schema_version", "feature_id", "artifact_path", "platform", "stand", "scope",
                "summary", "items", "independence", "context"]:
        if key not in d:
            errs.append(f"ux-audit.{key} отсутствует")
    if d.get("schema_version") != "1.0":
        errs.append("ux-audit.schema_version != 1.0")
    stand = d.get("stand") or {}
    if not stand.get("url"):
        errs.append("ux-audit.stand.url пуст")
    if not HEX40.match(str(stand.get("sha", ""))):
        errs.append("ux-audit.stand.sha не 40-hex")
    scope = d.get("scope") or {}
    if not scope.get("screens"):
        errs.append("ux-audit.scope.screens пуст")
    summary = d.get("summary") or {}
    if summary.get("verdict") != "pass":
        errs.append("ux-audit.summary.verdict != pass")
    if summary.get("blockers") != 0:
        errs.append("ux-audit.summary.blockers != 0")
    if summary.get("open_critical_high") != 0:
        errs.append("ux-audit.summary.open_critical_high != 0")
    indep = d.get("independence") or {}
    if indep.get("distinct") is not True:
        errs.append("ux-audit.independence.distinct != true")
    if not indep.get("auditor_session_id") or not indep.get("author_session_id"):
        errs.append("ux-audit.independence session ids пусты")
    elif indep.get("auditor_session_id") == indep.get("author_session_id"):
        errs.append("ux-audit auditor == author")
    items = d.get("items")
    if not isinstance(items, list) or not items:
        errs.append("ux-audit.items пуст")
    else:
        for i, item in enumerate(items):
            for key in ["id", "screen_id", "block", "criterion", "verdict", "severity", "oracle", "evidence"]:
                if key not in item:
                    errs.append(f"ux-audit.items[{i}].{key} отсутствует")
            if item.get("verdict") == "ok":
                ev = item.get("evidence") or {}
                if not ev.get("kind") or not ev.get("ref"):
                    errs.append(f"ux-audit.items[{i}] ok без evidence")
            if item.get("severity") == "blocker" and item.get("verdict") == "violation":
                errs.append(f"ux-audit.items[{i}] blocker violation")
    if not isinstance(d.get("context"), dict) or not d["context"].get("source"):
        errs.append("ux-audit.context.source пуст")
    return errs


def check_ds_drift(feature: Path, root: Path, gate: str) -> list[str]:
    errs: list[str] = []
    pin = load_json(feature / "ds-pin.json", gate)
    lock = load_json(feature / "ds.lock.json", gate) if (feature / "ds.lock.json").is_file() else {}
    if lock:
        rel = lock.get("release") or {}
        if rel.get("version") != pin.get("design_system_version"):
            errs.append("ds-drift: ds.lock.release.version != ds-pin")
        mp = rel.get("manifest_path")
        if mp and rel.get("manifest_sha256"):
            path = root / mp if not Path(mp).is_absolute() else Path(mp)
            if path.is_file() and sha256_file(path) != rel.get("manifest_sha256"):
                errs.append("ds-drift: release manifest hash changed")
    ui = feature / "ui-audit.json"
    if ui.is_file():
        d = json.loads(ui.read_text(encoding="utf-8"))
        ds = d.get("design_system") or {}
        if ds.get("release") and ds.get("release") != pin.get("design_system_version"):
            errs.append("ds-drift: ui-audit.design_system.release != ds-pin")
    return errs


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("gate", choices=["ds-pin", "unit-proto-coverage", "unit-ds-lock",
                                     "design-review", "design-integrate", "ds-usage", "ux-audit", "ds-drift"])
    ap.add_argument("--root", required=True)
    ap.add_argument("--feature-dir", default="")
    ap.add_argument("--screen", default="")
    ap.add_argument("--kind", choices=["ui", "ux"], default="")
    ap.add_argument("--base", default="")
    args = ap.parse_args()
    root = Path(args.root).resolve()
    gate = args.gate
    feature = resolve_feature(root, args.feature_dir or None, gate)
    try:
        if gate == "ds-pin":
            errs = check_ds_pin(root, feature, gate)
        elif gate == "unit-proto-coverage":
            errs = check_unit_proto(feature, args.screen or None, gate)
        elif gate == "unit-ds-lock":
            errs = check_unit_ds_lock(feature, args.screen or None, gate)
        elif gate == "design-review":
            if not args.kind:
                raise SystemExit(fail(gate, "--kind ui|ux обязателен"))
            errs = check_design_review(feature, args.kind, args.screen or None, gate)
        elif gate == "design-integrate":
            errs = check_design_integrate(feature, root, gate)
        elif gate == "ds-usage":
            errs = check_ds_usage(feature, gate)
        elif gate == "ux-audit":
            errs = check_ux_audit(feature, gate)
        elif gate == "ds-drift":
            errs = check_ds_drift(feature, root, gate)
        else:
            errs = [f"unknown gate {gate}"]
    except SystemExit:
        raise
    except Exception as exc:  # noqa: BLE001 - fail-close on malformed artifact
        errs = [f"неожиданная ошибка: {type(exc).__name__}: {exc}"]
    if errs:
        for e in errs:
            print(f"{gate}: FAIL — {e}", file=sys.stderr)
        return 1
    print(f"{gate}: PASS — {feature}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
