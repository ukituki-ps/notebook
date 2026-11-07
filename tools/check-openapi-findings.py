#!/usr/bin/env python3
"""check-openapi-findings — схема OpenAPI ⇄ код ⇄ БД (CR-F188-03 / CR-07).

Проверяет, что `Finding`/`FindingList` в `openapi/modules/nexus-d9-findings.yaml`
1:1 совпадают с Go-структурами (json-теги) в `nexus/findings/types.go`, и что
enum'ы `status/severity` из схемы совпадают со значениями в миграции
`0020_findings_status.sql` / CHECK `0042_findings_status_enum_check.sql`.

Гейт `gate-openapi-schema` (tools/path1-gate.sh openapi-schema).
"""
import argparse
import re
import sys

import yaml

PAIRS = {"Finding": "Finding", "FindingList": "ListResponse"}


def go_fields(src, struct):
    m = re.search(r"type\s+" + re.escape(struct) + r"\s+struct\s*\{(.*?)\n\}", src, re.S)
    if not m:
        return None
    body = m.group(1)
    out = []
    for line in body.splitlines():
        jm = re.search(r'json:"([^",]+)', line)
        if jm and jm.group(1) != "-":
            out.append(jm.group(1))
    return out


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--spec", default="openapi/modules/nexus-d9-findings.yaml")
    ap.add_argument("--go", default="nexus/findings/types.go")
    ap.add_argument("--migration", default="nexus/migrations/0020_findings_status.sql")
    a = ap.parse_args(argv)

    spec = yaml.safe_load(open(a.spec, encoding="utf-8"))
    schemas = ((spec.get("components") or {}).get("schemas") or {})
    go = open(a.go, encoding="utf-8").read()
    errs = []

    for sname, gname in PAIRS.items():
        sc = schemas.get(sname)
        if not sc:
            errs.append(f"нет схемы {sname} в {a.spec}")
            continue
        props = set((sc.get("properties") or {}).keys())
        gfields = go_fields(go, gname)
        if gfields is None:
            errs.append(f"нет Go-структуры {gname} в {a.go}")
            continue
        gset = set(gfields)
        miss = props - gset
        extra = gset - props
        if miss:
            errs.append(f"{sname}: в схеме, но нет в коде: {sorted(miss)}")
        if extra:
            errs.append(f"{sname}: в коде, но нет в схеме: {sorted(extra)}")
        req = set(sc.get("required") or [])
        if not req <= props:
            errs.append(f"{sname}: required ∌ properties: {sorted(req - props)}")

    # enum ⇄ БД CHECK (0042): множества должны совпадать
    try:
        chk = open("nexus/migrations/0042_findings_status_enum_check.sql", encoding="utf-8").read()
    except OSError:
        chk = ""

    def check_set(field):
        m = re.search(r"CHECK\s*\(\s*" + field + r"\s+IN\s*\(([^)]*)\)", chk, re.I)
        return set(re.findall(r"'([^']+)'", m.group(1))) if m else None

    for field in ("status", "severity"):
        enum = set((((schemas.get("Finding") or {}).get("properties") or {}).get(field) or {}).get("enum") or [])
        dbset = check_set(field)
        if not enum:
            errs.append(f"Finding.{field}: нет enum в схеме")
        elif dbset is None:
            errs.append(f"0042: не найден CHECK-набор для '{field}'")
        elif enum != dbset:
            errs.append(f"Finding.{field}: схема enum {sorted(enum)} != БД CHECK {sorted(dbset)}")

    if errs:
        print("gate-openapi-schema: FAIL")
        for e in errs:
            print("  -", e)
        return 1
    print("gate-openapi-schema: PASS — Finding/FindingList 1:1 (схема ⇄ код), enum'ы согласованы с миграциями")
    return 0


if __name__ == "__main__":
    sys.exit(main())
