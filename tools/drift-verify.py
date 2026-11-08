#!/usr/bin/env python3
"""drift-verify — runner для gate-drift-expected-actual (C-5, expected==actual).

Usage:
    python3 tools/drift-verify.py verify --expected <canon.json> --actual <run-result.json>

Канон объявляет ожидаемое поведение сценария в `expected` (top-level или
`scenarios[].expected`). Run-result публикует фактические значения в `repro`
и/или `run_result`. Гейт проходит только если каждое ожидаемое поле совпадает
с фактическим; отсутствующее поле — drift (fail-close, не skip).

Exit: 0 = expected==actual; 1 = drift/не найдено; 2 = ошибка использования.
"""
from __future__ import annotations

import argparse
import json
import sys
from typing import Any


def _load(path: str) -> Any:
    with open(path, "r", encoding="utf-8") as fh:
        return json.load(fh)


def _expected(doc: Any) -> dict | None:
    if isinstance(doc, dict):
        if isinstance(doc.get("expected"), dict):
            return doc["expected"]
        for sc in doc.get("scenarios") or []:
            if isinstance(sc, dict) and isinstance(sc.get("expected"), dict):
                return sc["expected"]
    return None


def _actual(doc: Any) -> dict:
    out: dict[str, Any] = {}
    if not isinstance(doc, dict):
        return out
    repro = doc.get("repro")
    if isinstance(repro, dict):
        for k, v in repro.items():
            out[k] = v
    rr = doc.get("run_result")
    if isinstance(rr, dict):
        for k, v in rr.items():
            if isinstance(v, dict):
                for kk, vv in v.items():
                    out[f"{k}.{kk}"] = vv
            else:
                out[k] = v
    return out


def _resolve(actual: dict, key: str) -> tuple[bool, Any]:
    if key in actual:
        return True, actual[key]
    # nested path a.b.c
    cur: Any = actual
    for part in key.split("."):
        if not isinstance(cur, dict) or part not in cur:
            return False, None
        cur = cur[part]
    return True, cur


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description="C-5 expected==actual drift gate")
    sub = p.add_subparsers(dest="cmd", required=True)
    v = sub.add_parser("verify")
    v.add_argument("--expected", required=True, dest="expected_path")
    v.add_argument("--actual", required=True, dest="actual_path")
    args = p.parse_args(argv)

    try:
        canon = _load(args.expected_path)
        result = _load(args.actual_path)
    except Exception as exc:  # noqa: BLE001
        print(f"drift-verify: ERROR: {exc}", file=sys.stderr)
        return 2

    expected = _expected(canon)
    if not expected:
        print("drift-verify: FAIL — canon не содержит expected", file=sys.stderr)
        return 1
    actual = _actual(result)
    if not actual:
        print("drift-verify: FAIL — run-result не содержит repro/run_result", file=sys.stderr)
        return 1

    drift: list[str] = []
    for key, want in expected.items():
        ok, got = _resolve(actual, key)
        if not ok:
            drift.append(f"{key}: expected {want!r}, actual <missing>")
        elif got != want:
            drift.append(f"{key}: expected {want!r}, actual {got!r}")

    if drift:
        print("drift-verify: FAIL — expected != actual", file=sys.stderr)
        for line in drift:
            print(f"  - {line}", file=sys.stderr)
        return 1
    print(f"drift-verify: PASS — {len(expected)} expected fields match")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
