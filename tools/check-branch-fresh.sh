#!/usr/bin/env bash
# gate-branch-fresh — preflight перед push в primary (audit F003/E5438, p.7).
#
# В базовом каноне s24a.branch_fresh скипается в default-точке входа, поэтому «ветка отстала
# от main / конфликтует» выясняется уже после приёмки. В пилоте F003 ветка отставала на 4
# коммита и конфликтовала в frontend/vite.config.ts — обнаружилось только при влитии PR.
# Этот гейт ставится (оверлеем) на s45.push_primary и на s24: дешёвый fetch + dry-run merge.
#
# Проверки (fail-close):
#   1) head ветки на origin РАВЕН ожидаемому (--expect / context.target_repo_head / локальный HEAD);
#   2) ветка не отстаёт от базы (по умолчанию origin/main): behind==0;
#   3) dry-run merge базы в ветку не даёт конфликтов (git merge-tree, дерево не меняется).
#
# Использование: bash tools/check-branch-fresh.sh --branch B [--expect SHA] [--base origin/main]
#                bash tools/check-branch-fresh.sh <execution_id>     # branch/base из env/context
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DIR/.." && pwd)"
BRANCH=""; EXPECT=""; BASE=""; exec_id=""; ROOT_OVERRIDE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT_OVERRIDE="$2"; shift 2 ;;
    --branch) BRANCH="$2"; shift 2 ;;
    --expect) EXPECT="$2"; shift 2 ;;
    --base) BASE="$2"; shift 2 ;;
    *) exec_id="${1:-}"; shift ;;
  esac
done
[ -n "$ROOT_OVERRIDE" ] && ROOT="$ROOT_OVERRIDE"
BRANCH="${BRANCH:-${WORK_BRANCH:-${1:-}}}"
EXPECT="${EXPECT:-${TARGET_REPO_HEAD:-}}"
BASE="${BASE:-${BRANCH_BASE:-origin/main}}"
fail() { echo "gate-branch-fresh: FAIL — $1" >&2; exit 1; }
warn() { echo "gate-branch-fresh: warn — $1" >&2; }

git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1 || fail "$ROOT не git-репозиторий"
[ -n "$BRANCH" ] || fail "не задана ветка (--branch / WORK_BRANCH)"
git -C "$ROOT" fetch -q origin 2>/dev/null || warn "git fetch не удался (работаю по локальным refs)"

remote_head="$(git -C "$ROOT" ls-remote origin "refs/heads/$BRANCH" 2>/dev/null | cut -f1 || true)"
[ -n "$remote_head" ] || fail "ветка '$BRANCH' не найдена на origin (не запушена?)"
[ -n "$EXPECT" ] || EXPECT="$(git -C "$ROOT" rev-parse "$BRANCH" 2>/dev/null || true)"
if [ -n "$EXPECT" ] && [ "$remote_head" != "$EXPECT" ]; then
  fail "origin/$BRANCH=$remote_head != ожидаемого $EXPECT (push не дошёл или ветка изменилась)"
fi

base_sha="$(git -C "$ROOT" rev-parse "$BASE" 2>/dev/null || true)"
[ -n "$base_sha" ] || fail "не разрешается база '$BASE' (нужен fetch: git fetch origin)"
if git -C "$ROOT" merge-base --is-ancestor "$base_sha" "$remote_head" 2>/dev/null; then
  behind=0
else
  behind="$(git -C "$ROOT" rev-list --count "$remote_head..$base_sha" 2>/dev/null || echo 0)"
fi
if [ "${behind:-0}" != "0" ]; then
  fail "ветка отстаёт от $BASE на ${behind} коммит(ов) — влей базу ДО push:
  git -C <ворктри> fetch origin && git merge origin/${BASE#origin/}
  (иначе конфликты всплывут на CI/PR)"
fi

# dry-run merge: git merge-tree --write-tree (git ≥ 2.38) либо классический merge-tree
conflicts=""
if git -C "$ROOT" merge-tree --write-tree "$remote_head" "$base_sha" >/dev/null 2>&1; then
  conflicts=""
else
  mt="$(git -C "$ROOT" merge-tree --write-tree "$remote_head" "$base_sha" 2>&1 || true)"
  if printf '%s' "$mt" | grep -qiE 'CONFLICT|conflict'; then
    conflicts="$(printf '%s' "$mt" | grep -oiE "[A-Za-z0-9_./\u0400-\u04FF-]+\.(ts|tsx|js|jsx|go|py|sh|json|yaml|yml|md)" | sort -u | head -10 | tr '\n' ' ')"
  fi
fi
if [ -n "${conflicts:-}" ]; then
  fail "dry-run merge $BASE → $BRANCH даёт конфликты: ${conflicts}
  Разреши в ветке (git merge origin/${BASE#origin/}) и запушь до push в primary."
fi

echo "gate-branch-fresh: OK — $BRANCH=$remote_head, база $BASE свежая (behind=0), конфликтов нет"
