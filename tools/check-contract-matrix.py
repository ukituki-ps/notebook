#!/usr/bin/env python3
"""gate-contract-matrix — spec-прецизия (ADR-KIT-090; «9.5» step 1).

Требует `doc/идеи/<F>/spec/contract-matrix.md`: таблица контракта 1:1 с точками,
ГДЕ по каждому endpoint указаны статус-коды (по слоям), границы параметров,
envelope ошибок, и test_ref; плюс секция негативных/краевых кейсов (≥N).

Смысл: закрывает класс «код соответствует расплывчатой спеке» (405 vs 403,
page_size, until, envelope auth-слоя и т.п.) — неоднозначность спеки = балл ниже.
"""
import argparse, glob, os, re, sys
import sys as _sys, os as _os
_sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))
from _feature_dir import resolve as _resolve


ROWS_MIN = 1
NEG_MIN = 5
REQ_COLS = ("endpoint", "method", "status", "envelope", "test")


def _backend_diff(root: str) -> bool:
    """True, если в ветке есть изменения backend-поверхности (Go/SQL/openapi/proto/yaml).
    UI/docs-only фича -> contract-matrix/spec-coverage не требуются (PASS-NA)."""
    import subprocess, re as _re
    def run(args):
        try:
            return subprocess.run(["git", "-C", root, "-c", "core.quotepath=false", *args],
                                  capture_output=True, text=True, timeout=20).stdout
        except Exception:
            return ""
    base = ""
    for ref in ("origin/main", "main"):
        if run(["rev-parse", "--verify", "--quiet", ref]).strip():
            base = ref
            break
    if not base:
        return True
    mb = run(["merge-base", base, "HEAD"]).strip() or base
    pat = _re.compile(r"(\.go$|\.sql$|\.proto$|openapi|\.ya?ml$)")
    for f in run(["diff", "--name-only", f"{mb}...HEAD"]).splitlines():
        f = f.strip()
        if not f or f.startswith("doc/"):
            continue
        if pat.search(f):
            return True
    return False


def _find(root):
    # F189/E6355: артефакт ТЕКУЩЕЙ фичи (детерминированно), не «первый по glob».
    for name in ("spec/contract-matrix.md", "contract-matrix.md"):
        path, _err = _resolve(root, name)
        if path:
            return path
    return None


def _table_rows(text):
    rows, header = [], None
    for line in text.splitlines():
        s = line.strip()
        if not s.startswith("|"):
            continue
        cells = [c.strip() for c in s.strip("|").split("|")]
        if all(re.fullmatch(r":?-{2,}:?", c) for c in cells if c):
            continue  # separator
        if header is None:
            header = [c.lower() for c in cells]; continue
        rows.append(dict(zip(header, cells)))
    return header, rows


def evaluate(root):
    path = _find(root)
    if not path:
        return None, ["нет doc/идеи/<F>/spec/contract-matrix.md (spec-прецизия обязательна)"]
    text = open(path, encoding="utf-8").read()
    errs = []
    header, rows = _table_rows(text)
    if not header:
        errs.append("нет markdown-таблицы контракта")
    else:
        h = " ".join(header)
        for col in REQ_COLS:
            if col not in h:
                errs.append(f"в таблице нет колонки '{col}' (нужны: {', '.join(REQ_COLS)})")
    if len(rows) < ROWS_MIN:
        errs.append(f"таблица контракта пуста (<{ROWS_MIN} строк)")
    # негативные/краевые кейсы
    m = re.search(r"#+\s*(negativ|краев|edge|негатив)[^\n]*\n(.*?)(\n#|\Z)", text, re.I | re.S)
    neg = 0
    if m:
        neg = len([l for l in m.group(2).splitlines() if l.strip().startswith(("-", "*", "|"))])
    if neg < NEG_MIN:
        errs.append(f"секция негативных/краевых кейсов: {neg} < {NEG_MIN}")
    return path, errs


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=".")
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args(argv)
    if not _backend_diff(a.root):
        if a.json:
            print(json.dumps({"gate": "contract-matrix", "ok": True, "na": True,
                              "reason": "нет backend-диффа (UI/docs-only) — не требуется"}, ensure_ascii=False))
        else:
            print("gate-contract-matrix: PASS-NA — нет backend-диффа (UI/docs-only)")
        return 0
    path, errs = evaluate(a.root)
    ok = not errs
    if a.json:
        import json
        print(json.dumps({"gate": "contract-matrix", "ok": ok, "path": path, "errors": errs}, ensure_ascii=False))
    else:
        print(f"gate-contract-matrix: {'PASS' if ok else 'FAIL'}" + (f" ({path})" if path else ""))
        for e in errs:
            print("  -", e)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
