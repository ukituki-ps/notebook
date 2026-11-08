#!/usr/bin/env bash
# check-run-artifacts — F-RUN-02 (E7141): per-run артефакты не должны быть в git.
#
# Симптом E7141: агент коммитил preview-deploy.json в ветку прогона → выкат записал ref,
# коммит артефакта сдвинул HEAD, и gate-preview-deploy дважды падал на «ref ≠ HEAD».
# Артефакты прогона живут в рабочем дереве/рантайме, но не в истории: их коммит ломает
# идентичность выката и засоряет ветку.
#
# Проверяем ТРЕКИНГ (git ls-files), а не наличие файла: файл в дереве — норма.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${1:-$(cd "$DIR/.." && pwd)}"
# .git у worktree — ФАЙЛ (gitdir: …), а не каталог: проверяем через git, не по типу пути.
git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1 || { echo "check-run-artifacts: FAIL — $ROOT не git-репозиторий" >&2; exit 1; }

tracked="$(git -C "$ROOT" ls-files \
  'preview-deploy.json' 'preview-verdict.json' 'review-verdict.json' \
  'deploy/stands/.runtime' 'deploy/stands/.runtime/**' \
  'data/audit/runs' 'data/audit/runs/**' \
  '*.tsbuildinfo' 2>/dev/null || true)"

# фильтруем пустые строки
tracked="$(printf '%s\n' "$tracked" | sed '/^$/d')"

if [ -n "$tracked" ]; then
  echo "check-run-artifacts: FAIL — per-run артефакты в git (их не должно быть в истории):" >&2
  printf '  %s\n' $tracked >&2
  echo "  Исправление: git rm --cached <путь> и убедиться, что путь в .gitignore." >&2
  echo "  (F-RUN-02/E7141: коммит preview-deploy.json после выката сдвигает HEAD и ломает gate-preview-deploy.)" >&2
  exit 1
fi

echo "check-run-artifacts: OK — per-run артефакты не трекаются"
