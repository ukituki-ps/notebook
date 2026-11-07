#!/bin/sh
''''exec python3 "$0" "$@" # '''
"""gate-open-findings-verdict: archd result-audit decision -> open confirmed major/high => verdict fail.
Reads $ORC_GATE_ROOT/.orc-archd/result-audit.json (materialized by ORC). Fail-close on missing fields."""
import json, os, sys

def fail(msg):
    print(f"gate-open-findings-verdict: FAIL — {msg}", file=sys.stderr)
    sys.exit(1)

root = (os.environ.get("ORC_GATE_ROOT") or "").strip()
if not root:
    print("gate-open-findings-verdict: FAIL — ORC_GATE_ROOT не задан (fail-close)", file=sys.stderr)
    sys.exit(2)
p = os.path.join(root, ".orc-archd", "result-audit.json")
if not os.path.isfile(p):
    fail(f"нет {p} (fail-close: archd result-audit не материализован)")
try:
    d = json.load(open(p, encoding="utf-8"))
except Exception as e:
    fail(f"invalid json {p}: {e}")

verdict = str(d.get("verdict") or "").strip().lower()
if verdict not in ("pass", "fail"):
    fail("нет/невалиден verdict (ожидается pass|fail)")
findings = d.get("findings")
counts = d.get("counts")
if not isinstance(findings, list):
    fail("нет findings[] (fail-close)")
if not isinstance(counts, dict):
    fail("нет counts{} (fail-close)")

def cnt(k):
    v = counts.get(k)
    if not isinstance(v, int) or isinstance(v, bool) or v < 0:
        fail(f"counts.{k} отсутствует/невалиден")
    return v

mh = cnt("open_confirmed_major_high")
cr = cnt("open_confirmed_critical")
calc_mh = sum(1 for f in findings if str(f.get("status", "")).lower() == "confirmed"
              and str(f.get("severity", "")).lower() in ("major", "high"))
calc_cr = sum(1 for f in findings if str(f.get("status", "")).lower() == "confirmed"
              and str(f.get("severity", "")).lower() == "critical")
if calc_mh != mh or calc_cr != cr:
    fail(f"counts не совпадают с findings (major_high {mh}!={calc_mh}, critical {cr}!={calc_cr})")
if (mh > 0 or cr > 0) and verdict != "fail":
    fail(f"open confirmed major/high={mh}, critical={cr}, verdict={verdict} (нужен fail)")
print(f"gate-open-findings-verdict: PASS — verdict={verdict}, open_confirmed_major_high={mh}, open_confirmed_critical={cr}")
