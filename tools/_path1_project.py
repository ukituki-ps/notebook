#!/usr/bin/env python3
"""Per-project adapter-контракт кита path-1 (ADR-KIT-090/091 portability).

Зачем: скрипты кита (canary, fault-catalog, no-self-mock, graph-actualize,
feature-dir, preview-deploy, e2e) исторически были зашиты под layout
archkit-монорепо (`nexus/`, `nexus-ui/src`, `deploy/stands/ci/deploy-stand.sh`).
Прикладной репозиторий (kh_pg: `backend/`, `frontend/`) из-за этого либо
падал, либо — хуже — проходил гейт вакуумно (ложный зелёный).

Проект-прикладной репозиторий объявляет свои пути/команды в `path1.project.json`
в КОРНЕ репо. Кит-скрипты читают контракт здесь и не хардкодят layout.

Файл опционален: без него действуют DEFAULTS (= прежнее поведение archkit),
поэтому существующие проекты и тесты не ломаются.

Пример (app-репо):
{
  "version": 1,
  "no_self_mock": {"go_roots": ["backend"], "js_roots": ["frontend/src"]},
  "graph": {"source_roots": ["frontend"]},
  "detectors": {"go_roots": ["backend"]},
  "feature_dir": {"artifact_globs": ["doc/идеи/*/{name}", "doc/идеи/*/*/{name}" ]},
  "e2e": {"frontend_dir": "frontend", "command": "bash tools/run-stand-e2e.sh {execution_id}"},
  "deploy": {"stand_command": "bash deploy/stands/ci/deploy-stand.sh {stand} {ref}"},
  "mobile": {"command": "bash tools/mobile-run.sh {execution_id}"}
}

API:
    load(root) -> dict            # merged with DEFAULTS (ключ "_source" — путь файла или None)
    get(root, "a.b.c", default)   # точечный доступ
CLI:
    python3 tools/_path1_project.py --root . --get no_self_mock.go_roots
    python3 tools/_path1_project.py --root . --line no_self_mock.go_roots
"""
from __future__ import annotations

import argparse
import json
import os
import sys

CONFIG_NAME = "path1.project.json"

# DEFAULTS = layout archkit-монорепо (обратная совместимость).
DEFAULTS: dict = {
    "version": 1,
    # gate-no-self-mock: корни, где ищем мок юнита под тестом.
    "no_self_mock": {
        "go_roots": ["nexus"],
        "js_roots": ["nexus-ui/src"],
    },
    # gate-graph-actualized: какие пути считаются UI-поверхностью проекта.
    "graph": {
        "source_roots": ["nexus-ui"],
    },
    # детекторы каталога отказов (go test по корням).
    "detectors": {
        "go_roots": ["nexus"],
        "catalog_dir": "audit/fault-catalog",
    },
    # канарейки («подложи дефект — детектор обязан упасть»).
    # items[].seed / items[].detect — shell-команды; {worktree} подставляется движком.
    "canaries": {
        "clean_units": [],
        "items": [],
    },
    # резолвер каталога текущей фичи: шаблоны glob с {name}.
    "feature_dir": {
        "artifact_globs": ["doc/идеи/*/{name}"],
    },
    # выкат ветки на арендованный стенд (команда {stand} {ref}).
    # stand_command для app-репо НЕ наследуется из archkit layout: default
    # применяется только если в корне реально есть archkit deploy/stands/ci.
    "deploy": {
        "stand_command": "bash deploy/stands/ci/deploy-stand.sh {stand} {ref}",
        "project_id": "",
    },
    # E2E на превью-стенде.
    "e2e": {
        "frontend_dir": "nexus-ui",
        "command": "",
    },
    # мобильная проба (Maestro/аналог).
    "mobile": {
        "command": "",
    },
}


def _deep_merge(base: dict, override: dict) -> dict:
    out = dict(base)
    for k, v in (override or {}).items():
        if isinstance(v, dict) and isinstance(out.get(k), dict):
            out[k] = _deep_merge(out[k], v)
        else:
            out[k] = v
    return out


def config_path(root: str = ".") -> str:
    return os.path.join(os.path.abspath(root), CONFIG_NAME)


def load(root: str = ".") -> dict:
    """Контракт проекта, слитый с DEFAULTS. Отсутствие файла — не ошибка."""
    p = config_path(root)
    data: dict = {}
    if os.path.isfile(p):
        try:
            with open(p, encoding="utf-8") as f:
                data = json.load(f) or {}
        except Exception as e:  # noqa: BLE001 - контракт битый → явная ошибка, не тихий дефолт
            raise SystemExit(f"path1.project.json: не читается ({p}): {e}")
    cfg = _deep_merge(DEFAULTS, data)
    cfg["_source"] = p if os.path.isfile(p) else None
    # E2703/W5: app-репо без явного deploy.stand_command не должен молча
    # выкатываться archkit-командой (уводило target repo в 4e3d98c0).
    deploy_cfg = data.get("deploy") if isinstance(data.get("deploy"), dict) else {}
    archkit_layout = os.path.isfile(os.path.join(root, "deploy", "stands", "ci", "deploy-stand.sh"))
    if not archkit_layout and not str(deploy_cfg.get("stand_command") or "").strip():
        cfg["deploy"]["stand_command"] = ""
    return cfg


def get(root: str, path: str, default=None):
    cur = load(root)
    for part in path.split("."):
        if not isinstance(cur, dict) or part not in cur:
            return default
        cur = cur[part]
    return cur


def _fmt_line(v) -> str:
    if v is None:
        return ""
    if isinstance(v, list):
        return " ".join(str(x) for x in v)
    if isinstance(v, bool):
        return "true" if v else "false"
    return str(v)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="path-1 per-project adapter contract")
    ap.add_argument("--root", default=".")
    ap.add_argument("--get", help="точечный путь, напр. no_self_mock.go_roots")
    ap.add_argument("--line", help="как --get, но одна строка (список через пробел)")
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args(argv)
    if a.line:
        print(_fmt_line(get(a.root, a.line)))
        return 0
    if a.get:
        v = get(a.root, a.get)
        print(json.dumps(v, ensure_ascii=False) if a.json else _fmt_line(v))
        return 0
    print(json.dumps(load(a.root), ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
