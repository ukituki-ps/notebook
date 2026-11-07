#!/usr/bin/env python3
"""check-test-ref-runnable — gate-test-ref-runnable (ADR-KIT-090 A2).

Проверяет, что каждый active-инвариант в брифе/манифесте имеет
ИСПОЛНИМО-ОПРОВЕРЖИМЫЙ `test_ref` ДО кода, чтобы не ловить fail-close на s20a
(инцидент E8473: голый путь vitest в INV-5 → `gate-invariant-enforced` fail).

Разрешённые формы `test_ref` (как в seam `invariantTestRunner`):
  * `cmd:<shell>`      — shell-команда;
  * `sh:<shell>`       — синоним;
  * `<path>::<Test>`   — файл существует и содержит символ теста.

Запрещено: голый путь без `::`/`cmd:`/`sh:`; пустой test_ref.

Вход: YAML/JSON с `invariants: [{id, status, test_ref}]` (top-level или вложенно).
Exit: 0 = ok; 1 = нарушение/пусто (fail-close); 2 = ошибка использования/IO.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys

try:
    import yaml  # type: ignore
except Exception:  # pragma: no cover
    yaml = None

ACTIVE = {"active", "", None}


def _die(msg: str, code: int = 2) -> int:
    print(f"check-test-ref-runnable: ERROR: {msg}", file=sys.stderr)
    return code


def _load(path: str):
    with open(path, "r", encoding="utf-8") as fh:
        text = fh.read()
    if path.endswith((".yaml", ".yml")):
        if yaml is None:
            raise RuntimeError("PyYAML нужен для .yaml")
        return yaml.safe_load(text)
    return json.loads(text)


def _find_invariants(doc):
    if isinstance(doc, dict):
        if isinstance(doc.get("invariants"), list):
            return doc["invariants"]
        for v in doc.values():
            found = _find_invariants(v)
            if found:
                return found
    elif isinstance(doc, list):
        for v in doc:
            found = _find_invariants(v)
            if found:
                return found
    return None


def _symbol_in_file(path: str, test: str) -> bool:
    if not os.path.isfile(path):
        return False
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as fh:
            body = fh.read()
    except OSError:
        return False
    base = test.split("/")[-1]
    # Go: func TestX / TypeScript: test('name' / it('name' / describe(
    patterns = [rf"func\s+{re.escape(base)}\b", rf"\b{re.escape(base)}\b"]
    return any(re.search(p, body) for p in patterns)


def _build_constraint(path: str) -> str:
    """Возвращает build-constraint (Go) файла, если задан в первых строках."""
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as fh:
            head = fh.read(700)
    except OSError:
        return ""
    for line in head.splitlines()[:8]:
        s = line.strip()
        if s.startswith("//go:build") or s.startswith("// +build"):
            return s
    return ""


def _excluded_by_default(tag: str) -> bool:
    # Тег исключает файл из дефолтного `go test ./...` → «no tests to run» + exit 0.
    markers = ("integration", "e2e", "manual", "!linux", "!amd64")
    return any(m in tag for m in markers)


def evaluate(invariants, root):
    errors = []
    checked = 0
    for inv in invariants or []:
        if not isinstance(inv, dict):
            continue
        if inv.get("status") not in ACTIVE:
            continue
        checked += 1
        iid = inv.get("id", "?")
        ref = (inv.get("test_ref") or "").strip()
        if not ref:
            errors.append(f"{iid}: пустой test_ref")
            continue
        if ref.startswith(("cmd:", "sh:")):
            c = ref.split(":", 1)[1].strip()
            if not c:
                errors.append(f"{iid}: пустая команда в test_ref")
            else:
                # Review F-INV-1: команда-заглушка всегда exit 0 (true/:) — это вакуумный pass,
                # запрещённый ADR-KIT-075. Требуем проверку, которая может УПАСТЬ.
                import re as _re
                _noop = _re.compile(r"^(?:/usr?/bin/|/bin/)?(?:true|:)(?:\s*;.*)?$|^exit\s+0(?:\s*;.*)?$")
                _head = c.split("#", 1)[0].strip()
                # Заглушка = первая команда всегда-успешна И в цепочке нет содержательной проверки (F-04):
                # ловим `true`, `:`, `/bin/true`, `true; echo ok`, `exit 0` — но НЕ `true && grep -q x f`.
                _first = _head.split("&&")[0].strip()
                if _noop.match(_first) and not _re.search(r"(grep|test|go |cargo|python|npm |npx |pytest|maestro|playwright|axe|\[ )", _head):
                    errors.append(f"{iid}: test_ref '{c}' — команда-заглушка (всегда exit 0); нужна проверка, которая может упасть")
            continue
        if "::" not in ref:
            errors.append(f"{iid}: голый путь '{ref}' (нужен cmd:/sh:/<path>::<Test>)")
            continue
        path, test = ref.split("::", 1)
        path = path.strip()
        test = test.strip()
        abspath = path if os.path.isabs(path) else os.path.join(root, path)
        if not test:
            errors.append(f"{iid}: пустой символ теста в '{ref}'")
        elif not _symbol_in_file(abspath, test):
            errors.append(f"{iid}: символ теста '{test}' не найден в {path}")
        else:
            tag = _build_constraint(abspath)
            if tag and _excluded_by_default(tag):
                errors.append(
                    f"{iid}: test_ref '{ref}' — файл под build-тегом ({tag}); "
                    "голый путь при дефолтном прогоне даст 'no tests to run' (exit 0, false-pass). "
                    "Используй cmd:/sh: с нужными -tags (напр. cmd:go test -tags integration ...)"
                )
    return checked, errors


def build_parser():
    p = argparse.ArgumentParser(description="gate-test-ref-runnable (ADR-KIT-090 A2)")
    p.add_argument("--invariants", required=True, help="YAML/JSON с invariants[]")
    p.add_argument("--root", default=".", help="корень для относительных test_ref")
    p.add_argument("--allow-empty", action="store_true", help="пусто = ok (по умолчанию fail-close)")
    p.add_argument("--json", action="store_true")
    return p


def main(argv=None) -> int:
    a = build_parser().parse_args(argv)
    try:
        doc = _load(a.invariants)
    except (OSError, ValueError, RuntimeError) as exc:
        return _die(str(exc))
    invs = _find_invariants(doc)
    if invs is None:
        return _die(f"в {a.invariants} не найден ключ invariants[]")
    checked, errors = evaluate(invs, a.root)
    if checked == 0 and not a.allow_empty:
        errors.append("активных инвариантов нет (fail-close: пусто ≠ ok)")
    ok = not errors
    if a.json:
        print(json.dumps({"ok": ok, "active_invariants": checked, "errors": errors}, ensure_ascii=False))
    else:
        print(f"gate-test-ref-runnable: {'OK' if ok else 'FAIL'} (active={checked})")
        for e in errors:
            print(f"  - {e}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
