#!/usr/bin/env bash
# gate-l2-integration (ADR-KIT-090/091) — интеграция ПРОТИВ БД АРЕНДОВАННОГО стенда.
# Один REST-вызов: GET /api/v1/stands/leases?execution_id= → аренда СО СТЕНДОМ
# (stand_url, stand_dsn_ref). Дальше dsn_ref (env:VAR) → значение из env → TEST_DATABASE_URL.
#   - аренда есть, но DSN не разрешён → FAIL (docker-fallback запрещён);
#   - аренды нет → INTEGRATION_CMD → docker; ничего → FAIL.
# $1: execution_id (или EXECUTION_ID). ENV: NEXUS_BASE_URL, NEXUS_TOKEN|ORC_NEXUS_TOKEN.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# В pinned gate-bundle скрипт живёт в /opt/gate-tools/tools, а оцениваемое
# дерево — eval-root ORC. Без ORC_GATE_ROOT l2 делал git diff/go test в самом
# bundle (не git-репозиторий) → `./...` по всему платформенному репо
# (F199-CANARY-3/5). Kit-скрипты обязаны брать eval-root из ORC_GATE_ROOT.
ROOT="${ORC_GATE_ROOT:-$(cd "$DIR/.." && pwd)}"

# Runtime DSN/preview-артефакты не версионируются и потому существуют только в
# основном клоне, а не в свежем eval-worktree. Для runtime_dir нужен корень
# проекта (клон), а не корень worktree. git-common-dir в linked worktree
# указывает на <clone>/.git, поэтому поднимаемся на уровень выше.
PROJECT_ROOT="${ORC_PROJECT_ROOT:-}"
if [ -z "$PROJECT_ROOT" ]; then
  common="$(git rev-parse --git-common-dir 2>/dev/null || true)"
  if [ -n "$common" ]; then
    case "$common" in
      /*) ;;
      *) common="$ROOT/$common" ;;
    esac
    PROJECT_ROOT="$(cd "$common/.." 2>/dev/null && pwd || true)"
  fi
fi
[ -n "$PROJECT_ROOT" ] || PROJECT_ROOT="$ROOT"
exec_id="${1:-${EXECUTION_ID:-}}"
base_url="${NEXUS_BASE_URL:-http://nexus:9182}"
tok="${NEXUS_TOKEN:-${ORC_NEXUS_TOKEN:-}}"

# F189/E2389: если Go-файлы не менялись (frontend/docs-only фича) — интегрировать нечего.
# Раньше pick_cmd возвращал `go test -tags integration ./...` → падал не-герметичный
# test/integration (TestBackupRestore_RoundTrip) и блокировал фронт-фичи. PASS-NA.
if [ -z "${INTEGRATION_CMD:-}" ]; then
  _mb=""
  # F199-CANARY-3/5: в eval-worktree origin/main может быть СТАРЕЕ base_sha,
  # из-за чего diff тянет чужие Go-пакеты. База исполнения (ORC_BASE_SHA)
  # авторитетнее локального main-ref; иначе — прежний fallback.
  for _base in "${ORC_BASE_SHA:-}" origin/main main; do
    [ -n "$_base" ] || continue
    _mb="$(git -C "$ROOT" merge-base "$_base" HEAD 2>/dev/null || true)"
    [ -n "$_mb" ] && break
  done
  # Базу определить не удалось → НЕ объявляем NA (fail-open запрещён): идём обычной веткой.
  if [ -n "$_mb" ] && _diff="$(git -C "$ROOT" diff --name-only "${_mb}...HEAD" 2>/dev/null)"; then
    # diff УСПЕШЕН (иначе fail-open запрещён → идём обычной веткой). «Нет совпадений»
    # grep'а — это exit 1, а не ошибка diff: отличаем явно.
    _changed_go="$(printf '%s\n' "$_diff" | grep '\.go$' || true)"
    if [ -z "$_changed_go" ]; then
      echo "gate-l2-integration: PASS-NA — нет изменённых Go-файлов (frontend/docs-only; интегрировать нечего)"
      exit 0
    fi
  fi
fi

# pick_cmd: INTEGRATION_CMD, иначе integration-тесты ТОЛЬКО по изменённым Go-пакетам
# (иначе `./...` тянет чужие пакеты и падает на не-герметичных тестах — инцидент E4192).
pick_cmd() {
  if [ -n "${INTEGRATION_CMD:-}" ]; then printf '%s' "$INTEGRATION_CMD"; return; fi
  local mb dirs d e cur mr rel pkgs nested pre
  mb=""
  for _b in "${ORC_BASE_SHA:-}" origin/main main; do
    [ -n "$_b" ] || continue
    mb="$(git -C "$ROOT" merge-base "$_b" HEAD 2>/dev/null || true)"
    [ -n "$mb" ] && break
  done
  [ -n "$mb" ] || mb="origin/main"
  dirs="$(git -C "$ROOT" diff --name-only "${mb}...HEAD" 2>/dev/null | grep '\.go$' | xargs -r -n1 dirname | sort -u)"

  # Модульная граница: go test запускается из каталога с go.mod (app-репо:
  # backend/). Иначе `./backend/internal/...` из корня → "does not contain main
  # module" (E5722). Определяем общий модуль изменённых файлов.
  local common_mr="" first=1
  for d in $dirs; do
    cur="$d"; mr=""
    while [ -n "$cur" ] && [ "$cur" != "." ]; do
      if [ -f "$ROOT/$cur/go.mod" ]; then mr="$cur"; break; fi
      cur="$(dirname "$cur")"
    done
    if [ "$first" = 1 ]; then common_mr="$mr"; first=0
    elif [ "$mr" != "$common_mr" ]; then common_mr="__multi__"; fi
  done
  if [ "$common_mr" = "__multi__" ]; then
    if [ -f "$ROOT/backend/go.mod" ]; then
      printf 'cd backend && GOWORK=off go test -count=1 -tags integration -p 1 ./...'
    else
      printf 'go test -count=1 -tags integration -p 1 ./...'
    fi
    return
  fi

  # Скоуп — РОВНО изменённые Go-пакеты; родительский глоб не добавляем, если
  # изменён вложенный подпакет (инцидент E4192).
  pkgs=""
  for d in $dirs; do
    nested=0
    for e in $dirs; do
      case "$e" in "$d"/*) nested=1;; esac
    done
    [ "$nested" = 1 ] && continue
    rel="$d"
    if [ -n "$common_mr" ]; then
      if [ "$d" = "$common_mr" ]; then rel="."; else rel="${d#"$common_mr"/}"; fi
    fi
    if [ "$rel" = "." ]; then pkgs="$pkgs ./..."; else pkgs="$pkgs ./$rel/..."; fi
  done
  pkgs="$(printf '%s' "$pkgs" | xargs)"
  [ -z "$pkgs" ] && pkgs="./..."
  pre=""
  [ -n "$common_mr" ] && pre="cd $common_mr && "
  printf '%sgo test -count=1 -tags integration -p 1 %s' "$pre" "$pkgs"
}

# pick_pkgs — модульная граница + РОВНО изменённые пакеты для isolation-пути.
# Возвращает "modroot|pkgs" (modroot "." — корень). Пустой pkgs → return 2.
pick_pkgs() {
  local mb dirs d e cur modroot rel pkgs nested
  mb=""
  for _b in "${ORC_BASE_SHA:-}" origin/main main; do
    [ -n "$_b" ] || continue
    mb="$(git -C "$ROOT" merge-base "$_b" HEAD 2>/dev/null || true)"
    [ -n "$mb" ] && break
  done
  [ -n "$mb" ] || mb="origin/main"
  dirs="$(git -C "$ROOT" diff --name-only "${mb}...HEAD" 2>/dev/null | grep '\.go$' | xargs -r -n1 dirname | sort -u)"
  modroot=""
  d="$(printf '%s\n' $dirs | head -n1)"
  while [ -n "$d" ] && [ "$d" != "." ] && [ "$d" != "/" ] && [ ! -f "$ROOT/$d/go.mod" ]; do
    d="$(dirname "$d")"
  done
  if [ -n "$d" ] && [ "$d" != "." ] && [ -f "$ROOT/$d/go.mod" ]; then modroot="$d"; fi
  pkgs=""
  for d in $dirs; do
    nested=0
    for e in $dirs; do case "$e" in "$d"/*) nested=1;; esac; done
    [ "$nested" -eq 1 ] && continue
    rel="$d"
    [ -n "$modroot" ] && rel="${d#"$modroot"/}"
    if [ "$rel" = "." ]; then pkgs="$pkgs ./..."; else pkgs="$pkgs ./$rel/..."; fi
  done
  printf '%s|%s' "${modroot:-.}" "$(printf '%s' "$pkgs" | xargs)"
}

# run_isolated — F002.4/E8267: один общий DSN стенда на все пакеты даёт
# взаимный дрейф фикстур (migrations/seed падают от порядка пакетов). Если
# оцениваемый репозиторий предоставляет backend/cmd/l2db, клонируем БД стенда
# в template и даём КАЖДОМУ пакету свою БД. Ошибка клона/создания — fail-close.
run_isolated() {
  local spec modroot pkgs tpl pkg db pdsn pddsn rel pkg_count
  spec="${1:-$(pick_pkgs)}"
  modroot="${spec%%|*}"; pkgs="${spec#*|}"
  [ -n "$pkgs" ] || return 2
  tpl="l2tpl_$(date +%s)_$$"; tpl="$(printf '%s' "$tpl" | tr -cd 'a-z0-9_')"
  echo "gate-l2-integration: isolation — template ${tpl} из ${stand_name:-stand DSN}"
  ( cd "$ROOT/$modroot" && GOWORK=off go run ./cmd/l2db -dsn "$dsn" -mode template -template "$tpl" ) \
    || { echo "gate-l2-integration: FAIL — clone template ${tpl}" >&2; return 1; }
  for pkg in $pkgs; do
    rel="$(printf '%s' "$pkg" | tr 'A-Z' 'a-z' | sed 's#^\./##; s#/\.\.\.$##; s#[^a-z0-9_]#_#g')"
    db="$(printf 'l2_%s_%s' "$$" "$rel" | cut -c1-60)"
    ( cd "$ROOT/$modroot" && GOWORK=off go run ./cmd/l2db -dsn "$dsn" -mode create -template "$tpl" -db "$db" ) \
      || { echo "gate-l2-integration: FAIL — create ${db} из ${tpl}" >&2; return 1; }
    pdsn="$( cd "$ROOT/$modroot" && GOWORK=off go run ./cmd/l2db -dsn "$dsn" -mode dsn -db "$db" )" \
      || { echo "gate-l2-integration: FAIL — dsn для ${db}" >&2; return 1; }
    pddsn=""
    if [ -n "$deleter_dsn" ]; then
      pddsn="$( cd "$ROOT/$modroot" && GOWORK=off go run ./cmd/l2db -dsn "$deleter_dsn" -mode dsn -db "$db" )" \
        || { echo "gate-l2-integration: FAIL — deleter dsn для ${db}" >&2; return 1; }
    fi
    echo "gate-l2-integration: pkg ${pkg} → ${db}"
    if ! ( cd "$ROOT/$modroot" && env TEST_DATABASE_URL="$pdsn" HP_TEST_DATABASE_URL="$pdsn" ${pddsn:+TEST_DELETER_DATABASE_URL="$pddsn"} GOWORK=off go test -count=1 -tags integration "$pkg" ); then
      echo "gate-l2-integration: FAIL — ${pkg}" >&2
      ( cd "$ROOT/$modroot" && GOWORK=off go run ./cmd/l2db -dsn "$dsn" -mode drop -db "$db" >/dev/null 2>&1 ) || true
      return 1
    fi
    ( cd "$ROOT/$modroot" && GOWORK=off go run ./cmd/l2db -dsn "$dsn" -mode drop -db "$db" >/dev/null 2>&1 ) || true
  done
  ( cd "$ROOT/$modroot" && GOWORK=off go run ./cmd/l2db -dsn "$dsn" -mode drop -db "$tpl" >/dev/null 2>&1 ) || true
  pkg_count=0
  for pkg in $pkgs; do pkg_count=$((pkg_count + 1)); done
  echo "gate-l2-integration: OK (isolation, ${pkg_count} пакетов)"
  return 0
}

# Host-run deviation (GATE-L2-HOST-RUN): в eval-контейнере аренда/DSN не
# разрешаются; для s20a принимается host-run evidence с тем же стендом,
# ровно 5 baseline red и без новых red.
if [ -d /app/orc-repos ]; then
  ev=doc/идеи/orc32-contract-release/units/s20a-l2-host-run.json
  if [ -f "$ev" ] && python3 tools/verify-host-evidence.py "$ev" tools/conformance-baseline.txt; then
    echo "gate-l2-integration: PASS (signed host-run evidence)"
    exit 0
  fi
fi

# F199-CANARY-3/5: base_sha из execution env; fallback — маркер, который
# ORC кладёт в eval-root перед гейтами (auto-гейт может не получить GateEnv).
if [ -z "${ORC_BASE_SHA:-}" ] && [ -s "$ROOT/.orc-eval-base-sha" ]; then
  ORC_BASE_SHA="$(tr -d '\r\n' < "$ROOT/.orc-eval-base-sha")"
  export ORC_BASE_SHA
fi
if [ -z "${ORC_BASE_SHA:-}" ] && [ -s "$(dirname "$ROOT")/base-sha" ]; then
  ORC_BASE_SHA="$(tr -d '\r\n' < "$(dirname "$ROOT")/base-sha")"
  export ORC_BASE_SHA
fi
if [ -z "${ORC_BASE_SHA:-}" ] && [ -n "${PROJECT_ROOT:-}" ] && [ -s "$PROJECT_ROOT/.orc-base-sha" ]; then
  ORC_BASE_SHA="$(tr -d '\r\n' < "$PROJECT_ROOT/.orc-base-sha")"
  export ORC_BASE_SHA
fi
if [ -z "${ORC_BASE_SHA:-}" ]; then
  _d="$ROOT"
  while [ "$_d" != "/" ] && [ -n "$_d" ]; do
    if [ -s "$_d/.orc-base-sha" ]; then
      ORC_BASE_SHA="$(tr -d '\r\n' < "$_d/.orc-base-sha")"
      export ORC_BASE_SHA
      break
    fi
    _d="$(dirname "$_d")"
  done
fi
dsn="${TEST_DATABASE_URL:-}"
# Unresolved context template / невалидный DSN не должен попасть в тесты
# (F199-CANARY-5): принимаем только postgres(-ql):// или пусто.
case "$dsn" in
  postgres://*|postgresql://*) ;;
  *) dsn="";;
esac
lease_found=0; stand_name=""; stand_url=""
# F002.3/T0406: positive-delete тесты используют отдельный deleter-пул.
deleter_dsn="${TEST_DELETER_DATABASE_URL:-${HP_TEST_DELETER_DATABASE_URL:-}}"
case "$deleter_dsn" in
  postgres://*|postgresql://*) ;;
  *) deleter_dsn="";;
esac
# Preferred: ORC-signed lease proof. ORC issues it for gate-l2-integration
# (leaseProofGateTools) when a lease is active; the raw Nexus token never
# enters the gate env (ADR-KIT-091). The proof is verified by the same
# fail-closed checker as gate-stand-leased.
proof="${ORC_STAND_LEASE_PROOF:-}"
if [ -n "$proof" ]; then
  bash "$DIR/check-stand-leased.sh" "$exec_id" "${PROJECT_ID:-}" >/dev/null 2>&1 \
    || { echo "gate-l2-integration: FAIL — lease proof не прошёл проверку (fail-close)" >&2; exit 1; }
  stand_name="$(printf '%s' "$proof" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("stand",""))' 2>/dev/null)"
  stand_url="$(printf '%s' "$proof" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("stand_url",""))' 2>/dev/null)"
  case "$stand_name" in
    test1|test2) ;;
    *) echo "gate-l2-integration: FAIL — стенд '$stand_name' не из dev-allowlist (test1|test2)" >&2; exit 1 ;;
  esac
  case "$stand_url" in
    *prod*) echo "gate-l2-integration: FAIL — prod-стенд запрещён ($stand_url)" >&2; exit 1 ;;
  esac
  lease_found=1
  echo "gate-l2-integration: lease proof OK (stand=$stand_name url=$stand_url)" >&2
fi
if [ "$lease_found" -eq 0 ] && [ -n "$exec_id" ] && [ -n "$tok" ]; then
  j="$(curl -fsS -m 10 -H "Authorization: Bearer $tok" \
       "${base_url}/api/v1/stands/leases?execution_id=${exec_id}" 2>/dev/null)"
  if [ "$(printf '%s' "$j" | python3 -c 'import sys,json;print(1 if json.load(sys.stdin).get("active") else 0)' 2>/dev/null)" = "1" ]; then
    lease_found=1
    stand_name="$(printf '%s' "$j" | python3 -c 'import sys,json;print((json.load(sys.stdin).get("lease") or {}).get("stand_name",""))' 2>/dev/null)"
    stand_url="$(printf '%s' "$j" | python3 -c 'import sys,json;print((json.load(sys.stdin).get("lease") or {}).get("stand_url",""))' 2>/dev/null)"
    ref="$(printf '%s' "$j" | python3 -c 'import sys,json;print((json.load(sys.stdin).get("lease") or {}).get("stand_dsn_ref",""))' 2>/dev/null)"
    case "$ref" in
      env:*) var="${ref#env:}"; dsn="${!var:-}";;
      "")    : ;;
      *)     echo "gate-l2-integration: FAIL — stand_dsn_ref не является env:VAR; raw DSN запрещён (F199-CANARY-5). Перерегистрируйте стенд с dsn_ref=env:VAR + secret_ref." >&2
             exit 1;;
    esac
    dref="$(printf '%s' "$j" | python3 -c 'import sys,json;print((json.load(sys.stdin).get("lease") or {}).get("stand_deleter_dsn_ref",""))' 2>/dev/null)"
    case "$dref" in
      env:*) var="${dref#env:}"; deleter_dsn="${!var:-}";;
      "")    : ;;
      *)     echo "gate-l2-integration: FAIL — stand_deleter_dsn_ref не является env:VAR; raw DSN запрещён (F199-CANARY-5)." >&2
             exit 1;;
    esac
  fi
fi
case "$deleter_dsn" in
  postgres://*|postgresql://*) ;;
  *) deleter_dsn="";;
esac

# App-declared integration.command: API smoke against the leased stand.
# This is NOT a blanket PASS-NA: if the project declares nothing, the gate
# falls through to the DSN / INTEGRATION_CMD / docker paths below.
integ_cmd="$(python3 "$DIR/_path1_project.py" --root "$ROOT" --line integration.command 2>/dev/null || true)"
if [ -n "$integ_cmd" ]; then
  if [ "$lease_found" -ne 1 ] || [ -z "$stand_url" ]; then
    echo "gate-l2-integration: FAIL — integration.command требует арендованный стенд (execution=${exec_id:-?})" >&2
    exit 1
  fi
  export E2E_BASE_URL="$stand_url" PREVIEW_BASE_URL="$stand_url"
  echo "gate-l2-integration: integration.command на стенде '$stand_name' ($stand_url)"
  if ( cd "$ROOT" && bash -c "$integ_cmd" ); then
    echo "gate-l2-integration: OK — integration.command (stand $stand_name)"
    exit 0
  fi
  echo "gate-l2-integration: FAIL — integration.command (stand $stand_name)" >&2
  exit 1
fi

# Fallback: DSN, записанный выкатом стенда в РАНТАЙМ рабочего дерева
# (tools/deploy-preview-stand.sh → deploy.runtime_dir/<stand>/dsn). Так контур
# «саморезолвится» на стенде и НЕ требует секрета в реестре стендов или env ORC
# (инцидент E8141; F188). Путь — из path1.project.json.
if [ "$lease_found" -eq 1 ] && [ -z "$dsn" ] && [ -n "$stand_name" ]; then
  rt_dir="$(python3 "$DIR/_path1_project.py" --root "$ROOT" --line deploy.runtime_dir 2>/dev/null || true)"
  [ -n "$rt_dir" ] || rt_dir="deploy/stands/.runtime"
  dsn_file="$PROJECT_ROOT/$rt_dir/${stand_name}/dsn"
  if [ -s "$dsn_file" ]; then
    dsn="$(cat "$dsn_file")"
    echo "gate-l2-integration: DSN стенда '${stand_name}' из рантайма выката" >&2
  fi
fi

if [ "$lease_found" -eq 1 ] && [ -z "$dsn" ]; then
  echo "gate-l2-integration: FAIL — стенд арендован (execution=${exec_id}), но DSN не разрешён." >&2
  echo "→ Выкати стенд (tools/deploy-preview-stand.sh → deploy.runtime_dir/<stand>/dsn) или задай env:VAR в stand_dsn_ref." >&2
  exit 1
fi

run() { echo "gate-l2-integration: $1"; bash -c "$2" && { echo "gate-l2-integration: OK"; exit 0; } || { echo "gate-l2-integration: FAIL — $1" >&2; exit 1; }; }
if [ -n "$dsn" ]; then
  export TEST_DATABASE_URL="$dsn"
  [ -n "$deleter_dsn" ] && export TEST_DELETER_DATABASE_URL="$deleter_dsn"

  # 1) Per-package isolation — если оцениваемый репозиторий её предоставляет.
  #    Приоритетнее baseline: 4 «new red» в kh_pg были артефактом общей БД,
  #    а не дефектом тестов (E2495 s20a).
  if [ "${L2_ISOLATION:-1}" != "0" ] && [ -f "$ROOT/backend/cmd/l2db/main.go" ]; then
    run_isolated; rc=$?
    if [ "$rc" -eq 0 ]; then exit 0; fi
    if [ "$rc" -eq 1 ]; then
      echo "gate-l2-integration: FAIL — stand DSN isolation (execution=${exec_id:-env})" >&2
      exit 1
    fi
    echo "gate-l2-integration: WARN — нет изменённых Go-пакетов, обычный путь" >&2
  fi

  # 2) Baseline — только если его несёт САМ оцениваемый коммит (eval-root).
  #    Fallback на PROJECT_ROOT опасен: в клоне приложения может лежать чужой
  #    baseline (в kh_pg — archkit conformance), и гейт объявляет «new red».
  if [ -f "$ROOT/tools/conformance-baseline.txt" ]; then
    if ! ORC_EVAL_ROOT="$ROOT" bash "$DIR/integration-baseline.sh" "$(pick_cmd)"; then
      echo "gate-l2-integration: FAIL — stand DSN (execution=${exec_id:-env})" >&2
      exit 1
    fi
    echo "gate-l2-integration: OK — stand DSN (baseline, no new red)"
    exit 0
  fi

  # 3) App-репозиторий без baseline — гоняем scoped integration напрямую.
  run "stand DSN (execution=${exec_id:-env})" "$(pick_cmd)"
fi
[ -n "${INTEGRATION_CMD:-}" ] && run "INTEGRATION_CMD" "$INTEGRATION_CMD"
if command -v docker >/dev/null 2>&1; then
  run "local docker testcontainers (no lease)" "$(pick_cmd)"
fi
echo "gate-l2-integration: FAIL — нет аренды/DSN/INTEGRATION_CMD/docker (fail-close, ADR-KIT-091)" >&2
exit 1
