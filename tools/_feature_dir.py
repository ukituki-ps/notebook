#!/usr/bin/env python3
"""Единый детерминированный резолвер каталога текущей фичи.

Зачем: в репозитории одновременно живёт много фич (`doc/идеи/F1..Fn`), и гейт,
выбирающий артефакт «первым по glob», легко зеленеет на ЧУЖОМ артефакте
(инцидент E6355/F189: gate-contract-matrix проверил F188).

Порядок разрешения (первый успех выигрывает):
  1. `$ORC_FEATURE_DIR` — явный каталог (напр. из ORC), если `<dir>/<name>` есть.
  2. git: файлы под `doc/идеи/`, изменённые в текущей ветке относительно
     merge-base с `origin/main`/`main`; среди затронутых каталогов — ровно один
     содержит `<name>`.
  3. единственный каталог среди `doc/идеи/*/<name>`.
Иначе — fail-close: `not_found` (нет артефакта) или `ambiguous` (несколько).

API:
    resolve(root, name) -> (path|None, error|None)
    error ∈ {"not_found", "ambiguous", ...}
CLI:
    python3 tools/_feature_dir.py --root . --name spec/contract-matrix.md
    → печатает путь (относительно root) и exit 0; иначе печатает причину, exit 2.
"""
from __future__ import annotations

import argparse
import glob
import os
import re
import subprocess
import sys

_DIR = os.path.dirname(os.path.abspath(__file__))
IDEA_GLOB = os.path.join("doc", "идеи")
# Дефолт = layout archkit (см. path1.project.json → feature_dir.artifact_globs).
DEFAULT_ARTIFACT_GLOBS = ["doc/идеи/*/{name}"]


def _rel(root: str, p: str) -> str:
    r = os.path.relpath(p, root)
    return r if not r.startswith("..") else p


def _artifact_globs(root: str) -> list[str]:
    """Шаблоны путей артефакта фичи из контракта проекта (с {name}).

    Прикладной репо объявляет вложенную раскладку, напр.
    ["doc/идеи/*/{name}", "doc/идеи/*/*/{name}"] для doc/идеи/<F>/f00N.NN/<name>.
    """
    try:
        if _DIR not in sys.path:
            sys.path.insert(0, _DIR)
        import _path1_project as proj  # type: ignore

        g = proj.get(root, "feature_dir.artifact_globs")
        if isinstance(g, list) and g:
            return [str(x) for x in g]
    except Exception:
        pass
    return list(DEFAULT_ARTIFACT_GLOBS)


def _candidates(root: str, name: str) -> list[str]:
    found: set[str] = set()
    for tmpl in _artifact_globs(root):
        pat = os.path.join(root, tmpl.format(name=name))
        for p in glob.glob(pat):
            if os.path.isfile(p):
                found.add(p)
    return sorted(found)


def _idea_dir(root: str, path: str) -> str:
    """Каталог фичи (=путь относительно doc/идеи), напр. `F1-alpha` или `F/F001.63`."""
    rp = _rel(root, path).replace("\\", "/")
    parts = rp.split("/")
    if len(parts) >= 3 and parts[0] == "doc" and parts[1] == "идеи":
        d = "/".join(parts[2:-1])
        return d or parts[2]
    return ""


def _related(a: str, b: str) -> bool:
    """Один каталог или вложен друг в друга (F/ и F/f001.63)."""
    if not a or not b:
        return False
    return a == b or a.startswith(b + "/") or b.startswith(a + "/")


def _git_changed_dirs(root: str) -> set[str]:
    """Каталоги фич под doc/идеи, затронутые в текущей ветке (относительно main)."""
    def run(args: list[str]) -> str:
        try:
            return subprocess.run(
                ["git", "-C", root, "-c", "core.quotepath=false", *args],
                capture_output=True, text=True, timeout=20,
            ).stdout
        except Exception:
            return ""

    base = ""
    for base_ref in ("origin/main", "main"):
        if run(["rev-parse", "--verify", "--quiet", base_ref]).strip():
            base = base_ref
            break
    if not base:
        return set()
    merge_base = run(["merge-base", base, "HEAD"]).strip() or base
    out = run(["diff", "--name-only", f"{merge_base}...HEAD", "--", IDEA_GLOB])
    dirs: set[str] = set()
    for line in out.splitlines():
        line = line.strip().strip('"')
        parts = line.split("/")
        if len(parts) >= 3 and parts[0] == "doc" and parts[1] == "идеи":
            d = "/".join(parts[2:-1])
            dirs.add(d or parts[2])
    return dirs


def resolve(root: str = ".", name: str = "") -> tuple[str | None, str | None]:
    """Возвращает (path, None) либо (None, reason). reason: not_found|ambiguous|..."""
    root = os.path.abspath(root)
    if not name:
        return None, "empty_name"

    base = os.path.realpath(os.path.join(root, "doc", "идеи"))
    def contained(path: str) -> bool:
        real = os.path.realpath(path)
        return real == base or real.startswith(base + os.sep)

    env = os.environ.get("ORC_FEATURE_DIR", "").strip()
    if env:
        p = env if os.path.isabs(env) else os.path.join(root, env)
        if not contained(p):
            return None, "feature_dir_escape"
        cand = os.path.join(p, name)
        if os.path.exists(cand) and contained(cand):
            return cand, None
        return None, "env_feature_dir_missing_artifact"

    fid = (os.environ.get("FEATURE_ID", "") or os.environ.get("ORC_FEATURE_ID", "")).strip()
    if fid:
        if not re.match(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$", fid) or ".." in fid:
            return None, "invalid_feature_id"
        cand = os.path.join(root, "doc", "идеи", fid, name)
        if os.path.exists(cand):
            return cand, None
        return None, "feature_id_missing_artifact"

    cands = _candidates(root, name)
    if not cands:
        return None, "not_found"
    if len(cands) == 1:
        return cands[0], None

    # несколько: сузить по затронутым в ветке каталогам
    changed = _git_changed_dirs(root)
    if changed:
        narrowed = [c for c in cands
                    if any(_related(_idea_dir(root, c), ch) for ch in changed)]
        if len(narrowed) == 1:
            return narrowed[0], None
        if len(narrowed) > 1:
            return None, "ambiguous"
    return None, "ambiguous"


def feature_dir(root: str = ".") -> str | None:
    """Каталог текущей фичи (по scenarios.json → invariants.json → ui-audit.json)."""
    for name in ("scenarios.json", "invariants.json", "ui-audit.json", "feature-brief.md"):
        p, _err = resolve(root, name)
        if p:
            return os.path.dirname(p)
    return None


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=".")
    ap.add_argument("--name", required=True, help="относительный путь внутри doc/идеи/<F>, напр. spec/contract-matrix.md")
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args(argv)
    path, err = resolve(a.root, a.name)
    if a.json:
        import json
        print(json.dumps({"path": path, "error": err}, ensure_ascii=False))
    elif path:
        print(path)  # абсолютный: гейты могут запускаться из другого cwd
    else:
        print(f"feature-dir: {err} ({a.name})", file=sys.stderr)
    return 0 if path else 2


if __name__ == "__main__":
    sys.exit(main())
