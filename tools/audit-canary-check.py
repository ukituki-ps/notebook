#!/usr/bin/env python3
"""audit-canary-check — валидация ЧУВСТВИТЕЛЬНОСТИ аудита через канарейки.

Механизм (ADR-KIT-090; расширяет path-9 `s06.canary_check`):
  * канарейка — заведомо известный дефект, подложенный в ИЗОЛИРОВАННЫЙ контур
    (не в реальную ветку). Аудит обязан его найти; если не нашёл — прогон
    невалиден (fail-close), «зелёный» вердикт не имеет силы;
  * заведомо «чистый» юнит НЕ должен получить ни одного finding (защита от
    вранья «нашёл всё», то есть от over-reporting).

Режимы:
  --mode manifest   структурная валидация манифеста (канарейки заведены):
                    canaries_total >= --min-canaries (default 2),
                    clean_units   >= --min-clean    (default 1).
  --mode verify     проверка детекции:
                    canaries_found == canaries_total
                    AND clean_untouched == true
                    => run_valid == true.

Контракт каталога прогона `data/audit/runs/<run_id>/`:
  canary.json    {"run_id": "...", "canaries": [{"id","seed","expect"?}],
                  "clean_units": ["<unit_id>", ...]}
  findings.json  {"findings": [{"id","unit_id"?, "canary_id"?}, ...]}

Канарейка считается найденной, если в findings есть запись с `canary_id == id`
либо `id == <canary id>`.

Выход: 0 = pass, 1 = fail (критерии не выполнены), 2 = ошибка использования/IO.
"""
from __future__ import annotations

import argparse
import glob
import json
import os
import sys


def _die(msg: str, code: int = 2) -> int:
    print(f"audit-canary-check: ERROR: {msg}", file=sys.stderr)
    return code


def _load_json(path: str):
    try:
        with open(path, "r", encoding="utf-8") as fh:
            return json.load(fh)
    except FileNotFoundError:
        raise
    except json.JSONDecodeError as exc:
        raise ValueError(f"{path}: invalid JSON: {exc}") from exc


def _run_dir(root: str, run_id: str) -> str:
    return os.path.join(root, run_id)


def _emit(mode: str, ok: bool, fields: dict, as_json: bool) -> None:
    result = {"mode": mode, "ok": bool(ok), **fields}
    if as_json:
        print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    else:
        status = "PASS" if ok else "FAIL"
        print(f"canary[{mode}] {status}: " + ", ".join(f"{k}={v}" for k, v in fields.items()))


def cmd_manifest(args) -> int:
    d = _run_dir(args.root, args.run)
    canary_path = os.path.join(d, "canary.json")
    if not os.path.isfile(canary_path):
        return _die(f"manifest not found: {canary_path}")
    try:
        doc = _load_json(canary_path)
    except ValueError as exc:
        return _die(str(exc))

    canaries = doc.get("canaries") or []
    clean = doc.get("clean_units") or []
    errors = []
    if not isinstance(canaries, list):
        errors.append("canaries must be a list")
        canaries = []
    if not isinstance(clean, list):
        errors.append("clean_units must be a list")
        clean = []

    seen = set()
    for i, c in enumerate(canaries):
        if not isinstance(c, dict):
            errors.append(f"canaries[{i}] must be an object")
            continue
        if not c.get("id"):
            errors.append(f"canaries[{i}] missing id")
        elif c["id"] in seen:
            errors.append(f"duplicate canary id: {c['id']}")
        else:
            seen.add(c["id"])
        if not c.get("seed"):
            errors.append(f"canaries[{i}] ({c.get('id','?')}) missing seed")

    total = len(canaries)
    if total < args.min_canaries:
        errors.append(f"canaries_total={total} < min_canaries={args.min_canaries}")
    if len(clean) < args.min_clean:
        errors.append(f"clean_units={len(clean)} < min_clean={args.min_clean}")

    fields = {
        "run": args.run,
        "canaries_total": total,
        "clean_units": len(clean),
        "min_canaries": args.min_canaries,
        "min_clean": args.min_clean,
    }
    if errors:
        fields["errors"] = "; ".join(errors)
    ok = not errors
    _emit("manifest", ok, fields, args.json)
    return 0 if ok else 1



def _finding_evidence(f, root, catalog_root):
    """F3: находка канарейки обязана нести машинное доказательство детекции
    (proof_run_id/detector_exit/evidence_id ИЛИ существующий contour-файл unit_id/file),
    а не только само-ссылку id==canary_id."""
    for k in ("proof_run_id", "detector_exit", "evidence_id"):
        if k in f:
            return True
    for k in ("unit_id", "file"):
        v = f.get(k)
        if isinstance(v, str) and v.strip():
            for base in (root, ".", os.path.join(root, "..", "..", "canary-contour"), "data/audit/canary-contour"):
                if os.path.exists(os.path.join(base, v)) or os.path.exists(v):
                    return True
    return False


def _load_verdicts(path, as_json=False):
    """fault-verdicts.json: {"<catalog_id>": {"verdict":"...","justification":"..."}}."""
    if not path:
        return {}
    try:
        with open(path, "r", encoding="utf-8") as fh:
            doc = json.load(fh)
        return doc if isinstance(doc, dict) else {}
    except (OSError, ValueError):
        return {}


def _critical_canary_refs(catalog, verdicts=None, app_mode=False):
    """critical-пункты каталога, у которых есть canary_ref.

    app_mode (явная декларация audit.mode=app): critical-класс, помеченный в
    fault-verdicts как `na` С justification, неприменим к проекту и не требует
    канарейки. Без justification (или без app_mode) — требование сохраняется
    (fail-closed), чтобы app-репо не получал поблажек молча.
    """
    refs = {}
    try:
        import yaml
    except ImportError:
        return set(refs)
    for path in sorted(glob.glob(os.path.join(catalog, "*.yaml"))) + sorted(glob.glob(os.path.join(catalog, "*.yml"))):
        try:
            doc = yaml.safe_load(open(path, encoding="utf-8")) or []
        except Exception:
            continue
        for e in doc if isinstance(doc, list) else []:
            if not (isinstance(e, dict) and str(e.get("severity", "")).lower() == "critical" and e.get("canary_ref")):
                continue
            cid = e.get("id")
            if app_mode and isinstance(verdicts, dict):
                v = verdicts.get(cid)
                if isinstance(v, dict) and v.get("verdict") == "na" and (v.get("justification") or "").strip():
                    continue
            refs[os.path.basename(str(e["canary_ref"]).rstrip("/"))] = cid
    return set(refs)


def cmd_verify(args) -> int:
    d = _run_dir(args.root, args.run)
    canary_path = os.path.join(d, "canary.json")
    findings_path = args.findings or os.path.join(d, "findings.json")
    if not os.path.isfile(canary_path):
        return _die(f"manifest not found: {canary_path}")
    if not os.path.isfile(findings_path):
        return _die(f"findings not found: {findings_path}")
    try:
        canary_doc = _load_json(canary_path)
        findings_doc = _load_json(findings_path)
    except ValueError as exc:
        return _die(str(exc))

    canaries = canary_doc.get("canaries") or []
    clean = set(canary_doc.get("clean_units") or [])
    canary_ids = {c.get("id") for c in canaries if isinstance(c, dict) and c.get("id")}
    findings = findings_doc.get("findings") or []

    found = set()
    genuine = set()
    clean_hits = []
    require_ev = not getattr(args, "allow_self", False)
    for f in findings:
        if not isinstance(f, dict):
            continue
        cid = f.get("canary_id")
        fid = f.get("id")
        match = cid if cid in canary_ids else (fid if fid in canary_ids else None)
        if match:
            found.add(match)
            if not require_ev or _finding_evidence(f, d, args.catalog):
                genuine.add(match)
        if f.get("unit_id") in clean:
            clean_hits.append(f.get("unit_id"))

    total = len(canaries)
    canaries_found = len(genuine) if require_ev else len(found)
    clean_untouched = not clean_hits
    run_valid = (canaries_found == total) and clean_untouched
    # F4: манифест обязан покрывать critical-канарейки каталога
    crit = _critical_canary_refs(
        args.catalog,
        _load_verdicts(getattr(args, "verdicts", ""), as_json=True),
        bool(getattr(args, "app_mode", False)),
    ) if getattr(args, "require_critical", False) else set()
    if crit:
        have = {os.path.basename(str(c).rstrip("/")) for c in canary_ids}
        miss_crit = sorted(crit - have)
        if miss_crit:
            run_valid = False
            fields_critmiss = ",".join(miss_crit)

    fields = {
        "run": args.run,
        "canaries_total": total,
        "canaries_found": canaries_found,
        "clean_untouched": clean_untouched,
        "run_valid": run_valid,
    }
    missing = sorted(canary_ids - (genuine if require_ev else found))
    if missing:
        fields["missing_canaries"] = ",".join(missing)
    if require_ev:
        fields["self_reference_only"] = ",".join(sorted(found - genuine))
    if crit and (crit - {os.path.basename(str(c).rstrip("/")) for c in canary_ids}):
        fields["missing_critical"] = ",".join(sorted(crit - {os.path.basename(str(c).rstrip("/")) for c in canary_ids}))
    if clean_hits:
        fields["false_positive_units"] = ",".join(sorted(clean_hits))
    _emit("verify", run_valid, fields, args.json)
    return 0 if run_valid else 1


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="Audit canary manifest/verify gate (ADR-KIT-090)")
    p.add_argument("--mode", required=True, choices=["manifest", "verify"])
    p.add_argument("--run", required=True, help="run id (каталог под --root)")
    p.add_argument("--root", default=os.environ.get("ORC_AUDIT_RUNS_ROOT", "data/audit/runs"),
                   help="корень каталогов прогонов (default data/audit/runs)")
    p.add_argument("--findings", default=None,
                   help="путь к findings.json (default <run_dir>/findings.json)")
    p.add_argument("--min-canaries", type=int, default=2)
    p.add_argument("--min-clean", type=int, default=1)
    p.add_argument("--allow-self", action="store_true",
                   help="разрешить находки без доказательства детекции (legacy; по умолчанию запрещено — F3)")
    p.add_argument("--require-critical", action="store_true",
                   help="требовать покрытие critical-канареек каталога (--catalog) — F4")
    p.add_argument("--catalog", default="audit/fault-catalog",
                   help="каталог детекторов для --require-critical")
    p.add_argument("--verdicts", default="",
                   help="fault-verdicts.json: na+justification снимает требование critical-канарейки в --app-mode")
    p.add_argument("--app-mode", action="store_true",
                   help="явный app-режим проекта (audit.mode=app): critical только для применимых классов")
    p.add_argument("--json", action="store_true", help="машинный вывод (одна JSON-строка)")
    return p


def main(argv=None) -> int:
    args = build_parser().parse_args(argv)
    if args.mode == "manifest":
        return cmd_manifest(args)
    return cmd_verify(args)


if __name__ == "__main__":
    sys.exit(main())
