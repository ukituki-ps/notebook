#!/usr/bin/env python3
"""gate-spec-coverage — покрытие пунктов контракта оракулами (ADR-KIT-090; «9.5» step 3).

Каждая строка `contract-matrix.md` обязана иметь ИСПОЛНИМЫЙ `test_ref`
(cmd:/sh:/<path>::<Test> или явный `test`-столбец со ссылкой на тест), а каждый
негативный/краевой кейс — покрыт (ссылка на тест или пометка `n/a: <причина>`).
Иначе спека не «доказана» → conformance недобирает балл.
"""
import argparse, glob, json, os, re, sys
import sys as _sys, os as _os
_sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))
from _feature_dir import resolve as _resolve


REF_RE = re.compile(r"(cmd:|sh:|::\w|go test|npx vitest|playwright|pytest)", re.I)


def _find_matrix(root):
    for pat in ("spec/contract-matrix.md", "contract-matrix.md"):
        _p, _e = _resolve(root, pat)
        h = [_p] if _p else []
        if h:
            return h[0]
    return None


def _rows(text):
    rows, header = [], None
    for line in text.splitlines():
        s = line.strip()
        if not s.startswith("|"):
            continue
        cells = [c.strip() for c in s.strip("|").split("|")]
        if all(re.fullmatch(r":?-{2,}:?", c) for c in cells if c):
            continue
        if header is None:
            header = [c.lower() for c in cells]; continue
        rows.append(dict(zip(header, cells)))
    return rows


def _backend_diff(root: str) -> bool:
    """True, если в ветке есть изменения backend-поверхности (Go/SQL/openapi/proto/yaml).
    UI/docs-only фича → contract-matrix/spec-coverage не требуются (PASS-NA)."""
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
        return True  # база неизвестна → NA не объявляем (fail-open запрещён)
    mb = run(["merge-base", base, "HEAD"]).strip() or base
    pat = _re.compile(r"(\.go$|\.sql$|\.proto$|openapi|\.ya?ml$)")
    for f in run(["diff", "--name-only", f"{mb}...HEAD"]).splitlines():
        f = f.strip()
        if not f or f.startswith("doc/"):
            continue
        if pat.search(f):
            return True
    return False

def evaluate(root):
    path = _find_matrix(root)
    if not path:
        return ["нет contract-matrix.md"]
    text = open(path, encoding="utf-8").read()
    errs = []
    rows = _rows(text)
    if not rows:
        errs.append("таблица контракта пуста")
    for i, r in enumerate(rows, 1):
        ref = r.get("test") or r.get("test_ref") or ""
        joined = " ".join(r.values())
        if not (ref and REF_RE.search(ref)) and not REF_RE.search(joined):
            errs.append(f"строка {i} ({r.get('endpoint','?')} {r.get('method','')}) без исполнимого test_ref")
    # негативные кейсы
    m = re.search(r"#+\s*(negativ|краев|edge|негатив)[^\n]*\n(.*?)(\n#|\Z)", text, re.I | re.S)
    if not m:
        errs.append("нет секции негативных/краевых кейсов")
    else:
        for l in m.group(2).splitlines():
            s = l.strip()
            if s.startswith(("-", "*")):
                if not REF_RE.search(s) and "n/a" not in s.lower():
                    errs.append(f"негатив без оракула/n-a: {s[:70]}")
    return errs


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=".")
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args(argv)
    if not _backend_diff(a.root):
        if a.json:
            print(json.dumps({"gate": "spec-coverage", "ok": True, "na": True,
                              "reason": "нет backend-диффа (UI/docs-only) — не требуется"}, ensure_ascii=False))
        else:
            print("gate-spec-coverage: PASS-NA — нет backend-диффа (UI/docs-only)")
        return 0
    errs = evaluate(a.root)
    ok = not errs
    if a.json:
        print(json.dumps({"gate": "spec-coverage", "ok": ok, "errors": errs}, ensure_ascii=False))
    else:
        print(f"gate-spec-coverage: {'PASS' if ok else 'FAIL'}")
        for e in errs:
            print("  -", e)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
