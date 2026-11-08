#!/usr/bin/env bash
# path1-doctor — проверка готовности проекта к пути 1 (path-1.feature).
# Репо-сторонние проверки; шаги Nexus/MCP выводятся как подсказки.
#   bash tools/path1-doctor.sh
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DIR/.." && pwd)"
ok=0; warn=0; bad=0
G() { printf '  \033[32m✓\033[0m %s\n' "$1"; ok=$((ok+1)); }
W() { printf '  \033[33m!\033[0m %s\n' "$1"; warn=$((warn+1)); }
B() { printf '  \033[31m✗\033[0m %s\n' "$1"; bad=$((bad+1)); }

echo "path1-doctor: $ROOT"

echo "[1] git"
if git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then G "git-репозиторий"; else B "не git-репозиторий"; fi
if [ -n "$(git -C "$ROOT" status --porcelain 2>/dev/null | head -1)" ]; then W "рабочее дерево грязное (будут untracked/modified — учти ADR-KIT-076)"; else G "рабочее дерево чистое"; fi

echo "[2] UI-поверхность (platform)"
if [ -f "$ROOT/path1.ui.json" ]; then
  G "path1.ui.json: $(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("platform","?"))' "$ROOT/path1.ui.json" 2>/dev/null)"
else
  found=""
  for f in frontend/package.json nexus-ui/package.json app/package.json web/package.json; do [ -f "$ROOT/$f" ] && found="$f"; done
  compgen -G "$ROOT/ios/*.xcodeproj" >/dev/null 2>&1 && found="ios"
  [ -f "$ROOT/android/build.gradle" ] && found="android"
  [ -f "$ROOT/mobile/pubspec.yaml" ] && found="flutter"
  if [ -n "$found" ]; then
    B "есть UI ($found), но нет path1.ui.json → gate-ui-audit будет fail-close. Создай {\"platform\":\"web|mobile|both\"}"
  else
    W "UI не обнаружен: если это бэкенд-only — создай path1.ui.json {\"platform\":\"none\"} (иначе gate-ui-audit pass-NA, но лучше объявить явно)"
  fi
fi

echo "[3] kit-скрипты в tools/ (ORC обычно синкает их сам)"
miss=""
for f in path1-gate.sh ui-audit-check.py check-evidence-authentic.sh; do [ -f "$ROOT/tools/$f" ] || miss="$miss $f"; done
if [ -z "$miss" ]; then G "kit-скрипты на месте"; else W "нет:$miss — ORC до-копирует из kit (ORC_KIT_ROOT) при создании worktree"; fi

echo "[4] спека/идеи"
[ -d "$ROOT/doc/идеи" ] && G "doc/идеи присутствует" || W "нет doc/идеи/ — создаётся на шаге s01"

echo "[5] Шаги в Nexus/MCP (сделать один раз на проект)"
cat <<'TXT'
  - stand_register (проект → t1..tN, dsn_ref)                     # стенды
  - binding_put (project_id → path-1.feature)                     # привязка
  - mobile_register/seed (если mobile) — устройства уже в реестре
  - orc_start (process_id=path-1.feature, project_id=…, branch от main)
TXT

echo
echo "Итог: ok=$ok warn=$warn fail=$bad"
[ "$bad" -eq 0 ] || exit 1
