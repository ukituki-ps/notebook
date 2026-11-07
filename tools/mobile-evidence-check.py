#!/usr/bin/env python3
"""gate-mobile-lab — доказательства мобильного прогона (block M / s22d.mobile_probe).

Проверяет `doc/идеи/<F>/mobile-evidence.json`:
- покрыты ОБА движка: ≥1 android (Blink) и ≥1 ios (WebKit) из реестра device-lab;
- каждый device.id есть в tools/mobile-devices.json;
- у каждого устройства ≥1 СУЩЕСТВУЮЩИЙ скриншот (реальный прогон, не заявка);
- все flows — status: pass;
- summary: open_critical_high == 0, blockers == 0;
- stand.sha привязан к билду (--expect-sha).

Запускается через `tools/path1-gate.sh mobile-lab`.
"""
import sys as _sys, os as _os
_sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))
from _feature_dir import resolve as _resolve
import argparse, glob, json, os, sys

WEB_ENGINE = {"android": "Blink", "ios": "WebKit"}


def _find(root):
    # F189/E6355: mobile-evidence.json ТЕКУЩЕЙ фичи.
    path, _err = _resolve(root, "mobile-evidence.json")
    return [path] if path else []


def evaluate(root, registry, expect_sha=None):
    files = _find(root)
    if not files:
        return ["нет doc/идеи/<F>/mobile-evidence.json (mobile-проба не выполнена)"]
    if len(files) > 1:
        return [f"неоднозначный mobile-evidence.json: {len(files)}"]
    errs = []
    try:
        d = json.load(open(files[0], encoding="utf-8"))
    except Exception as e:
        return [f"mobile-evidence.json не парсится: {e}"]
    reg = {x["id"]: x for x in json.load(open(registry, encoding="utf-8"))["devices"]}
    devs = d.get("devices") or []
    if not devs:
        return ["devices[] пуст (не на чем проверять)"]
    platforms, ids = set(), set()
    for dv in devs:
        did = dv.get("id", "?")
        ids.add(did)
        meta = reg.get(did)
        if not meta:
            errs.append(f"device '{did}' нет в реестре device-lab (tools/mobile-devices.json)")
            continue
        platforms.add(meta["platform"])
        shots = [s for s in (dv.get("screenshots") or []) if s]
        real = [s for s in shots if os.path.exists(os.path.join(root, s))]
        if not real:
            errs.append(f"device '{did}': нет ни одного существующего скриншота ({len(shots)} заявлено)")
        for f in (dv.get("flows") or []):
            if str(f.get("status", "")).lower() != "pass":
                errs.append(f"device '{did}': flow '{f.get('name','?')}' не pass ({f.get('status')})")
        if not dv.get("browser"):
            errs.append(f"device '{did}': не указан browser (движок)")
    for p, engine in WEB_ENGINE.items():
        if p not in platforms:
            errs.append(f"нет устройства платформы '{p}' ({engine}) — нужны оба движка (блок M1)")
    stand = d.get("stand") or {}
    # p.5 (аудит F003/E5438): проба обязана подтверждать БИЛД. Иначе доказательство может
    # относиться к другому стенду/устаревшему SW-precache (аномалия A1: android отдал
    # бандл пре-abe20da из precache, хотя server HTML указывал новый).
    if not stand.get("sha"):
        errs.append("stand.sha пуст — проба не привязана к билду стенда (укажи ref выката)")
    if not stand.get("bundle"):
        errs.append("stand.bundle пуст — нечем подтвердить, что проба снята с выкаченного бандла")
    for dv in devs:
        did = dv.get("id", "?")
        dsha = dv.get("stand_sha")
        if not dsha:
            errs.append(f"device '{did}': нет stand_sha (какой билд реально прогнан?)")
        elif stand.get("sha") and dsha != stand.get("sha"):
            errs.append(f"device '{did}': stand_sha={str(dsha)[:10]} != stand.sha={stand.get('sha','')[:10]}")
        checks = dv.get("checks") or []
        build_chk = [c for c in checks if "build" in str(c.get("id", "")).lower()
                     or "build" in str(c.get("statement", "")).lower()
                     or "бандл" in str(c.get("statement", "")).lower()
                     or "precache" in str(c.get("statement", "")).lower()]
        if not build_chk:
            errs.append(
                f"device '{did}': нет ни одной проверки «проба снята с выкаченного билда» "
                f"(нужен check вида '<device>-current-build': загруженный бандл == stand.bundle)")
        else:
            for c in build_chk:
                v = str(c.get("verdict") or c.get("status") or "ok").lower()
                if v not in ("ok", "pass", "true"):
                    errs.append(f"device '{did}': проверка билда '{c.get('id')}' = {v}")
    if expect_sha and stand.get("sha") and stand["sha"] != expect_sha:
        errs.append(f"stand.sha={stand.get('sha','')[:10]} != билд {expect_sha[:10]}")
    # Near-duplicate между кадрами разных устройств/сценариев: одинаковые картинки —
    # не доказательство (тот же оракул, что в gate-evidence-authentic). Только если pngdiff есть.
    shots_all = [s for dv in devs for s in (dv.get("screenshots") or []) if s]
    real_all = [os.path.join(root, s) for s in shots_all if os.path.exists(os.path.join(root, s))]
    if len(real_all) >= 2:
        _pd = os.path.join(os.path.dirname(os.path.abspath(__file__)), "pngdiff.py")
        if os.path.isfile(_pd):
            import subprocess as _sp
            r = _sp.run(["python3", _pd, "--thresh", "0.005", *real_all], capture_output=True, text=True)
            if r.returncode != 0:
                errs.append("near-duplicate скриншоты мобильной пробы (кадры почти идентичны — не доказательство)")
    s = d.get("summary") or {}
    if int(s.get("open_critical_high", -1)) != 0:
        errs.append(f"summary.open_critical_high={s.get('open_critical_high')} != 0")
    if int(s.get("blockers", -1)) != 0:
        errs.append(f"summary.blockers={s.get('blockers')} != 0")
    return errs


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=".")
    ap.add_argument("--registry", default=os.path.join(os.path.dirname(__file__), "mobile-devices.json"))
    ap.add_argument("--expect-sha", default=None)
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args(argv)
    errs = evaluate(a.root, a.registry, a.expect_sha)
    ok = not errs
    if a.json:
        print(json.dumps({"gate": "mobile-lab", "ok": ok, "errors": errs}, ensure_ascii=False))
    else:
        print(f"gate-mobile-lab: {'PASS' if ok else 'FAIL'}")
        for e in errs:
            print("  -", e)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
