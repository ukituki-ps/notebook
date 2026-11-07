#!/usr/bin/env python3
"""check-requirement-trace — machine-гейт трассируемости «просил человек ↔ делаем».

F190 C-22. Закрывает дефект E2669/F004: гейты проверяли согласованность артефактов
между собой, а не с сырым запросом человека (3b истолкован молча, 3c потерян).

Артефакт: doc/идеи/<F>/intent-trace.json (его публикует s07.requirements_reconcile).

Правила (fail-close):
  * файл существует и валидный JSON-объект;
  * items[] — непустой массив;
  * каждый item: item_id, raw_quote, our_interpretation (непустые), verdict ∈ enum;
  * verdict ∈ {reinterpreted, added} ТРЕБУЕТ confirmed_by_human ∈ {yes, edited}
    (переинтерпретация/добавление без явного подтверждения человека — блок);
  * при заданном --request: source_items_total (если объявлен) ≥ числа пунктов
    сырого запроса; len(items) ≥ source_items_total (каждый пункт имеет запись).

Exit: 0 — pass; 1 — fail-close; 2 — ошибка окружения/аргументов.
"""
import argparse
import json
import re
import sys

VERDICTS = {"match", "reinterpreted", "missing", "dropped"}
REQUIRED_FIELDS = ("item_id", "raw_quote", "our_interpretation", "verdict")
CONFIRM_VALUES = {"yes", "edited"}

# Пункт сырого запроса: строка вида «1.» / «1)» / «- » / «* » с непустым текстом.
REQUEST_ITEM_RE = re.compile(r"^\s*(?:\d+[.)]|[-*])\s+\S")


def count_request_items(path):
    try:
        with open(path, encoding="utf-8") as fh:
            return sum(1 for line in fh if REQUEST_ITEM_RE.match(line))
    except OSError:
        return None


def fail(msg):
    print(f"gate-requirement-trace: FAIL — {msg}", file=sys.stderr)
    sys.exit(1)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--trace", required=True, help="путь к intent-trace.json")
    ap.add_argument("--request", default="", help="путь к сырому запросу человека (feature-request.md)")
    args = ap.parse_args()

    trace_path = (args.trace or "").strip()
    if not trace_path or trace_path == "/nonexistent":
        fail("нет intent-trace.json (запусти s07.requirements_reconcile)")

    try:
        with open(trace_path, encoding="utf-8") as fh:
            doc = json.load(fh)
    except FileNotFoundError:
        fail(f"intent-trace.json не найден: {trace_path}")
    except (OSError, json.JSONDecodeError) as exc:
        fail(f"intent-trace.json нечитаем: {exc}")

    if not isinstance(doc, dict):
        fail("intent-trace.json должен быть JSON-объектом")

    items = doc.get("items")
    if not isinstance(items, list) or not items:
        fail("items[] пуст или отсутствует (нет ни одной записи сверки)")

    problems = []
    for idx, item in enumerate(items):
        if not isinstance(item, dict):
            problems.append(f"items[{idx}] — не объект")
            continue
        for field in REQUIRED_FIELDS:
            val = item.get(field)
            if not isinstance(val, str) or not val.strip():
                problems.append(f"items[{idx}].{field} пуст/отсутствует")
        verdict = item.get("verdict")
        if isinstance(verdict, str) and verdict not in VERDICTS:
            problems.append(f"items[{idx}].verdict='{verdict}' вне {sorted(VERDICTS)}")
        needs_confirm = verdict in ("reinterpreted", "added") or item.get("added") is True
        if needs_confirm:
            if item.get("confirmed_by_human") not in CONFIRM_VALUES:
                problems.append(
                    f"items[{idx}] ({item.get('item_id', '?')}): verdict/added требует "
                    "подтверждения человеком (confirmed_by_human ∈ {yes,edited})"
                )

    source_total = doc.get("source_items_total")
    if isinstance(source_total, int) and source_total > 0 and len(items) < source_total:
        problems.append(f"items={len(items)} < source_items_total={source_total} (не каждый пункт учтён)")

    req_count = count_request_items(args.request) if args.request else None
    if req_count:
        if isinstance(source_total, int):
            if source_total < req_count:
                problems.append(
                    f"source_items_total={source_total} < числа пунктов сырого запроса={req_count} "
                    "(часть запроса не попала в сверку)"
                )
        elif len(items) < req_count:
            problems.append(
                f"items={len(items)} < числа пунктов сырого запроса={req_count} (нет source_items_total)"
            )

    if problems:
        print("gate-requirement-trace: FAIL", file=sys.stderr)
        for p in problems:
            print(f"  - {p}", file=sys.stderr)
        sys.exit(1)

    n_conf = sum(1 for it in items if isinstance(it, dict) and it.get("confirmed_by_human") in CONFIRM_VALUES)
    print(f"gate-requirement-trace: PASS items={len(items)} confirmed_by_human={n_conf}")


if __name__ == "__main__":
    main()
