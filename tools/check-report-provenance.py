#!/usr/bin/env python3
"""Verify that a final markdown report's provenance matches the run artifacts.

E1688 showed why hand-copied digests are dangerous: the report table carried an
old build_args_hash while preview-deploy.json/healthz had the real one. This
check compares the fields present in the report against preview-deploy.json
(and optionally /healthz) and fails on any mismatch.

Usage:
  check-report-provenance.py --report REPORT.md --preview-deploy preview-deploy.json
    [--healthz https://stand/healthz | --healthz healthz.json]

Exit: 0 match/absent, 1 mismatch, 2 bad input.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import urllib.request

FIELDS = ("image_digest", "build_args_hash", "gate_bundle_digest")


def load_healthz(ref: str) -> dict:
    if ref.startswith(("http://", "https://")):
        with urllib.request.urlopen(ref, timeout=10) as r:  # noqa: S310 - explicit operator URL
            return json.load(r)
    with open(ref, encoding="utf-8") as fh:
        return json.load(fh)


def report_fields(text: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for line in text.splitlines():
        m = re.match(r"\|\s*(image_digest|build_args_hash|gate_bundle_digest)\s*\|\s*`?([^`|]+)`?", line)
        if m:
            out[m.group(1)] = m.group(2).strip()
    return out


def digest_match(got: str, want: str) -> bool:
    """Accept a full digest or a report abbreviation ending in .../…."""
    g = got.strip().lower().replace("…", "...")
    w = want.strip().lower()
    if g.endswith("..."):
        prefix = g[:-3]
        return len(prefix) >= 10 and w.startswith(prefix)
    return g == w


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--report", required=True)
    ap.add_argument("--preview-deploy")
    ap.add_argument("--healthz")
    a = ap.parse_args(argv)
    if not a.preview_deploy and not a.healthz:
        print("report-provenance: FAIL — need --preview-deploy and/or --healthz", file=sys.stderr)
        return 2
    try:
        text = open(a.report, encoding="utf-8").read()
        dep = json.load(open(a.preview_deploy, encoding="utf-8")) if a.preview_deploy else {}
    except (OSError, ValueError) as e:
        print(f"report-provenance: FAIL — {e}", file=sys.stderr)
        return 2
    health = {}
    if a.healthz:
        try:
            health = load_healthz(a.healthz)
        except (OSError, ValueError) as e:
            print(f"report-provenance: FAIL — healthz: {e}", file=sys.stderr)
            return 2

    expected = {
        "image_digest": str(dep.get("stand_image_digest") or "").strip(),
        "build_args_hash": str(dep.get("build_args_hash") or "").strip(),
        "gate_bundle_digest": str(dep.get("gate_bundle_digest") or "").strip(),
    }
    for k in FIELDS:
        if not expected[k] and health.get(k):
            expected[k] = str(health[k]).strip()

    found = report_fields(text)
    bad = []
    for k in FIELDS:
        got = found.get(k)
        want = expected.get(k)
        if got and want and not digest_match(got, want):
            bad.append(f"{k}: report={got} artifact={want}")
    if bad:
        for b in bad:
            print(f"report-provenance: FAIL — {b}", file=sys.stderr)
        return 1
    print(f"report-provenance: OK ({', '.join(k for k in FIELDS if found.get(k)) or 'no fields'} )")
    return 0


if __name__ == "__main__":
    sys.exit(main())
