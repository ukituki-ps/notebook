#!/usr/bin/env bash
# path1-gate — placeholder-free диспетчер гейтов path-1 (ADR-KIT-090/091).
# $1 = gate, $2 = execution_id (для стенд-гейтов; обычно {execution_id}).
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# В pinned gate-bundle DIR=/opt/gate-tools/tools, оцениваемое дерево — ORC_GATE_ROOT.
ROOT="${ORC_GATE_ROOT:-$(cd "$DIR/.." && pwd)}"
# Gate sandbox: canonical gate tools live next to this script (bundle mount).
# fault-catalog-exec pins `tools/<script>` detectors to this root.
ORC_GATE_TOOLS_ROOT="${ORC_GATE_TOOLS_ROOT:-$DIR}"
export ORC_GATE_TOOLS_ROOT
gate="${1:-}"; exec_id="${2:-${EXECUTION_ID:-}}"
base="${NEXUS_BASE_URL:-http://nexus:9182}"; tok="${NEXUS_TOKEN:-${ORC_NEXUS_TOKEN:-}}"
first() { ls $1 2>/dev/null | head -1; }
# idea_file <relname> — артефакт ТЕКУЩЕЙ фичи (детерминированно; инцидент E6355/F189:
# glob «первый по алфавиту» валидировал чужую фичу). Пусто → вызывающий fail-close.
idea_file() {
  local out=""
  if [ -f "$DIR/_feature_dir.py" ]; then
    out="$(python3 "$DIR/_feature_dir.py" --root "$ROOT" --name "$1" 2>/dev/null)"
  fi
  # Пустой результат = неоднозначность/нет feature — fail-close (не угадывать).
  printf '%s' "$out"
}
# resolve_run_id — id прогона канареек/детекторов СТРОГО: env RUN_ID, иначе ровно один
# каталог data/audit/runs/*; при 0 или >1 — fail-close (F2: не выбирать «головой» glob).
resolve_run_id() {
  local rid="${RUN_ID:-${FEATURE_RUN_ID:-}}"
  [ -n "$rid" ] && { printf '%s' "$rid"; return 0; }
  # Run-scoped: id ТЕКУЩЕГО исполнения. Иначе новый прогон писал/читал каталог чужого
  # прогона (инцидент E2389: proof попал в data/audit/runs/F188-v11).
  rid="${exec_id:-${EXECUTION_ID:-}}"
  [ -n "$rid" ] && { printf '%s' "$rid"; return 0; }
  local dirs=( data/audit/runs/*/ ) d n=0
  for d in "${dirs[@]}"; do [ -d "$d" ] && n=$((n+1)); done
  [ "$n" -eq 1 ] && { basename "${dirs[0]%/}"; return 0; }
  return 1
}
# feature_dir — каталог ТЕКУЩЕЙ фичи (для гейтов, работающих по артефактам фичи).
feature_dir() {
  local p
  for probe in report.md plan.md scenarios.json mobile-evidence.json; do
    p="$(idea_file "$probe")"
    [ -n "$p" ] && { dirname "$p"; return 0; }
  done
  return 1
}
inv() {
  local p
  # project-scoped: явный audit.invariants из path1.project.json, затем артефакт фичи.
  p="$(python3 "$DIR/_path1_project.py" --root "$ROOT" --line audit.invariants 2>/dev/null || true)"
  [ -n "$p" ] && { printf '%s' "$p"; return; }
  p="$(idea_file invariants.json)"; [ -n "$p" ] || p="$(idea_file invariants.yaml)"
  printf '%s' "$p"
}
lease_json() { # сырой JSON аренды текущего исполнения (для полей вроде stand_name)
  [ -n "${tok:-}" ] && [ -n "${exec_id:-}" ] && curl -fsS -m 10 -H "Authorization: Bearer $tok" \
    "${base:-http://nexus:9182}/api/v1/stands/leases?execution_id=${exec_id}" 2>/dev/null || true
}

lease_field() { # lease_field <field> : поле аренды (stand_name/stand_url/stand_dsn_ref) по execution_id
  curl -fsS -m 10 -H "Authorization: Bearer $tok" \
    "${base}/api/v1/stands/leases?execution_id=${exec_id}" 2>/dev/null \
    | python3 -c 'import sys,json;print((json.load(sys.stdin).get("lease") or {}).get(sys.argv[1],""))' "$1" 2>/dev/null
}

# Каталог отказов — из контракта проекта (path1.project.json → detectors.catalog_dir),
# иначе app-репо с собственной раскладкой получал «каталог не найден».
catalog_dir() {
  local c
  c="$(python3 "$DIR/_path1_project.py" --root "$ROOT" --line detectors.catalog_dir 2>/dev/null || true)"
  printf '%s' "${c:-audit/fault-catalog}"
}

# app_audit_mode — ЯВНАЯ декларация audit.mode=app в контракте проекта.
# Только она включает app-поблажки (critical-канарейки по применимым классам,
# DSN не обязателен при database=false+require_dsn=false, invariants опциональны).
# Нет декларации → kit-поведение (полный fail-closed).
app_audit_mode() {
  [ "$(python3 "$DIR/_path1_project.py" --root "$ROOT" --line audit.mode 2>/dev/null || true)" = "app" ]
}

# Fail-closed: если окружение не дало разрешить корень/каталог (нет dirname, кривой путь),
# гейт обязан упасть, а не «пройти» PASS-NA на пустом platform.
[ -n "${DIR:-}" ] && [ -d "${DIR:-}" ] || { echo "path1-gate: FAIL — не разрешился каталог кита (DIR='${DIR:-}')" >&2; exit 2; }
[ -n "${ROOT:-}" ] && [ -d "${ROOT:-}" ] || { echo "path1-gate: FAIL — не разрешился корень репо (ROOT='${ROOT:-}')" >&2; exit 2; }

case "$gate" in
  run-id) { resolve_run_id || exit 1; echo; } ;;
  requirement-trace)
    # F190 C-22: сверка «просил человек ↔ делаем» (intent-trace.json) с сырым запросом.
    exec python3 "$DIR/check-requirement-trace.py" --trace "$(idea_file intent-trace.json)" --request "$(idea_file feature-request.md)" ;;
  coverage-verdict)
    # path-1 3.1.1 (ADR-3.2-03 D3): s17 verdict/severity/owner → fail-close при
    # verdict=fail или любом major/critical gap. Читает машинное зеркало отчёта.
    exec python3 "$DIR/check-coverage-verdict.py" --path "$(idea_file coverage-audit.json)" ;;
  test-ref-runnable) exec python3 "$DIR/check-test-ref-runnable.py" --invariants "$(inv)" ;;
  catalog-invariants)
    if app_audit_mode; then
      exec python3 "$DIR/check-catalog-invariants.py" --catalog "$(catalog_dir)" --invariants "$(inv)" --verdicts "$(idea_file fault-verdicts.json)" --app-mode
    fi
    exec python3 "$DIR/check-catalog-invariants.py" --catalog "$(catalog_dir)" --invariants "$(inv)" --verdicts "$(idea_file fault-verdicts.json)" ;;
  scenario-coverage)
    b="$(idea_file scenarios.json)"; e="$(idea_file scenario-evidence.json)"
    if [ -z "$b" ] || [ -z "$e" ]; then
      # Backend-only инкремент без UI-поверхности: сценарии E2E не применимы.
      _base="${UI_SURFACE_BASE:-${ORC_BASE_SHA:-origin/main}}"
      _rc=0; _reason="$(python3 "$DIR/ui_surface.py" --root "$ROOT" --base "$_base" --print-reason 2>/dev/null)" || _rc=$?
      if [ "$_rc" = 1 ]; then
        echo "gate-scenario-coverage: PASS-NA — нет UI-поверхности ($_reason)"
        exit 0
      fi
      echo "gate-scenario-coverage: FAIL — scenarios.json/scenario-evidence.json не разрешены (${_reason:-ui surface rc=$_rc})" >&2
      exit 1
    fi
    exec python3 "$DIR/check-scenario-coverage.py" --brief "$b" --evidence "$e" ;;
  fault-catalog) exec python3 "$DIR/fault-catalog-check.py" --mode verdicts --require-proof --catalog "$(catalog_dir)" --verdicts "$(idea_file fault-verdicts.json)" ;;
  fault-catalog-exec)
    rid="$(resolve_run_id)" || { echo "gate-fault-catalog-exec: FAIL — run-id неоднозначен (data/audit/runs/*: 0 или >1); задай RUN_ID=${exec_id}" >&2; exit 1; }
    _skip_dsn=0
    if app_audit_mode; then
      _db="$(python3 "$DIR/_path1_project.py" --root "$ROOT" --line audit.database 2>/dev/null || true)"
      _rd="$(python3 "$DIR/_path1_project.py" --root "$ROOT" --line canaries.require_dsn 2>/dev/null || true)"
      _db_false=0; _rd_false=0
      case "$_db" in False|false|0) _db_false=1;; esac
      case "$_rd" in False|false|0) _rd_false=1;; esac
      if [ "$_db_false" = 1 ] && [ "$_rd_false" = 1 ]; then
        _skip_dsn=1
        echo "gate-fault-catalog-exec: app-режим (audit.mode=app, database=false, require_dsn=false) — DSN не требуется" >&2
      fi
    fi
    if [ "$_skip_dsn" = 0 ]; then
      ref="$(lease_field stand_dsn_ref)"
      case "$ref" in
        env:*) v="${ref#env:}"; [ -n "${!v:-}" ] && export TEST_DATABASE_URL="${!v}";;
        "")    : ;;
        *)     export TEST_DATABASE_URL="$ref";;
      esac
      # Fallback (E8141): DSN из рантайма арендованного стенда — его пишет deploy-preview-stand.sh.
      # Без этого гейт перезапускал DB-детекторы без DSN, они слепли («no tests to run») и приёмка падала.
      if [ -z "${TEST_DATABASE_URL:-}" ]; then
        _sn="$(lease_json 2>/dev/null | python3 -c 'import sys,json
try: print((json.load(sys.stdin).get("lease") or {}).get("stand_name",""))
except Exception: print("")' 2>/dev/null || true)"
        # ТОЛЬКО стенд из аренды (review F-DSN-1): хардкод-фолбэк на test1 позволял прогнать
        # DB-детекторы против БД ЧУЖОГО стенда и получить чужой вердикт.
        [ -n "$_sn" ] || { echo "gate-fault-catalog-exec: FAIL — не определён стенд аренды (нельзя выбрать DSN)" >&2; exit 1; }
        _dsnf="$ROOT/deploy/stands/.runtime/${_sn}/dsn"
        [ -s "$_dsnf" ] || { echo "gate-fault-catalog-exec: FAIL — нет DSN стенда '${_sn}' (${_dsnf}); перевыкати стенд (deploy-preview-stand)" >&2; exit 1; }
        export TEST_DATABASE_URL="$(cat "$_dsnf")"
        echo "gate-fault-catalog-exec: DSN стенда '${_sn}' из рантайма" >&2
      fi
      [ -n "${TEST_DATABASE_URL:-}" ] || { echo "gate-fault-catalog-exec: FAIL — DSN стенда не найден (env TEST_DATABASE_URL / аренда stand_dsn_ref / deploy/stands/.runtime/<stand>/dsn)" >&2; exit 1; }
    fi
    _oracles="$(python3 "$DIR/_path1_project.py" --root "$ROOT" --get audit.oracles --json 2>/dev/null || true)"
    _oracle_args=()
    if [ -n "$_oracles" ] && [ "$_oracles" != "null" ] && [ "$_oracles" != "{}" ]; then
      _oracle_args=(--oracles "$_oracles")
    fi
    _exec_root="${ORC_EXECUTION_ROOT:-$(dirname "$ROOT")}"
    _proof_out="$_exec_root/data/audit/runs/$rid/proof.json"
    mkdir -p "$(dirname "$_proof_out")"
    exec python3 "$DIR/fault-catalog-check.py" --mode execute --catalog "$(catalog_dir)" --run-id "$rid" --verdicts "$(idea_file fault-verdicts.json)" "${_oracle_args[@]}" --proof-out "$_proof_out" --sandbox ;;
  canary)
    run="$(resolve_run_id)" || { echo "gate-canary: FAIL — run-id неоднозначен (data/audit/runs/*: 0 или >1); задай RUN_ID=${exec_id}" >&2; exit 1; }
    if app_audit_mode; then
      exec python3 "$DIR/audit-canary-check.py" --mode verify --run "$run" --require-critical --catalog "$(catalog_dir)" --verdicts "$(idea_file fault-verdicts.json)" --app-mode
    fi
    exec python3 "$DIR/audit-canary-check.py" --mode verify --run "$run" --require-critical --catalog "$(catalog_dir)" ;;
  e2e-preview) exec bash "$DIR/check-preview-verified.sh" "$exec_id" ;;
  preview-deploy) exec bash "$DIR/check-preview-deployed.sh" "$exec_id" ;;
  stand-leased) exec bash "$DIR/check-stand-leased.sh" "$exec_id" ;;
  ui-audit)
    # Платформа: UI_PLATFORM > path1.ui.json > авто-детект поверхности.
    # Шаг присутствует во ВСЕХ проектах; бэкенд-only проходит как PASS-NA,
    # но при наличии UI без объявления — fail-close (нельзя молча пропустить).
    plat="${UI_PLATFORM:-}"
    if [ -z "$plat" ] && [ -f "$ROOT/path1.ui.json" ]; then
      plat="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("platform","web"))' "$ROOT/path1.ui.json" 2>/dev/null || echo web)"
    fi
    if [ -z "$plat" ]; then
      found=""
      for f in frontend/package.json nexus-ui/package.json app/package.json web/package.json; do
        [ -f "$ROOT/$f" ] && found=1
      done
      compgen -G "$ROOT/ios/*.xcodeproj" >/dev/null 2>&1 && found=1
      [ -f "$ROOT/android/build.gradle" ] && found=1
      [ -f "$ROOT/mobile/pubspec.yaml" ] && found=1
      if [ -n "$found" ]; then
        echo "gate-ui-audit: FAIL — в проекте есть UI, но нет path1.ui.json (объяви platform: web|mobile|both)" >&2; exit 1
      fi
      echo "gate-ui-audit: PASS-NA — UI-поверхность не обнаружена и не объявлена"; exit 0
    fi
    # Привязка к билду стенда: preview-deploy.json (канонически — КОРЕНЬ репо, как в
    # check-preview-deployed/verified; sha → ref=выкаченный коммит). Если файл есть, а
    # sha/ref пуст — fail-close (нельзя молча пропустить привязку; инцидент E2389:
    # stand.sha=a8a963c при выкаченном 5894408, привязка не проверялась).
    exp=""; pd="$ROOT/preview-deploy.json"
    [ -f "$pd" ] || pd="$(idea_file preview-deploy.json)"
    if [ -n "$pd" ] && [ -f "$pd" ]; then
      exp="$(python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));print(d.get("sha") or d.get("ref") or "")' "$pd" 2>/dev/null)"
      [ -n "$exp" ] || { echo "gate-ui-audit: FAIL — preview-deploy.json без sha/ref (нельзя привязать аудит к билду стенда)" >&2; exit 1; }
      # Привязка к ПРОГОНУ: preview-deploy.json обязан нести execution_id текущего прогона.
      # Инцидент E3877: залежавшийся (закоммиченный в main от F188) preview-deploy.json
      # позволял «привязать» аудит к чужому деплою (стенд test2, lease test1).
      pdex="$(python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));print(d.get("execution_id") or "")' "$pd" 2>/dev/null)"
      case "$exec_id" in
        ""|*'{'*) : ;;
        *) [ -n "$pdex" ] || { echo "gate-ui-audit: FAIL — preview-deploy.json без execution_id (деплой не привязан к прогону; выполни s20b/preview-deploy)" >&2; exit 1; }
           [ "$pdex" = "$exec_id" ] || { echo "gate-ui-audit: FAIL — preview-deploy.json прогона '$pdex', а аудит принимается для '$exec_id' (залежавшийся артефакт чужого прогона)" >&2; exit 1; } ;;
      esac
      exec python3 "$DIR/ui-audit-check.py" --root "$ROOT" --platform "$plat" --expect-sha "$exp"
    fi
    exec python3 "$DIR/ui-audit-check.py" --root "$ROOT" --platform "$plat" ;;
  openapi-schema)
    exec python3 "$DIR/check-openapi-findings.py" ;;
  mobile-lab)
    # device-lab: для platform mobile/both — doctor (устройства живы) + доказательства пробы.
    plat="${UI_PLATFORM:-}"
    if [ -z "$plat" ] && [ -f "$ROOT/path1.ui.json" ]; then
      plat="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("platform",""))' "$ROOT/path1.ui.json" 2>/dev/null)"
    fi
    # Execution-scoped NA: если s22d.mobile_probe скипнут по when (platform=web),
    # мобильный блок к фиче не применим — даже когда проектный path1.ui.json = both.
    # Артефакт обязан быть согласован: status=na И platform=web.
    _mev="$(idea_file mobile-evidence.json)"
    if [ -n "$_mev" ] && python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); raise SystemExit(0 if str(d.get("status","")).lower()=="na" and str(d.get("platform","")).lower()=="web" else 1)' "$_mev" 2>/dev/null; then
      echo "gate-mobile-lab: PASS-NA — mobile-evidence status=na (platform=web; s22d skipped by when)"
      exit 0
    fi
    case "${plat:-}" in
      mobile|both) : ;;
      *) echo "gate-mobile-lab: PASS-NA — platform='${plat:-none}' не включает mobile"; exit 0 ;;
    esac
    # Живой doctor возможен только там, где есть тулчейн device-lab (dev-хост: adb+ssh+maestro).
    # В контейнере ORC тулчейна нет (нет adb/maestro/ssh, устройства недоступны) — принимаем
    # АРТЕФАКТЫ пробы (mobile-evidence.json: реальные скриншоты обоих движков, stand.sha),
    # по аналогии с gate-e2e-preview, который читает preview-verdict.json. Fail-close сохранён:
    # без валидных артефактов гейт падает (см. mobile-evidence-check.py).
    if [ "${MOBILE_LAB_ARTIFACTS_ONLY:-0}" = "1" ]; then
      echo "gate-mobile-lab: artifact-only mode (MOBILE_LAB_ARTIFACTS_ONLY=1) — проверяю артефакты пробы" >&2
    elif command -v adb >/dev/null 2>&1 && command -v maestro >/dev/null 2>&1; then
      bash "$DIR/mobile-device.sh" doctor || exit 1
    else
      echo "gate-mobile-lab: device-lab toolchain incomplete (нужны adb+maestro) — проверяю артефакты пробы" >&2
    fi
    pd="$(idea_file preview-deploy.json)"; exp=""
    # kit пишет в preview-deploy.json ключ ref (историческое sha встречается в старых прогонах)
    [ -n "$pd" ] && exp="$(python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));print(d.get("ref") or d.get("sha") or "")' "$pd" 2>/dev/null)"
    if [ -n "$exp" ]; then
      exec python3 "$DIR/mobile-evidence-check.py" --root "$ROOT" --expect-sha "$exp"
    else
      exec python3 "$DIR/mobile-evidence-check.py" --root "$ROOT"
    fi ;;
  evidence-durable)
    # p.1/p.2 (аудит F003/E5438): доказательства прогона обязаны быть durable и repo-relative.
    # Сначала идемпотентно экспортируем прогон в артефакты фичи, затем проверяем.
    bash "$DIR/export-run-evidence.sh" "$exec_id" --root "$ROOT" >/dev/null 2>&1 \
      || echo "gate-evidence-durable: warn — экспорт прогона не удался (нет данных для $exec_id?)" >&2
    fd="$(feature_dir || true)"
    exec python3 "$DIR/check-evidence-durable.py" --root "$ROOT" ${fd:+--feature-dir "$fd"} --require-manifest ;;
  links-resolve)
    # p.3: пути и line-refs внутри артефактов обязаны разрешаться (фантомные пути/устаревшие строки).
    fd="$(feature_dir || true)"
    exec python3 "$DIR/check-links-resolve.py" --root "$ROOT" ${fd:+--feature-dir "$fd"} ;;
  claims-text)
    # p.6: нормативный текст артефактов обязан совпадать с тем, что эмитит код (связка MSG_* ↔ «цитата»).
    fd="$(feature_dir || true)"
    exec python3 "$DIR/check-claims-text.py" --root "$ROOT" ${fd:+--feature-dir "$fd"} ;;
  deploy-provenance)
    # p.4: выкаченный билд опознаваем (build_ref == ref; бандл стенда == бандл доказательств).
    exec bash "$DIR/check-deploy-provenance.sh" "$exec_id" ;;
  branch-fresh)
    # p.7: preflight перед push в primary (ветка не отстала, dry-run merge без конфликтов).
    exec bash "$DIR/check-branch-fresh.sh" --branch "${WORK_BRANCH:-}" --expect "${TARGET_REPO_HEAD:-}" --base "${BRANCH_BASE:-origin/main}" ;;
  graph-actualized)
    # UI-граф: фича обязана быть в arch/structure/ui-pages/*.yaml (или UI-GRAPH.yaml фичи),
    # актуализированном ЭТИМ прогоном (E3877: s04/s21 скипнуты → модель разошлась с кодом).
    exec python3 "$DIR/check-graph-actualized.py" --root "$ROOT" --base "${GRAPH_BASE:-origin/main}" --execution "$exec_id" ;;
  prototype-accept)
    # s03b: человеческая приёмка прототипа; fail-close по manifest/review/digest.
    # $2 = execution_id не нужен; фича резолвится по prototypes/v*/prototype-review.json
    # или ORC_FEATURE_DIR. S3-объект должен быть материализован в .fig-cache.
    exec python3 "$DIR/check-prototype-accept.py" --root "$ROOT" ${ORC_FEATURE_DIR:+--feature-dir "$ORC_FEATURE_DIR"} ;;
  ds-pin|design-integrate|ds-usage|ux-audit)
    exec python3 "$DIR/check-design-gates.py" "$gate" --root "$ROOT" ${ORC_FEATURE_DIR:+--feature-dir "$ORC_FEATURE_DIR"} ;;
  unit-proto-coverage|unit-ds-lock)
    screen=""; [ "${3:-}" = "--screen" ] && screen="${4:-}"
    exec python3 "$DIR/check-design-gates.py" "$gate" --root "$ROOT" ${ORC_FEATURE_DIR:+--feature-dir "$ORC_FEATURE_DIR"} ${screen:+--screen "$screen"} ;;
  design-review)
    kind=""; [ "${3:-}" = "--kind" ] && kind="${4:-}"
    screen=""; [ "${5:-}" = "--screen" ] && screen="${6:-}"
    exec python3 "$DIR/check-design-gates.py" design-review --root "$ROOT" ${ORC_FEATURE_DIR:+--feature-dir "$ORC_FEATURE_DIR"} --kind "$kind" ${screen:+--screen "$screen"} ;;
  ds-drift)
    base=""; [ "${3:-}" = "--base" ] && base="${4:-}"
    exec python3 "$DIR/check-design-gates.py" ds-drift --root "$ROOT" ${ORC_FEATURE_DIR:+--feature-dir "$ORC_FEATURE_DIR"} ${base:+--base "$base"} ;;
  ds-token-drift)
    # E0809: implementation CSS tokens must match design/tokens.json.
    exec python3 "$DIR/check-ds-token-drift.py" --root "$ROOT" ;;
  *) echo "path1-gate: unknown gate '$gate' (fail-close)" >&2; exit 2 ;;
esac
