#!/usr/bin/env bash
# seed-stand-fixtures <execution_id> <sql-file> — сеет фикстуры в БД АРЕНДОВАННОГО
# стенда. DSN резолвится из аренды (stand_dsn_ref → env:VAR). Нужен для сценариев,
# требующих объёма данных (пагинация: ≥ page_size+1 строк).
# Запускать АГЕНТОМ на docker-хосте. Стенд должен быть арендован под execution_id.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec_id="${1:?usage: seed-stand-fixtures <execution_id> <sql-file>}"
sqlf="${2:?usage: seed-stand-fixtures <execution_id> <sql-file>}"
[ -f "$sqlf" ] || { echo "seed-stand-fixtures: нет SQL-файла $sqlf" >&2; exit 1; }
base="${NEXUS_BASE_URL:-http://nexus:9182}"
tok="${NEXUS_TOKEN:-${ORC_NEXUS_TOKEN:-}}"

ref="$(curl -fsS -m 12 -H "Authorization: Bearer $tok" \
    "${base}/api/v1/stands/leases?execution_id=${exec_id}" 2>/dev/null \
  | python3 -c 'import sys,json;print((json.load(sys.stdin).get("lease") or {}).get("stand_dsn_ref",""))' 2>/dev/null || true)"
case "$ref" in
  env:*) v="${ref#env:}"; dsn="${!v:-}";;
  "")    dsn="";;
  *)     dsn="$ref";;
esac
[ -n "$dsn" ] || { echo "seed-stand-fixtures: DSN не разрешён (execution=${exec_id})" >&2; exit 1; }
command -v psql >/dev/null 2>&1 || { echo "seed-stand-fixtures: psql не найден на хосте" >&2; exit 1; }

echo "seed-stand-fixtures: apply $sqlf → стенд (execution=${exec_id})"
PGSSLMODE="${PGSSLMODE:-disable}" psql "$dsn" -v ON_ERROR_STOP=1 -q -f "$sqlf"
echo "seed-stand-fixtures: OK"
