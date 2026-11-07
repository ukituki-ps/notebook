#!/usr/bin/env bash
# ADR-KIT-090/091 — gate-no-self-mock (по СМЫСЛУ, не по имени файла).
#
# Запрещает тесты, которые мокают ЮНИТ ПОД ТЕСТОМ (и потому не могут упасть на
# реальном дефекте): мок адаптера/клиента/сервиса фичи в E2E/контрактном тесте,
# sqlmock в Go-тестах. Скан — широкий (любые файлы), чтобы обход переименованием
# не помогал (fix после инцидента F186/F187).
#
# Портируемость (ADR-KIT-090 followup): корни исходников берутся из
# `path1.project.json` (no_self_mock.go_roots / no_self_mock.js_roots), а не
# хардкодятся под archkit-монорепо. Если настроенный корень не существует —
# FAIL (раньше гейт на app-репо проходил ВАКУУМНО, т.е. был ложный зелёный).
set -uo pipefail
root="${1:-.}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cfg() { python3 "$DIR/_path1_project.py" --root "$root" --line "$1" 2>/dev/null; }

go_roots="$(cfg no_self_mock.go_roots)"
js_roots="$(cfg no_self_mock.js_roots)"
fail=0; hits=""

if [ -z "${go_roots// }" ] && [ -z "${js_roots// }" ]; then
  echo "gate-no-self-mock: FAIL — не заданы корни исходников (path1.project.json → no_self_mock.*)" >&2
  exit 1
fi

# 1) JS/TS: мок транспорта/адаптера фичи в тестах.
for d in $js_roots; do
  if [ ! -d "$root/$d" ]; then
    echo "gate-no-self-mock: FAIL — настроенный js-root '$d' не найден (ложный PASS-NA запрещён)" >&2
    exit 1
  fi
  h1="$(grep -rnE "vi\.mock\((['\"])[^'\"]*(/(api|client|adapter|service|hooks)/|client|adapter)[^'\"]*\1\)" \
        "$root/$d" 2>/dev/null || true)"
  [ -n "$h1" ] && { hits="${hits}${h1}\n"; fail=1; }
done

# 2) Go: sqlmock в ЛЮБОМ _test.go (в т.ч. переименованных) — маскирует SQL/RLS.
# 3) Go: мок store/repo/db в тестах (эвристика по имени).
for d in $go_roots; do
  if [ ! -d "$root/$d" ]; then
    echo "gate-no-self-mock: FAIL — настроенный go-root '$d' не найден (ложный PASS-NA запрещён)" >&2
    exit 1
  fi
  h2="$(grep -rn "sqlmock" "$root/$d" --include='*_test.go' 2>/dev/null || true)"
  [ -n "$h2" ] && { hits="${hits}${h2}\n"; fail=1; }
  h3="$(grep -rnE "mock[A-Za-z]*Store|mockRepo|fakeDB|MockDatabase" "$root/$d" --include='*_test.go' 2>/dev/null || true)"
  [ -n "$h3" ] && { hits="${hits}${h3}\n"; fail=1; }
done

if [ "$fail" -ne 0 ]; then
  echo "gate-no-self-mock: FAIL — тест мокает юнит под тестом (не может упасть на реальном дефекте):" >&2
  printf '%b' "$hits" >&2
  echo "→ Стабь ТРАНСПОРТ (fetch/MSW) или поднимай реальную БД (testcontainers/стенд)." >&2
  exit 1
fi
echo "gate-no-self-mock: OK"
exit 0
