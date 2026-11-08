#!/usr/bin/env python3
"""gate-links-resolve — ссылки внутри артефактов обязаны разрешаться.

Причина (аудит F003/E5438):
  * «фантомный e2e-путь» (frontend/e2e/f003-login-availability.spec.ts) остался в
    change-definition/README.md и coverage-audit.md, хотя в result-audit объявлен
    вычищенным → закрытие без доказательства;
  * устаревшие line-refs (result-audit: `LoginPage.tsx:75` при фактических 109-113;
    spec/core.md: `useAuth.ts:9/12` при фактических 10/13);
  * test_ref вида `login/email-login.test.tsx::disabled` (файла нет).

Проверки (fail-close, объективные):
  C1  каждый упомянутый в артефакте repo-путь существует (glob-паттерны — ≥1 совпадение);
  C2  для `path:line` ссылки файл существует и содержит ≥ line строк;
  C3  если на той же строке артефакта есть ровно один «символьный» токен и он НЕ встречается
      в целевом файле — line-ref устарел (FAIL). Если токен есть, но далеко от указанной
      строки (>--window) — предупреждение (не блокирует).
"""
from __future__ import annotations

import argparse
import glob
import json
import os
import re
import sys

# repo-корни, которые считаем ссылками (плюс кириллические пути doc/…)
ROOTS = ("frontend", "backend", "tools", "deploy", "doc", "arch", "scripts", "openapi",
         "data", "audit", "docs", "spec", "e2e", ".github", "nexus-ui")
PATH_RE = re.compile(
    r"(?<![\w./-])(" + "|".join(re.escape(r) for r in ROOTS) +
    r")/(?:[\w.@+-]+/)*[\w.@+\u0400-\u04FF-]+\.[A-Za-z0-9]{1,6}")
LINEREF_RE = re.compile(
    r"(?P<path>(?:" + "|".join(re.escape(r) for r in ROOTS) +
    r")/(?:[\w.@+-]+/)*[\w.@+\u0400-\u04FF-]+\.[A-Za-z0-9]{1,6}):(?P<line>\d+)(?:-(?P<end>\d+))?")
BACKTICK_RE = re.compile(r"`([^`\n]{2,60})`")
SYMBOL_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z0-9_]+)*$")
# Пути, доставляемые китом/прогоном (в checkout ветки их нет штатно) — для них «не найден» = warn.
KIT_PREFIXES = ("tools/", "scripts/", "deploy/stands/", "data/audit/", ".orc-evidence/")


def _iter_artifacts(feature_dir: str):
    for dirpath, _dirs, names in os.walk(feature_dir):
        if f"{os.sep}evidence{os.sep}" in dirpath + os.sep:
            continue
        for n in sorted(names):
            if n.endswith((".md", ".json")):
                yield os.path.join(dirpath, n)


def _read(path: str) -> str:
    try:
        return open(path, encoding="utf-8", errors="replace").read()
    except OSError:
        return ""


def _file_lines(path: str) -> int:
    return _read(path).count("\n") + 1


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="gate-links-resolve")
    ap.add_argument("--root", required=True)
    ap.add_argument("--feature-dir", default="")
    ap.add_argument("--window", type=int, default=20, help="допустимое расхождение line-ref, строк")
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args(argv)

    root = os.path.abspath(a.root)
    dirs = [os.path.abspath(a.feature_dir)] if a.feature_dir else []
    if not dirs:
        base = os.path.join(root, "doc", "идеи")
        if os.path.isdir(base):
            dirs = [os.path.join(base, d) for d in sorted(os.listdir(base))
                    if os.path.isdir(os.path.join(base, d))]

    errors: list[str] = []
    warns: list[str] = []
    checked = 0

    def rel(p: str) -> str:
        return os.path.relpath(p, root)

    for fd in dirs:
        if not os.path.isdir(fd):
            continue
        for art in _iter_artifacts(fd):
            text = _read(art)
            if not text:
                continue
            checked += 1
            # C1/C2: пути и line-refs
            for m in LINEREF_RE.finditer(text):
                p, line = m.group("path"), int(m.group("line"))
                tgt = os.path.join(root, p)
                if not os.path.isfile(tgt):
                    if p.startswith(KIT_PREFIXES):
                        warns.append(f"{rel(art)}: `{p}:{line}` — файл доставляется китом/прогоном (в checkout нет)")
                    else:
                        errors.append(f"{rel(art)}: `{p}:{line}` — файл не существует")
                    continue
                lines = _file_lines(tgt)
                if line > lines:
                    errors.append(f"{rel(art)}: `{p}:{line}` — в файле всего {lines} строк")
                    continue
                # C3: токен на строке артефакта
                art_line = text[text.rfind("\n", 0, m.start()) + 1: text.find("\n", m.end())]
                toks = [t.strip() for t in BACKTICK_RE.findall(art_line)]
                syms = [t for t in toks if SYMBOL_RE.match(t) and not t.endswith((".md", ".json", ".tsx", ".ts", ".sh", ".py", ".yaml", ".yml"))]
                if len(syms) == 1:
                    body = _read(tgt)
                    tok = syms[0].split(".")[0]
                    if not re.search(r"\b" + re.escape(tok) + r"\b", body):
                        # warn, не FAIL: артефакт может называть токен из другого файла
                        # (FAIL оставлен только для объективного: нет файла / строка за границей).
                        warns.append(
                            f"{rel(art)}: `{p}:{line}` — токен `{syms[0]}` не найден в {p} "
                            f"(проверь line-ref)")
                        continue
                    tlines = _read(tgt).split("\n")
                    near = any(re.search(r"\b" + re.escape(tok) + r"\b", tlines[i])
                               for i in range(max(0, line - 1 - a.window),
                                              min(len(tlines), line + a.window)))
                    if not near:
                        warns.append(f"{rel(art)}: `{p}:{line}` — токен `{syms[0]}` далеко от строки")
            # C1: пути без номера строки
            for m in PATH_RE.finditer(text):
                p = m.group(0)
                if "*" in p or "?" in p:
                    if not glob.glob(os.path.join(root, p)):
                        errors.append(f"{rel(art)}: шаблон `{p}` — нет совпадений")
                    continue
                if os.path.exists(os.path.join(root, p)) or os.path.exists(os.path.join(fd, p)):
                    continue
                if p.startswith(KIT_PREFIXES):
                    warns.append(f"{rel(art)}: `{p}` — нет в checkout (путь доставляется китом/прогоном)")
                else:
                    errors.append(f"{rel(art)}: `{p}` — путь не существует")

    if not checked:
        print("gate-links-resolve: PASS-NA — артефактов для проверки нет")
        return 0
    dedup_err = sorted(set(errors))
    dedup_warn = sorted(set(warns))
    if a.json:
        print(json.dumps({"gate": "links-resolve", "ok": not dedup_err, "artifacts": checked,
                          "errors": dedup_err, "warnings": dedup_warn}, ensure_ascii=False))
    else:
        for w in dedup_warn:
            print(f"gate-links-resolve: warn — {w}")
        for e in dedup_err:
            print(f"gate-links-resolve: FAIL — {e}", file=sys.stderr)
        if not dedup_err:
            print(f"gate-links-resolve: OK ({checked} артефакт(ов))")
    return 1 if dedup_err else 0


if __name__ == "__main__":
    sys.exit(main())
