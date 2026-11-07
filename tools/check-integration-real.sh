#!/usr/bin/env bash
# ADR-KIT-090 (принцип «реальность») — реальный gate-l2-integration.
# Заменяет no-op из канона 2.7.0: если интеграционные тесты нельзя выполнить
# (нет docker/команды) — FAIL-CLOSE, а не «silent pass».
#
# ENV: INTEGRATION_CMD — команда интеграции (по умолчанию go test -tags integration ./...)
set -uo pipefail

cmd="${INTEGRATION_CMD:-go test -count=1 -tags integration ./...}"

# Эвристика: реальная интеграция обычно требует контейнеров/БД.
if [ -z "${INTEGRATION_CMD:-}" ]; then
  if ! command -v docker >/dev/null 2>&1; then
    echo "gate-l2-integration: BLOCK — docker недоступен и INTEGRATION_CMD не задан (fail-close, ADR-KIT-090)" >&2
    exit 1
  fi
fi

echo "gate-l2-integration: running: $cmd"
if bash -c "$cmd"; then
  echo "gate-l2-integration: OK"
  exit 0
fi
echo "gate-l2-integration: FAIL — интеграционные тесты не прошли (ADR-KIT-090)" >&2
exit 1
