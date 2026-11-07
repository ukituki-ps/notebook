#!/usr/bin/env bash
# orc-cli.sh — актуальный ORC CLI.
# Порядок выбора бинаря (инцидент E8141: в контейнере ORC нет Go → сборка падала,
# агенты внутри ORC не могли пользоваться CLI и собирали result руками → schema-violations):
#   1) $ORC_CLI_BIN (явно заданный);
#   2) собранный из репо .orc-cli/bin/orc, если он свежее исходников;
#   3) сборка из исходников репо (если есть Go);
#   4) установленный бинарь `orc` из образа (в контейнере ORC это /usr/local/bin/orc,
#      собран из того же коммита, что и деплой).
# Конфиг: ~/.config/orc/config.toml (T178), env ORC_MCP_URL / ORC_MCP_TOKEN.
#   bash tools/orc-cli.sh step-done -execution E8141 -step s01.product_discuss -schema
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DIR/.." && pwd)"

if [ -n "${ORC_CLI_BIN:-}" ] && [ -x "${ORC_CLI_BIN}" ]; then exec "${ORC_CLI_BIN}" "$@"; fi

BIN="$ROOT/.orc-cli/bin/orc"
stale_cache=0
if [ -x "$BIN" ] && [ -n "$(find "$ROOT/orc" -name '*.go' -newer "$BIN" 2>/dev/null | head -1)" ]; then
  stale_cache=1   # кэш старше исходников → он НЕ актуален (используем бинарь образа)
fi
if [ -x "$BIN" ] && [ "$stale_cache" = 0 ]; then
  exec "$BIN" "$@"
fi

if command -v go >/dev/null 2>&1; then
  mkdir -p "$(dirname "$BIN")"
  ( cd "$ROOT" && go build -o "$BIN" ./orc ) || { echo "orc-cli: сборка ./orc не удалась" >&2; exit 3; }
  exec "$BIN" "$@"
fi

if command -v orc >/dev/null 2>&1; then
  [ "$stale_cache" = 1 ] && echo "orc-cli: кэш .orc-cli/bin/orc устарел (старше исходников) → беру бинарь образа" >&2
  echo "orc-cli: Go нет — использую установленный бинарь $(command -v orc) ($(orc version 2>/dev/null | head -1))" >&2
  rm -f "$BIN" 2>/dev/null || true
  exec orc "$@"
fi

[ -x "$BIN" ] && exec "$BIN" "$@"

echo "orc-cli: не найден ни Go для сборки, ни бинарь orc в PATH (задай ORC_CLI_BIN)" >&2
exit 3
