#!/usr/bin/env python3
"""check-scenario-coverage — gate-scenario-coverage (path-1).

Приёмка идёт по ПОЛЬЗОВАТЕЛЬСКИМ СЦЕНАРИЯМ: бриф задаёт `scenarios[]`
(Given/When/Then), а на стенде по каждому прогоняется E2E с evidence-скриншотом.
Гейт fail-close: каждый сценарий обязан иметь ПРОЙДЕННЫЙ E2E + непустой скриншот.

Вход:
  --brief     YAML/JSON с scenarios: [{id, given, when, then}]
  --evidence  YAML/JSON с scenarios: [{id, status: pass|fail, screenshot: <path>, e2e_ref}]
Выход: 0 ok; 1 fail; 2 error.
"""
from __future__ import annotations
import argparse, json, os, sys

try:
    import yaml
except Exception:  # pragma: no cover
    yaml = None


def _die(m, c=2):
    print(f"check-scenario-coverage: ERROR: {m}", file=sys.stderr)
    return c


def _load(p):
    with open(p, encoding="utf-8") as fh:
        t = fh.read()
    if p.endswith((".yaml", ".yml")):
        if yaml is None:
            raise RuntimeError("PyYAML нужен для .yaml")
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
    ap = argparse.ArgumentParser(description="gate-scenario-coverage")
    ap.add_argument("--brief", required=True)
    ap.add_argument("--evidence", required=True)
    ap.add_argument("--allow-empty", action="store_true", help="пусто=ok (по умолчанию fail-close)")
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args(argv)

    # PASS-NA (E7141/F193): без изменений UI-поверхности сценарии UI неприменимы.
    # Fail-closed: если определить не удалось (код != 1) — проверяем строго.
    import subprocess as _sp, os as _os
    _r = _sp.run(["python3", _os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "ui_surface.py"),
                    "--root", _os.path.dirname(_os.path.dirname(_os.path.abspath(__file__))), "--base", _os.environ.get("UI_SURFACE_BASE", "origin/main")],
                   capture_output=True, text=True)
    if _r.returncode == 1:
        print("gate-scenario-coverage: PASS-NA — инкремент без изменений UI-поверхности")
        return 0
    try:
        scenarios = _find(_load(a.brief), "scenarios")
        ev = _find(_load(a.evidence), "scenarios")
    except (OSError, ValueError, RuntimeError) as e:
        return _die(str(e))

    errors = []
    scenarios = scenarios or []
    ev = ev or []
    if not scenarios and not a.allow_empty:
        errors.append("в брифе нет scenarios[] (fail-close: сценарии обязательны)")
    ev_by = {e.get("id"): e for e in ev if isinstance(e, dict)}
    for s in scenarios:
        if not isinstance(s, dict):
            continue
        sid = s.get("id")
        if not sid:
            errors.append("scenario без id")
            continue
        e = ev_by.get(sid)
        if not e:
            errors.append(f"{sid}: нет E2E-evidence")
            continue
        if e.get("status") != "pass":
            errors.append(f"{sid}: E2E status={e.get('status')} (нужен pass)")
        # Сценарий с oracle=unit закрыт ЮНИТ-оракулом: стендовый кадр не требуется,
        # но нужен существующий test_ref (иначе это не доказательство, а отписка).
        if str(s.get("oracle") or "").strip().lower() == "unit":
            tref = str((e.get("test_ref") or s.get("test_ref") or "")).strip()
            tf = tref.split("::", 1)[0].strip()
            import os as _os2
            sp2 = tf if _os2.path.isabs(tf) else _os2.path.join(_os2.getcwd(), tf)
            if not tf or not _os2.path.isfile(sp2):
                errors.append(f"{sid}: oracle=unit, но test_ref не найден: {tref!r}")
            continue
        shot = (e.get("screenshot") or "").strip()
        if not shot:
            errors.append(f"{sid}: нет скриншота-evidence")
        else:
            # Review F-UIE2E-1c: наличие строки ≠ наличие доказательства — файл обязан существовать
            # и быть непустым (путь от корня репо; гейты исполняются в worktree).
            import os as _os, hashlib as _hl
            sp = shot if _os.path.isabs(shot) else _os.path.join(_os.getcwd(), shot)
            if not _os.path.isfile(sp) or _os.path.getsize(sp) == 0:
                errors.append(f"{sid}: файл скриншота не найден/пуст: {shot}")
            elif (e.get("sha256") or "").strip():
                got = _hl.sha256(open(sp, "rb").read()).hexdigest()
                if got != e["sha256"].strip():
                    errors.append(f"{sid}: sha256 скриншота не совпадает с evidence ({shot})")
    ok = not errors
    if a.json:
        print(json.dumps({"ok": ok, "scenarios": len(scenarios), "errors": errors}, ensure_ascii=False))
    else:
        print(f"gate-scenario-coverage: {'OK' if ok else 'FAIL'} (scenarios={len(scenarios)})")
        for x in errors:
            print(f"  - {x}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
