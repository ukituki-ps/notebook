#!/usr/bin/env bash
# ADR-KIT-090 (A6 / принцип «реальность») — gate-preview-verified
# Требует доказательства прогона экрана на превью-стенде, если ветка трогает UI.
# Пропускает фичи без UI-изменений. Fail-close при UI-изменении без evidence.
set -uo pipefail
root="${1:-.}"
base="${2:-${PREVIEW_BASE_REF:-main}}"

ui_changed=0
if git -C "$root" rev-parse --git-dir >/dev/null 2>&1; then
  if git -C "$root" -c core.quotepath=false diff --name-only "$base"...HEAD 2>/dev/null | grep -qE '(^|/)nexus-ui/src/pages/|(^|/)frontend/src/'; then
    ui_changed=1
  fi
else
  # вне git — считаем, что UI-маркер задан контекстом
  [ "${UI_CHANGED:-0}" = "1" ] && ui_changed=1
fi

if [ "$ui_changed" -eq 0 ]; then
  echo "gate-preview-verified: SKIP (нет UI-изменений)"
  exit 0
fi

for cand in "$root/preview-verdict.json" "$root/data/audit/preview-verdict.json" "$root/.orc-evidence/preview-verdict.json"; do
  if [ -f "$cand" ]; then
    echo "gate-preview-verified: OK ($cand)"
    exit 0
  fi
done

echo "gate-preview-verified: FAIL — UI-изменение без evidence превью-стенда (preview-verdict.json)." >&2
echo "→ Прогони deploy/test/run-preview-e2e.sh (s20b/s20c) до приёмки (ADR-KIT-090/ADR-KIT-077)." >&2
exit 1
