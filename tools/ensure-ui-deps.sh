#!/usr/bin/env bash
# ensure-ui-deps [ui-dir] — идемпотентно ставит зависимости nexus-ui (npm ci),
# если node_modules отсутствуют. Убирает ручной `npm ci` (инцидент E8837).
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DIR/.." && pwd)"
ui="${1:-$ROOT/nexus-ui}"
[ -f "$ui/package.json" ] || { echo "ensure-ui-deps: нет $ui/package.json — пропуск"; exit 0; }
if [ -x "$ui/node_modules/.bin/vitest" ]; then echo "ensure-ui-deps: deps уже на месте"; exit 0; fi
echo "ensure-ui-deps: npm ci в $ui"
( cd "$ui" && npm ci --no-audit --no-fund )
echo "ensure-ui-deps: OK"
