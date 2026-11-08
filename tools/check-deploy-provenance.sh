#!/usr/bin/env bash
# gate-deploy-provenance — выкаченный билд обязан быть опознаваем (audit F003/E5438, P-1).
#
# Проблема: контракт /healthz.build_ref выполнял только deploy-preview-stand.sh. После влития
# фичи (PR #14) test1/test2 отдавали `{"build_ref":""}` и ДРУГОЙ бандл (index-BpkqL1u9.js вместо
# index-DvhBQ1LB.js, эталонный стал 404) → пост-деплой проверку (s46) не к чему привязать.
#
# Проверки (fail-close):
#   1) /healthz.build_ref непуст и РАВЕН ожидаемому ref (env/аргумент/preview-deploy.json);
#   2) если известен ожидаемый бандл — отдаваемый index.html ссылается ровно на него
#      (ловит «стенд отдаёт другой билд» и stale service-worker precache).
#
# Использование:
#   bash tools/check-deploy-provenance.sh <execution_id>            # URL/ref из аренды+preview-deploy
#   bash tools/check-deploy-provenance.sh --url URL --ref SHA [--bundle assets/index-x.js]
# Тестируемость без сети: --healthz-json FILE [--index-file FILE].
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DIR/.." && pwd)"
exec_id=""; URL=""; REF=""; BUNDLE=""; HZ_FILE=""; IDX_FILE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --url) URL="$2"; shift 2 ;;
    --ref) REF="$2"; shift 2 ;;
    --bundle) BUNDLE="$2"; shift 2 ;;
    --healthz-json) HZ_FILE="$2"; shift 2 ;;
    --index-file) IDX_FILE="$2"; shift 2 ;;
    *) exec_id="${1:-}"; shift ;;
  esac
done
fail() { echo "gate-deploy-provenance: FAIL — $1" >&2; exit 1; }

base="${NEXUS_BASE_URL:-http://nexus:9182}"; tok="${NEXUS_TOKEN:-${ORC_NEXUS_TOKEN:-}}"
# аренда стенда текущего исполнения (URL и, при отсутствии preview-deploy.json, ref)
lease() { # lease <field>
  [ -n "${tok:-}" ] && [ -n "${exec_id:-}" ] && curl -fsS -m 10 -H "Authorization: Bearer $tok" \
    "${base}/api/v1/stands/leases?execution_id=${exec_id}" 2>/dev/null \
    | python3 -c 'import sys,json;print((json.load(sys.stdin).get("lease") or {}).get(sys.argv[1],""))' "$1" 2>/dev/null
}
[ -n "$URL" ] || URL="$(lease stand_url || true)"
[ -n "$URL" ] || URL="${STAND_URL:-}"

pd="$ROOT/preview-deploy.json"
if [ -z "$REF" ] && [ -f "$pd" ]; then
  REF="$(python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));print(d.get("ref") or d.get("sha") or "")' "$pd" 2>/dev/null || true)"
  [ -z "$BUNDLE" ] && BUNDLE="$(python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));print(d.get("bundle") or "")' "$pd" 2>/dev/null || true)"
fi
[ -n "$REF" ] || REF="${EXPECTED_REF:-}"
[ -n "$REF" ] || fail "не определён ожидаемый ref (аренда/preview-deploy.json/--ref/EXPECTED_REF)"
[ -n "$URL" ] || [ -n "$HZ_FILE" ] || fail "не определён URL стенда (аренда/--url/STAND_URL)"

# 1) /healthz.build_ref
if [ -n "$HZ_FILE" ]; then
  hz="$(cat "$HZ_FILE")"
else
  hz="$(curl -kfsS -m 12 "${URL%/}/healthz" 2>/dev/null || true)"
fi
[ -n "$hz" ] || fail "healthz недоступен: ${URL%/}/healthz"
got="$(printf '%s' "$hz" | python3 -c 'import sys,json
try: print(json.load(sys.stdin).get("build_ref",""))
except Exception: print("")' 2>/dev/null || true)"
if [ -z "$got" ]; then
  fail "healthz.build_ref пуст — билд не опознаваем (образ собран без build-arg build_ref?).
  Ожидалось '$REF'. Проверь деплой-путь: preview → deploy/stands/preview-deploy.sh;
  primary/CI → тот же build-arg обязателен (иначе s46/post-deploy не привязать к коду)."
fi
[ "$got" = "$REF" ] || fail "healthz.build_ref='$got' != ожидаемого '$REF' (на стенде другой билд)"

# 2) бандл (если известен ожидаемый)
if [ -n "$BUNDLE" ]; then
  if [ -n "$IDX_FILE" ]; then
    idx="$(cat "$IDX_FILE")"
  else
    idx="$(curl -kfsS -m 12 "${URL%/}/" 2>/dev/null || true)"
  fi
  [ -n "$idx" ] || fail "не удалось получить index.html стенда (${URL%/}/)"
  served="$(printf '%s' "$idx" | grep -oE 'assets/index-[A-Za-z0-9_-]+\.js' | head -1)"
  [ -n "$served" ] || fail "в index.html не найден бандл assets/index-*.js"
  [ "$served" = "$BUNDLE" ] || fail "стенд отдаёт '$served', а доказательства сняты для '$BUNDLE' (другой билд / stale SW precache)"
  echo "gate-deploy-provenance: OK — ref=$got, bundle=$served"
else
  echo "gate-deploy-provenance: OK — ref=$got (бандл не сверялся: не задан ожидаемый)"
fi
