#!/usr/bin/env python3
"""gate-coverage-verdict — fail-close по машинному зеркалу s17.coverage_audit.

Контракт path-1 3.1.1 (ADR-3.2-03 D3):
  doc/идеи/<F>/coverage-audit.json:
    {"verdict": "pass|pass_with_gaps|fail",
     "coverage": {"total": N, "resolved": N},
     "gaps": [{"id","severity":"info|minor|major|critical","owner",...}]}

Правила:
  * артефакт отсутствует/не JSON/неверный verdict → FAIL (fail-close, не skip);
  * verdict=fail → FAIL;
  * любой gap severity major|critical → FAIL (даже при verdict=pass_with_gaps);
  * у major/critical gap обязателен непустой owner;
  * pass_with_gaps с info/minor → PASS (s20 открывается).

Exit 0 — PASS, exit 1 — FAIL, exit 2 — ошибка вызова/нет артефакта.
"""
from __future__ import annotations

import argparse
import json
import sys

VERDICTS = {"pass", "pass_with_gaps", "fail"}
SEVERITIES = {"info", "minor", "major", "critical"}
BLOCKING = {"major", "critical"}


def fail(msg: str) -> int:
    print(f"gate-coverage-verdict: FAIL — {msg}", file=sys.stderr)
    return 1


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--path", required=True, help="doc/идеи/<F>/coverage-audit.json")
    args = ap.parse_args()

    path = (args.path or "").strip()
    if not path:
        return fail("не найден coverage-audit.json (машинное зеркало s17 не опубликовано)")

    try:
        with open(path, encoding="utf-8") as fh:
            doc = json.load(fh)
    except FileNotFoundError:
        return fail(f"нет файла {path}")
    except json.JSONDecodeError as exc:
        return fail(f"{path}: невалидный JSON ({exc})")

    if not isinstance(doc, dict):
        return fail(f"{path}: ожидался объект")

    verdict = doc.get("verdict")
    if verdict not in VERDICTS:
        return fail(f"{path}: verdict={verdict!r}, ожидалось одно из {sorted(VERDICTS)}")

    gaps = doc.get("gaps", [])
    if not isinstance(gaps, list):
        return fail(f"{path}: gaps должен быть массивом")

    blocking = []
    for i, gap in enumerate(gaps):
        if not isinstance(gap, dict):
            return fail(f"{path}: gaps[{i}] должен быть объектом")
        sev = gap.get("severity")
        if sev not in SEVERITIES:
            return fail(f"{path}: gaps[{i}].severity={sev!r}, ожидалось одно из {sorted(SEVERITIES)}")
        if sev in BLOCKING:
            owner = gap.get("owner")
            if not isinstance(owner, str) or not owner.strip():
                return fail(f"{path}: gaps[{i}] severity={sev} без owner (обязателен)")
            blocking.append(f"{gap.get('id', f'#{i}')}({sev})")

    if verdict == "fail":
        return fail(f"{path}: verdict=fail (s20 не открывается)")
    if blocking:
        return fail(f"{path}: verdict={verdict}, блокирующие gaps: {', '.join(blocking)}")

    print(
        f"gate-coverage-verdict: PASS — verdict={verdict}, gaps={len(gaps)} "
        f"(major/critical: 0)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
