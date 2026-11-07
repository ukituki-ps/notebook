#!/usr/bin/env python3
"""s20c per-run evidence fallback: execution root → fresh eval worktree.

ORC пересоздаёт eval-worktree перед гейтами (createEvalWorktree), поэтому
untracked `scenario-evidence.json` и `screenshots/*` из каталога фичи исчезают.
Этот helper строго переносит их из ПОСТОЯННОГО execution root в свежий
worktree, не расширяя allowlist приёмки и ничего не коммитя.

Контракт (fail-closed):
  * feature_dir — относительный путь под doc/идеи/, без traversal/symlink;
  * источник: <execution-root>/<feature-dir>/scenario-evidence.json;
  * scenario-evidence.execution == --execution-id (если задан);
  * каждый screenshot — относительный путь внутри feature_dir, regular file,
    не symlink; sha256 (если указан) обязан совпасть;
  * destination не может быть tracked-файлом eval worktree.

Exit: 0 — скопировано; 1 — ошибка/небезопасный вход; 2 — источника нет.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import posixpath
import shutil
import stat
import subprocess
import sys

PREFIX = "preview-evidence-fallback"


def fail(msg: str, code: int = 1) -> int:
    print(f"{PREFIX}: FAIL — {msg}", file=sys.stderr)
    return code


def norm_rel(p: object) -> str | None:
    if not isinstance(p, str):
        return None
    p = p.strip().replace("\\", "/")
    if not p or p.startswith("/"):
        return None
    n = posixpath.normpath(p)
    if n in ("", ".", "..") or n.startswith("../") or "/../" in n:
        return None
    return n


def regular_no_symlink(p: str) -> bool:
    try:
        st = os.lstat(p)
    except OSError:
        return False
    return stat.S_ISREG(st.st_mode)


def file_sha256(p: str) -> str:
    h = hashlib.sha256()
    with open(p, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 16), b""):
            h.update(chunk)
    return h.hexdigest()


def is_tracked(root: str, rel: str) -> bool:
    r = subprocess.run(
        ["git", "-C", root, "ls-files", "--error-unmatch", "--", rel],
        capture_output=True,
        text=True,
    )
    return r.returncode == 0


def under(path: str, parent: str) -> bool:
    return os.path.realpath(path) == os.path.realpath(parent) or os.path.realpath(path).startswith(
        os.path.realpath(parent) + os.sep
    )


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--worktree-root", required=True)
    ap.add_argument("--execution-root", required=True)
    ap.add_argument("--feature-dir", required=True)
    ap.add_argument("--execution-id", default="")
    a = ap.parse_args(argv)

    root = os.path.realpath(a.worktree_root)
    eroot = os.path.realpath(a.execution_root)
    feat = norm_rel(a.feature_dir)
    if not feat or not (feat == "doc/идеи" or feat.startswith("doc/идеи/")):
        return fail(f"feature_dir вне doc/идеи: {a.feature_dir!r}")
    if not under(os.path.join(root, feat), os.path.join(root, "doc", "идеи")):
        return fail("feature_dir escape/symlink в eval worktree")
    if not under(os.path.join(eroot, feat), os.path.join(eroot, "doc", "идеи")):
        return fail("feature_dir escape/symlink в execution root")

    src_ev = os.path.join(eroot, feat, "scenario-evidence.json")
    if not regular_no_symlink(src_ev):
        return fail(f"нет regular scenario-evidence.json: {src_ev}", 2)
    try:
        doc = json.load(open(src_ev, encoding="utf-8"))
    except Exception as e:  # noqa: BLE001
        return fail(f"scenario-evidence.json: {e}")
    if not isinstance(doc, dict):
        return fail("scenario-evidence.json: не JSON-объект")

    exec_id = a.execution_id.strip()
    if exec_id:
        got = str(doc.get("execution") or "").strip()
        if got != exec_id:
            return fail(f"scenario-evidence.execution={got!r} != {exec_id!r}")

    scenarios = doc.get("scenarios")
    if not isinstance(scenarios, list) or not scenarios:
        return fail("scenario-evidence.scenarios пуст/не список")

    dst_ev_rel = posixpath.join(feat, "scenario-evidence.json")
    if is_tracked(root, dst_ev_rel):
        return fail("scenario-evidence.json tracked в eval worktree — отказ перезаписи")

    copies = 0
    for item in scenarios:
        if not isinstance(item, dict):
            return fail("scenario-evidence: элемент scenarios не объект")
        sid = str(item.get("id") or "?").strip()
        raw = item.get("screenshot")
        if raw in (None, ""):
            continue  # oracle=unit: кадр не требуется (проверяет coverage-gate)
        rel = norm_rel(raw)
        if not rel:
            return fail(f"{sid}: небезопасный путь скриншота: {raw!r}")
        if rel != feat and not rel.startswith(feat + "/"):
            if rel.startswith("screenshots/"):
                rel = posixpath.join(feat, rel)
            else:
                return fail(f"{sid}: скриншот вне feature_dir: {raw!r}")
        src = os.path.join(eroot, rel)
        if not regular_no_symlink(src):
            return fail(f"{sid}: скриншот отсутствует/не regular/symlink: {rel}")
        if not under(src, os.path.join(eroot, feat)):
            return fail(f"{sid}: скриншот вне execution feature_dir: {rel}")
        want = str(item.get("sha256") or "").strip().lower()
        if want.startswith("sha256:"):
            want = want[len("sha256:") :]
        if want and file_sha256(src) != want:
            return fail(f"{sid}: sha256 скриншота не совпадает: {rel}")
        if is_tracked(root, rel):
            return fail(f"{sid}: скриншот tracked в eval worktree: {rel}")
        dst = os.path.join(root, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copyfile(src, dst)
        copies += 1

    dst_ev = os.path.join(root, dst_ev_rel)
    os.makedirs(os.path.dirname(dst_ev), exist_ok=True)
    shutil.copyfile(src_ev, dst_ev)
    copies += 1
    print(f"{PREFIX}: copied={copies}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
