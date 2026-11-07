#!/usr/bin/env python3
"""check-catalog-invariants — gate-catalog-invariants (path-1).

Связывает КАТАЛОГ ОТКАЗОВ с ИНВАРИАНТАМИ: каждый high/critical пункт каталога
(`audit/fault-catalog/*`) обязан быть покрыт АКТИВНЫМ инвариантом с исполнимым
`test_ref` (invariant.covers содержит id пункта). Иначе — fail-close: «зелёный»
стенд при непокрытом классе дефектов недопустим (урок F187: date/empty/RLS).

Вход:
  --catalog     файл/каталог audit/fault-catalog/*.yaml
  --invariants  YAML/JSON с invariants: [{id, status, test_ref, covers:[catalog_id]}]
Выход: 0 ok; 1 fail; 2 error.
"""
from __future__ import annotations
import argparse, glob, json, os, sys

try:
    import yaml
except Exception:  # pragma: no cover
    yaml = None

HIGH = {"high", "critical"}


def _die(m, c=2):
    print(f"check-catalog-invariants: ERROR: {m}", file=sys.stderr)
    return c


def _catalog_entries(path):
    files = sorted(glob.glob(os.path.join(path, "*.yaml")) + glob.glob(os.path.join(path, "*.yml"))) \
        if os.path.isdir(path) else [path]
    out = []
    for f in files:
        with open(f, encoding="utf-8") as fh:
            doc = yaml.safe_load(fh) or []
        if isinstance(doc, list):
            out += [e for e in doc if isinstance(e, dict)]
    return out


def _load(p):
    with open(p, encoding="utf-8") as fh:
        t = fh.read()
    if p.endswith((".yaml", ".yml")):
        return yaml.safe_load(t)
    return json.loads(t)


def _find(doc, key):
    if isinstance(doc, dict):
        if isinstance(doc.get(key), list):
            return doc[key]
        for v in doc.values():
            r = _find(v, key)
            if r is not None:
                return r
    elif isinstance(doc, list):
        for v in doc:
            r = _find(v, key)
            if r is not None:
                return r
    return None


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="gate-catalog-invariants")
    ap.add_argument("--catalog", default="audit/fault-catalog")
    # Пусто/не задано допустимо ТОЛЬКО в app-режиме (явная декларация audit.mode=app):
    # тогда high/critical обязаны быть покрыты fault-verdicts (covered+evidence или
    # na+justification). Иначе — fail-close, без «тихого» PASS.
    ap.add_argument("--invariants", default="")
    ap.add_argument("--app-mode", action="store_true",
                    help="явный app-режим: invariants опциональны, вердикты обязательны")
    # fault-verdicts.json: {"<catalog_id>": {"verdict":"covered|gap|na","justification":"…"}}.
    # Класс без активного инварианта допускается как na (наследуется) — ТОЛЬКО с обоснованием.
    ap.add_argument("--verdicts", default="")
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args(argv)
    if yaml is None:
        return _die("PyYAML не установлен")
    inv_path = (a.invariants or "").strip()
    if not inv_path and not a.app_mode:
        return _die("invariants file not declared (fail-close; app-репо: audit.mode=app)", 1)
    if inv_path and not os.path.exists(inv_path):
        return _die(f"invariants file not found: {inv_path} (fail-close)", 1)
    try:
        cat = _catalog_entries(a.catalog)
        invs = (_find(_load(inv_path), "invariants") or []) if inv_path else []
    except (OSError, ValueError) as e:
        return _die(str(e))

    verdicts = {}
    if a.verdicts and os.path.exists(a.verdicts):
        try:
            verdicts = json.load(open(a.verdicts, encoding="utf-8"))
        except (OSError, ValueError):
            verdicts = {}

    covered = set()
    for inv in invs:
        if not isinstance(inv, dict):
            continue
        if inv.get("status") not in ("active", "", None):
            continue
        if not (inv.get("test_ref") or "").strip():
            continue
        for c in (inv.get("covers") or []):
            covered.add(c)

    errors = []
    inherited = []
    covered_by_verdict = []
    req = [e for e in cat if str(e.get("severity")) in HIGH]
    for e in req:
        cid = e.get("id")
        if not cid or cid in covered:
            continue
        v = verdicts.get(cid) if isinstance(verdicts, dict) else None
        if isinstance(v, dict) and v.get("verdict") == "na" and (v.get("justification") or "").strip():
            inherited.append(cid)  # na-по-наследованию с обоснованием — допускается
            continue
        # app-режим (явная декларация): covered-вердикт с evidence — это аудит-покрытие
        # проекта. Без evidence — не принимаем (не «тихий» PASS).
        if a.app_mode and isinstance(v, dict) and v.get("verdict") == "covered" and (v.get("evidence") or "").strip():
            covered_by_verdict.append(cid)
            continue
        errors.append(f"{cid} ({e.get('severity')}): не покрыт активным инвариантом (covers) "
                      f"и нет fault-verdicts с na+justification"
                      + ("" if a.app_mode else " (app-режим не объявлен)"))
    ok = not errors
    if a.json:
        print(json.dumps({"ok": ok, "high_critical": len(req), "covered": len(covered),
                          "covered_by_verdict": len(covered_by_verdict),
                          "na_inherited": len(inherited), "app_mode": bool(a.app_mode),
                          "errors": errors}, ensure_ascii=False))
    else:
        print(f"gate-catalog-invariants: {'OK' if ok else 'FAIL'} (high/critical={len(req)}, covered={len(covered)})")
        for x in errors:
            print(f"  - {x}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
