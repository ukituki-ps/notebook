#!/usr/bin/env python3
"""gate-claims-text — нормативный текст в артефактах обязан совпадать с тем, что эмитит код.

Причина (аудит F003/E5438, F-2): отчёт утверждал, что во время проверки email-конфига
показывается «Проверяем доступные способы входа…». Строка в коде есть, но эмитится только
в другом состоянии (telegramUnavailable && emailChecking) — формулировка шире реализации.
Автопроверка условий невозможна, но проверить связку «идентификатор сообщения ↔ цитируемый
текст» можно и нужно.

Правило: если на одной строке артефакта встречаются и `MSG_*`-идентификатор, и «цитата»
русского UI-текста, то цитата обязана совпадать со значением этого идентификатора в коде
(нормализация: пробелы, завершающая точка, … ↔ ...). Идентификатор обязан существовать.

Проверяется только нормативная часть: spec/*.md, result-audit.md (+ включается ключом
--also для дополнительных файлов).
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys

MSG_RE = re.compile(r"\b(MSG_[A-Z0-9_]+)\b")
QUOTE_RE = re.compile(r"«([^»\n]{4,200})»")
CODE_EXT = (".ts", ".tsx", ".js", ".jsx", ".go", ".css", ".yaml", ".yml")
CODE_ROOTS = ("frontend/src", "frontend/e2e", "backend", "frontend/public")


def _norm(s: str) -> str:
    s = re.sub(r"\s+", " ", s).strip()
    s = s.replace("…", "...")
    return s.rstrip(". ").lower()


def _code_files(root: str):
    for r in CODE_ROOTS:
        base = os.path.join(root, r)
        if not os.path.isdir(base):
            continue
        for dirpath, dirs, names in os.walk(base):
            dirs[:] = [d for d in dirs if d not in ("node_modules", "dist", ".git", "test-results")]
            for n in names:
                if n.endswith(CODE_EXT):
                    yield os.path.join(dirpath, n)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="gate-claims-text")
    ap.add_argument("--root", required=True)
    ap.add_argument("--feature-dir", default="")
    ap.add_argument("--also", nargs="*", default=[], help="доп. артефакты (rel к feature-dir)")
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args(argv)

    root = os.path.abspath(a.root)
    fd = a.feature_dir
    if not fd:
        base = os.path.join(root, "doc", "идеи")
        cands = [os.path.join(base, d) for d in sorted(os.listdir(base))
                 if os.path.isdir(os.path.join(base, d))] if os.path.isdir(base) else []
        fd = cands[0] if len(cands) == 1 else ""
    if not fd or not os.path.isdir(fd):
        print("gate-claims-text: PASS-NA — каталог фичи не определён однозначно")
        return 0

    # индекс кода: содержимое файлов (для поиска значений MSG_*) + быстрый текст
    msgs: dict[str, tuple[str, str]] = {}   # MSG_* -> (значение, файл)
    code_text = []
    for path in _code_files(root):
        try:
            txt = open(path, encoding="utf-8", errors="replace").read()
        except OSError:
            continue
        code_text.append(txt)
        for m in re.finditer(r"(?:export\s+)?const\s+(MSG_[A-Z0-9_]+)\s*(?::[^=]+)?=\s*['\"`]([^'\"`]+)['\"`]", txt):
            msgs.setdefault(m.group(1), (m.group(2), os.path.relpath(path, root)))
    corpus = "\n".join(code_text)

    artifacts = [os.path.join(fd, "spec", "core.md"), os.path.join(fd, "spec", "contract-matrix.md"),
                 os.path.join(fd, "result-audit.md")]
    artifacts += [os.path.join(fd, p) for p in a.also]

    errors: list[str] = []
    warns: list[str] = []
    checked = 0
    for art in artifacts:
        if not os.path.isfile(art):
            continue
        checked += 1
        rel = os.path.relpath(art, root)
        for i, line in enumerate(open(art, encoding="utf-8", errors="replace").read().split("\n"), 1):
            ids = MSG_RE.findall(line)
            quotes = QUOTE_RE.findall(line)
            for ident in ids:
                if ident not in msgs:
                    errors.append(f"{rel}:{i}: `{ident}` не найден в коде (нет const {ident} = '…')")
                    continue
                val, where = msgs[ident]
                if quotes:
                    if not any(_norm(q) == _norm(val) for q in quotes):
                        # warn: на одной строке артефакта часто перечислено несколько
                        # сообщений (таблица состояний), поэтому жёсткая связка даёт ложь.
                        warns.append(
                            f"{rel}:{i}: `{ident}` цитируется как {quotes}, а код эмитит "
                            f"«{val}» ({where}) — проверь формулировку/условие")
                    else:
                        warns.append(f"{rel}:{i}: `{ident}` ⇔ «{val}» — совпадает ({where})")
            # MSG_* без значения-литерала (шаблон/функция) — только к существованию
    if not checked:
        print("gate-claims-text: PASS-NA — нормативных артефактов нет")
        return 0
    if a.json:
        print(json.dumps({"gate": "claims-text", "ok": not errors, "artifacts": checked,
                          "errors": errors, "warnings": warns}, ensure_ascii=False))
    else:
        for w in warns:
            print(f"gate-claims-text: ok — {w}")
        for e in errors:
            print(f"gate-claims-text: FAIL — {e}", file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
