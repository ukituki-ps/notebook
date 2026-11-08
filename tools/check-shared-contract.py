#!/usr/bin/env python3
"""check-shared-contract — gate-shared-contract (ADR-KIT-090 A4).

Ловит подмену ОБЩЕГО контракта локальным: модуль определяет собственную схему
error-envelope (`Error`) или переопределяет общий компонент (`APIError`) вместо
`$ref` на `openapi/common.yaml`. Это класс дрейфа из F186: `gate-contract-sync`
сравнивал код с self-authored OpenAPI (drift=0), но модуль расходился с общим
каноном.

Правила (fail-close):
  1. модуль не имеет права переопределять компонент, объявленный в common.yaml;
  2. модуль не имеет права объявлять локальный `Error`/`ApiError`/`APIError`
     вместо `$ref` на common.yaml#APIError.

Exit: 0 = ok; 1 = нарушение; 2 = ошибка использования/IO.
"""
from __future__ import annotations

import argparse
import glob
import json
import os
import re
import subprocess
import sys

try:
    import yaml  # type: ignore
except Exception:  # pragma: no cover
    yaml = None

ERROR_NAME = re.compile(r"^(api_?error|error)$", re.IGNORECASE)


def _die(msg: str, code: int = 2) -> int:
    print(f"check-shared-contract: ERROR: {msg}", file=sys.stderr)
    return code


def _schemas(path):
    with open(path, "r", encoding="utf-8") as fh:
        doc = yaml.safe_load(fh) or {}
    comp = (doc.get("components") or {})
    schemas = comp.get("schemas") or {}
    return schemas if isinstance(schemas, dict) else {}


def check(common_path, modules):
    # modules может быть списком путей ИЛИ glob-паттерном (так его использует тест/CLI).
    if isinstance(modules, str):
        modules = glob.glob(modules)
    common_names = set(_schemas(common_path).keys())
    violations = []
    modules = sorted(modules)
    for m in modules:
        if os.path.abspath(m) == os.path.abspath(common_path):
            continue
        local = set(_schemas(m).keys())
        for name in sorted(local & common_names):
            violations.append(f"{m}: переопределяет общий компонент '{name}' (нужен $ref на common.yaml)")
        for name in sorted(local):
            if name not in common_names and ERROR_NAME.match(name):
                violations.append(f"{m}: локальный '{name}' вместо $ref common.yaml#APIError (подмена общего error-envelope)")
    return modules, common_names, violations


def build_parser():
    p = argparse.ArgumentParser(description="gate-shared-contract (ADR-KIT-090 A4)")
    p.add_argument("--common", default="openapi/common.yaml")
    p.add_argument("--modules", default="openapi/modules/*.yaml")
    p.add_argument("--new-from-rev", default="", help="проверять только модули, изменённые относительно REV (например origin/dev)")
    p.add_argument("--json", action="store_true")
    return p


def main(argv=None) -> int:
    a = build_parser().parse_args(argv)
    if yaml is None:
        return _die("PyYAML не установлен")
    if not os.path.isfile(a.common):
        return _die(f"common not found: {a.common}")
    base_modules = sorted(glob.glob(a.modules))
    modules = base_modules
    if a.new_from_rev:
        try:
            out = subprocess.check_output(
                ["git", "-C", os.getcwd(), "diff", "--name-only",
                 f"{a.new_from_rev}...HEAD", "--", "openapi/modules"],
                text=True, stderr=subprocess.PIPE)
        except Exception as exc:
            return _die(f"new-from-rev {a.new_from_rev}: {exc}")
        changed = [p for p in out.splitlines()
                   if p.startswith("openapi/modules/") and p.endswith((".yaml", ".yml"))]
        allowed = {os.path.abspath(p) for p in base_modules}
        modules = [p for p in changed if os.path.abspath(p) in allowed]
    try:
        modules, common_names, violations = check(a.common, modules)
    except (OSError, ValueError) as exc:
        return _die(str(exc))
    ok = not violations
    if a.json:
        print(json.dumps({"ok": ok, "common": a.common, "common_components": sorted(common_names),
                          "modules": len(modules), "violations": violations}, ensure_ascii=False))
    else:
        print(f"gate-shared-contract: {'OK' if ok else 'FAIL'} (modules={len(modules)})")
        for v in violations:
            print(f"  - {v}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
