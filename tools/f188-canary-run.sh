#!/usr/bin/env bash
# DEPRECATED: переименован в tools/canary-run.sh (generic, run-scoped).
# Оставлен тонким шимом, чтобы не ломать идущие прогоны.
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/canary-run.sh" "$@"
