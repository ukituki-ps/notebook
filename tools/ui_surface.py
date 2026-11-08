#!/usr/bin/env python3
"""ui_surface — есть ли в ветке изменения UI-поверхности (для условных гейтов).

Зачем: часть проверок пути (E2E-превью s20c, evidence-authentic s24, UI-аудит s22a) осмысленны
только для инкрементов, меняющих UI. Для backend-only инкремента они должны честно отдавать
`PASS-NA` с причиной — иначе прогон упирается в стену и провоцирует подделку доказательств
(инцидент E7141/F193: `gate-e2e-preview: FAIL — нет scenario-evidence.json`).

Контракт (важно для fail-closed):
  exit 0 — изменения UI-поверхности ЕСТЬ  → вызывающий гейт обязан работать строго;
  exit 1 — изменений UI НЕТ               → гейт может вернуть PASS-NA с reason;
  exit 2 — не удалось определить (нет git/base/конфига) → вызывающий обязан работать СТРОГО.

Логика — та же, что в `check-graph-actualized.py` (единственный источник правды по «UI-поверхности»):
  * корни UI — `path1.project.json` → `graph.source_roots` (по умолчанию `nexus-ui`);
  * UI-файлы — расширения .tsx/.jsx/.vue/.css/.scss/.less под корнем, кроме тестов
    (__tests__/, .test., .spec., /tests/, /e2e/, cypress/) и кроме конфигов/сборки
    (.config.ts/.js, .tsbuildinfo, .d.ts);
  * сравнение — `git diff --name-only {base}...HEAD`.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys

DEFAULT_SOURCE_ROOTS = ["nexus-ui"]
UI_EXT = (".tsx", ".jsx", ".vue", ".css", ".scss", ".less")
TEST_MARK = ("__tests__/", ".test.", ".spec.", "/tests/", "/e2e/", "cypress/")
SKIP_EXT = (".config.ts", ".config.js", ".tsbuildinfo", ".d.ts")


def _project_cfg(root: str) -> dict:
    p = os.path.join(root, "path1.project.json")
    if not os.path.isfile(p):
        return {}
    try:
        return json.loads(open(p, encoding="utf-8").read())
    except (OSError, ValueError):
        return {}


def source_roots(root: str) -> list[str]:
    cfg = _project_cfg(root).get("graph") or {}
    roots = cfg.get("source_roots") or DEFAULT_SOURCE_ROOTS
    return [str(r).strip("/") for r in roots if str(r).strip()]


def ui_platform(root: str) -> str:
    p = os.path.join(root, "path1.ui.json")
    if os.path.isfile(p):
        try:
            m = re.search(r'"platform"\s*:\s*"([^"]*)"', open(p, encoding="utf-8").read())
            if m:
                return m.group(1).strip().lower()
        except OSError:
            pass
    return str((_project_cfg(root).get("ui") or {}).get("platform") or "").strip().lower()


def is_ui(path: str, roots: list[str]) -> bool:
    if path.endswith(SKIP_EXT) or any(m in path for m in TEST_MARK):
        return False
    if not path.endswith(UI_EXT):
        return False
    return any(path.startswith(r + "/") for r in roots)


def changed_files(root: str, base: str) -> list[str] | None:
    try:
        r = subprocess.run(["git", "-c", "core.quotepath=false", "diff", "--name-only", f"{base}...HEAD"],
                           cwd=root, capture_output=True, text=True, timeout=60)
    except (OSError, subprocess.SubprocessError):
        return None
    if r.returncode != 0:
        return None
    return [l.strip() for l in r.stdout.splitlines() if l.strip()]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=".")
    ap.add_argument("--base", default="origin/main")
    ap.add_argument("--print-reason", action="store_true")
    a = ap.parse_args()
    root = os.path.abspath(a.root)

    plat = ui_platform(root)
    if plat in ("none",):
        if a.print_reason:
            print(f"проект объявил platform={plat} (UI отсутствует)")
        return 1

    roots = source_roots(root)
    if not roots:
        if a.print_reason:
            print("graph.source_roots пуст — UI-поверхность не определена")
        return 2

    files = changed_files(root, a.base)
    if files is None:
        if a.print_reason:
            print(f"не удалось получить diff {a.base}...HEAD (fail-closed: считаем, что UI менялся)")
        return 2

    ui = [f for f in files if is_ui(f, roots)]
    if ui:
        if a.print_reason:
            print(f"изменены UI-файлы ({len(ui)}): {', '.join(ui[:5])}")
        return 0
    if a.print_reason:
        print(f"изменений UI-поверхности нет (корни: {', '.join(roots)}; файлов в diff: {len(files)})")
    return 1


if __name__ == "__main__":
    sys.exit(main())
