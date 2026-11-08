#!/usr/bin/env python3
"""gate-ui-audit — кроссплатформенный аудит UI (web + mobile).

Проверяет `doc/идеи/<F>/ui-audit.json` (§ «Аудит фронта» path-1):
- схема/обязательные поля, `platform ∈ {web,mobile,both,none}`;
- обязательные блоки чек-листа под платформу (A–L для web, M для mobile);
- каждый item: `verdict ∈ {ok,violation,na}`; при `na` — `reason`; иначе —
  исполнимый `oracle` (cmd:/sh:/<file>::<Test>/url/dom) И `evidence{kind,ref}`;
- привязка к билду стенда: `stand.sha` == `--expect-sha` (из preview-deploy.json);
- DoD: `summary.open_critical_high == 0` ∧ `blockers == 0`.

`none` — если проект объявил отсутствие UI (`path1.ui.json` platform=none) и это
ПОДТВЕРЖДЕНО (в файле `platform: none` + `summary.ui_absent_reason`): тогда PASS-NA.
Иначе — fail-close (нельзя «пропустить» UI-аудит без объявления).
"""
import argparse, glob, json, os, re, sys
import sys as _sys, os as _os
_sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))
from _feature_dir import resolve as _resolve


PLATFORM_BLOCKS = {
    "web":    "ABCDEFGHIJKL",
    "mobile": "ACDFGIKLM",
    "both":   "ABCDEFGHIJKLM",
}
SEV = {"blocker", "major", "minor", "cosmetic"}
VERDICT = {"ok", "violation", "na"}
ORA = re.compile(r"(cmd:|sh:|::\w|go test|npx |npm |pytest|maestro|playwright|axe|xcrun|simctl)", re.I)
SHA = re.compile(r"^[0-9a-f]{7,40}$")


def _find(root):
    # F189/E6355: ui-audit.json ТЕКУЩЕЙ фичи (не «первый по glob»).
    path, _err = _resolve(root, "ui-audit.json")
    return [path] if path else []


def evaluate(root, platform, expect_sha=None):
    files = _find(root)
    if not files:
        return [], ["нет doc/идеи/<F>/ui-audit.json"]
    if len(files) > 1 and expect_sha:
        files = [f for f in files if _sha_of(f) == expect_sha] or files
    if len(files) > 1:
        return [], [f"неоднозначный ui-audit.json: {len(files)} файлов (ожидается один)"]
    path = files[0]
    try:
        d = json.load(open(path, encoding="utf-8"))
    except Exception as e:
        return path, [f"ui-audit.json не парсится: {e}"]
    errs = []
    decl = d.get("platform")
    plat = decl if platform == "none" else platform
    if decl and decl not in (platform, "none") and platform != "none":
        errs.append(f"ui-audit.json.platform='{decl}' != объявленной '{platform}'")
    if plat not in PLATFORM_BLOCKS and plat != "none":
        errs.append(f"platform '{plat}' ∉ {{web,mobile,both,none}}")
    if plat == "none":
        if not (d.get("summary") or {}).get("ui_absent_reason"):
            errs.append("platform=none без summary.ui_absent_reason (обоснование обязательно)")
        return path, errs
    for f in ("stand", "summary", "items"):
        if f not in d:
            errs.append(f"нет обязательного поля '{f}'")
    stand = d.get("stand") or {}
    sha = str(stand.get("sha", ""))
    if not stand.get("url"):
        errs.append("stand.url пуст")
    if not SHA.match(sha):
        errs.append("stand.sha не похож на git-sha")
    if expect_sha and sha and sha != expect_sha:
        errs.append(f"stand.sha={sha[:10]} != билд стенда {expect_sha[:10]} (аудит не на том билде)")
    items = d.get("items") or []
    if not isinstance(items, list) or not items:
        errs.append("items пуст")
        items = []
    blocks_seen, na_blocks = set(), {}
    for i, it in enumerate(items, 1):
        iid = it.get("id", f"#{i}")
        blk = str(it.get("block", ""))
        v = it.get("verdict")
        if blk:
            blocks_seen.add(blk)
        if v not in VERDICT:
            errs.append(f"item {iid}: verdict '{v}' ∉ {sorted(VERDICT)}"); continue
        if v == "na":
            # F-06: reason обязателен ДЛЯ КАЖДОЙ na-позиции (иначе одна закрывает другую в блоке).
            if not (it.get("reason") or "").strip():
                errs.append(f"item {iid}: verdict=na без reason")
            na_blocks[blk] = it.get("reason") or na_blocks.get(blk) or ""
            continue
        if it.get("severity") not in SEV:
            errs.append(f"item {iid}: severity '{it.get('severity')}' ∉ {sorted(SEV)}")
        ev = it.get("evidence") or {}
        if not (ev.get("kind") and ev.get("ref")):
            errs.append(f"item {iid}: evidence{{kind,ref}} неполон")
        if not (it.get("oracle") or ORA.search(str(ev.get("ref", "")) + " " + str(it.get("criterion", "")))):
            errs.append(f"item {iid}: нет исполнимого oracle/ссыл­ки (criterion без доказательства)")
    need = PLATFORM_BLOCKS[plat]
    for b in need:
        if b not in blocks_seen:
            errs.append(f"блок {b} не покрыт (platform={plat})")
        elif b in na_blocks and not na_blocks[b]:
            errs.append(f"блок {b} весь na без reason")
    s = d.get("summary") or {}
    if int(s.get("open_critical_high", -1)) != 0:
        errs.append(f"summary.open_critical_high={s.get('open_critical_high')} != 0 (DoD)")
    if int(s.get("blockers", -1)) != 0:
        errs.append(f"summary.blockers={s.get('blockers')} != 0 (DoD)")
    errs += _check_ui_invariants(root)
    return path, errs


REQUIRED_UI_INVARIANTS = ("INV-UI-TRUTH", "INV-UI-LABEL", "INV-UI-A11Y-NAME", "INV-UI-ORACLE")


def _check_ui_invariants(root):
    """INV-UI-* ядро должно быть в invariants.json фичи (канон doc/процесс/ui-invariants.md)."""
    p, _err = _resolve(root, "invariants.json")
    files = [p] if p else []
    if not files:
        return ["нет doc/идеи/<F>/invariants.json (нужны INV-UI-* для UI-фичи)"]
    try:
        inv = json.load(open(files[0], encoding="utf-8"))
    except Exception as e:
        return [f"invariants.json не парсится: {e}"]
    have = {i.get("id") for i in (inv.get("invariants") or []) if isinstance(i, dict)}
    return [f"invariants.json не содержит обязательный {iid} (UI-фича)" for iid in REQUIRED_UI_INVARIANTS if iid not in have]


def _sha_of(p):
    try:
        return str((json.load(open(p, encoding="utf-8")).get("stand") or {}).get("sha", ""))
    except Exception:
        return ""


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=".")
    ap.add_argument("--platform", default="web", choices=["web", "mobile", "both", "none"])
    ap.add_argument("--expect-sha", default=None)
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args(argv)

    # PASS-NA (E7141/F193): инкремент без изменений UI-поверхности → UI-аудит неприменим.
    # Fail-closed: если определить не удалось (код ≠ 1), проверяем строго.
    import subprocess as _sp
    _r = _sp.run(["python3", os.path.join(os.path.dirname(os.path.abspath(__file__)), "ui_surface.py"),
                  "--root", a.root, "--base", os.environ.get("UI_SURFACE_BASE", "origin/main"),
                  "--print-reason"], capture_output=True, text=True)
    if _r.returncode == 1:
        print(f"gate-ui-audit: PASS-NA — инкремент без изменений UI-поверхности ({(_r.stdout or '').strip()})")
        return 0
    path, errs = evaluate(a.root, a.platform, a.expect_sha)
    ok = not errs
    if a.json:
        print(json.dumps({"gate": "ui-audit", "ok": ok, "path": path, "platform": a.platform, "errors": errs}, ensure_ascii=False))
    else:
        print(f"gate-ui-audit: {'PASS' if ok else 'FAIL'} (platform={a.platform})" + (f" ({path})" if path else ""))
        for e in errs:
            print("  -", e)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
