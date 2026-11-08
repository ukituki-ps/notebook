#!/usr/bin/env bash
# orc-worktree-sync <worktree> [branch] — детерминированно подтянуть execution-worktree
# к origin (git fetch + reset --hard). Заменяет ad-hoc ручные команды TL (инцидент E8837).
set -euo pipefail
wt="${1:?usage: orc-worktree-sync <worktree> [branch]}"
[ -d "$wt/.git" ] || [ -f "$wt/.git" ] || { echo "orc-worktree-sync: $wt не worktree" >&2; exit 1; }
br="${2:-$(git -C "$wt" rev-parse --abbrev-ref HEAD)}"
git -C "$wt" fetch origin "+refs/heads/${br}:refs/remotes/origin/${br}"
git -C "$wt" reset --hard "origin/${br}"
echo "orc-worktree-sync: $wt → origin/$br ($(git -C "$wt" rev-parse --short HEAD))"
