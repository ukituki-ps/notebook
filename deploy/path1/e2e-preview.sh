#!/usr/bin/env bash
# e2e-preview.sh — E2E для notebook на арендованном стенде (path1).
# Стенд/URL приходят из platform-скрипта run-stand-e2e.sh (env E2E_BASE_URL).
#
# Порядок: health (nginx JSON) -> auth-smoke API (401, register/login A/B,
# authed GET/POST/DELETE, A/B isolation, 404/400-негативы) -> Playwright chromium.
# Playwright — fail-close: нет node/npx/браузеров => ненулевой exit, не skip.
set -euo pipefail

base="${E2E_BASE_URL:-${PREVIEW_BASE_URL:-}}"
[ -n "$base" ] || { echo "e2e-preview: E2E_BASE_URL не задан" >&2; exit 2; }
base="${base%/}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
STATUS=""
BODY=""
HEADERS=""

fail() { echo "e2e-preview: FAIL $*" >&2; exit 1; }
ok() { echo "e2e-preview: ok — $*"; }

http() { # http METHOD PATH [JSON_BODY] [TOKEN]
  local method="$1" path="$2" data="${3:-}" token="${4:-}"
  local -a args=(-sS -m 20 -o "$TMP/body" -D "$TMP/headers" -w '%{http_code}' -X "$method" "$base$path")
  if [ -n "$data" ]; then args+=(-H 'Content-Type: application/json' --data "$data"); fi
  if [ -n "$token" ]; then args+=(-H "Authorization: Bearer $token"); fi
  STATUS="$(curl "${args[@]}")" || fail "curl $method $path: транспортная ошибка"
  BODY="$(cat "$TMP/body")"
  HEADERS="$(cat "$TMP/headers")"
}

json_string() { # json_string KEY [JSON] -> первое строковое значение
  local key="$1" src="${2:-$BODY}"
  printf '%s' "$src" | sed -n "s/.*\"$key\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -n1
}

json_number() { # json_number KEY [JSON] -> первое числовое значение
  local key="$1" src="${2:-$BODY}"
  printf '%s' "$src" | sed -n "s/.*\"$key\"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p" | head -n1
}

expect_status() { # expect_status WANT LABEL
  [ "$STATUS" = "$1" ] || fail "$2: ожидался HTTP $1, получен ${STATUS:-<нет>} (body=${BODY})"
}

expect_body() { # expect_body FIXED_SUBSTRING LABEL
  printf '%s' "$BODY" | grep -qF "$1" || fail "$2: в теле нет '$1' (body=${BODY})"
}

deny_body() { # deny_body FIXED_SUBSTRING LABEL
  if printf '%s' "$BODY" | grep -qF "$1"; then fail "$2: в теле не должно быть '$1' (body=${BODY})"; fi
}

expect_bearer() { # expect_bearer LABEL
  printf '%s' "$HEADERS" | grep -qiE '^www-authenticate:[[:space:]]*Bearer' \
    || fail "$1: нет заголовка WWW-Authenticate: Bearer"
}

# --- 1. Health: nginx JSON стенда -------------------------------------------
echo "e2e-preview: target=$base"
hz="$(curl -fsS -m 10 "$base/healthz")" || fail "/healthz недоступен ($base/healthz)"
case "$hz" in
  \{*\}) ;;
  *) fail "/healthz не JSON-объект: $hz" ;;
esac
build_ref="$(json_string build_ref "$hz")"
commit="$(json_string commit "$hz")"
[ -n "$build_ref" ] || fail "/healthz без build_ref"
printf '%s' "$commit" | grep -Eq '^[0-9a-f]{40}$' || fail "/healthz.commit=${commit} не 40hex"
echo "e2e-preview: health build_ref=$build_ref commit=$commit"

# --- 2. Auth-smoke API ------------------------------------------------------
stamp="$(date -u +%s)"
run="${stamp}$$"
userA="e2ea${stamp}${RANDOM}"
userB="e2eb${stamp}${RANDOM}"
password='e2e-secret-pass-1'
textA="e2e-note-A-${run}"
textB="e2e-note-B-${run}"

# 2.1 auth раньше всего: без токена -> 401 + WWW-Authenticate.
http GET /api/notes
expect_status 401 "unauth GET /api/notes"
expect_bearer "unauth GET /api/notes"
expect_body '"error":"unauthorized"' "unauth GET /api/notes"
ok "unauth GET /api/notes -> 401 + WWW-Authenticate: Bearer"

# 2.2 register A -> 201; повтор -> 409 username taken (не маскировать).
http POST /api/register "{\"username\":\"$userA\",\"password\":\"$password\"}"
expect_status 201 "register A"
[ "$(json_string username)" = "$userA" ] || fail "register A: username в ответе не '$userA' (body=${BODY})"
[ -n "$(json_number id)" ] || fail "register A: в ответе нет id (body=${BODY})"
ok "register A ($userA) -> 201"

http POST /api/register "{\"username\":\"$userA\",\"password\":\"$password\"}"
expect_status 409 "register A повторно"
expect_body '"error":"username taken"' "register A повторно"
ok "register A повторно -> 409 username taken"

# 2.3 login A -> 200 + непустой opaque-токен.
http POST /api/login "{\"username\":\"$userA\",\"password\":\"$password\"}"
expect_status 200 "login A"
tokenA="$(json_string token)"
[ ${#tokenA} -ge 32 ] || fail "login A: token пуст/короткий (len=${#tokenA}, body=${BODY})"
deny_body '"error"' "login A"
ok "login A -> 200 (token len=${#tokenA})"

# 2.4 authed POST/GET A.
http POST /api/notes "{\"text\":\"$textA\"}" "$tokenA"
expect_status 201 "POST /api/notes A"
idA="$(json_number id)"
[ -n "$idA" ] || fail "POST /api/notes A: нет id (body=${BODY})"
[ "$(json_string text)" = "$textA" ] || fail "POST /api/notes A: text не совпал (body=${BODY})"
ok "POST /api/notes A -> 201 id=$idA"

http GET /api/notes "" "$tokenA"
expect_status 200 "GET /api/notes A"
expect_body "\"id\":${idA}" "GET /api/notes A"
expect_body "\"text\":\"${textA}\"" "GET /api/notes A"
ok "GET /api/notes A содержит note A"

# 2.5 register/login B.
http POST /api/register "{\"username\":\"$userB\",\"password\":\"$password\"}"
expect_status 201 "register B"
http POST /api/login "{\"username\":\"$userB\",\"password\":\"$password\"}"
expect_status 200 "login B"
tokenB="$(json_string token)"
[ ${#tokenB} -ge 32 ] || fail "login B: token пуст/короткий (len=${#tokenB}, body=${BODY})"
ok "register/login B -> 201/200"

# 2.6 isolation: B не видит заметку A (свежий пользователь -> пустой список).
http GET /api/notes "" "$tokenB"
expect_status 200 "GET /api/notes B"
deny_body "\"id\":${idA}" "GET /api/notes B (не должен видеть note A)"
deny_body "$textA" "GET /api/notes B (не должен видеть note A)"
[ "$BODY" = "[]" ] || fail "GET /api/notes B: ожидался [] у нового пользователя, получено ${BODY}"
ok "A/B isolation: B не видит note A и получает []"

# 2.7 чужая заметка: B создаёт свою, A не может её удалить -> 404.
http POST /api/notes "{\"text\":\"$textB\"}" "$tokenB"
expect_status 201 "POST /api/notes B"
idB="$(json_number id)"
[ -n "$idB" ] || fail "POST /api/notes B: нет id (body=${BODY})"

http DELETE "/api/notes/$idB" "" "$tokenA"
expect_status 404 "DELETE чужой note B как A"
expect_body '"error":"not found"' "DELETE чужой note B как A"
ok "DELETE чужой note B как A -> 404 not found"

http GET /api/notes "" "$tokenB"
expect_status 200 "GET /api/notes B после чужого DELETE"
expect_body "\"id\":${idB}" "GET /api/notes B: note B должна остаться"
ok "чужая note B не удалена (изоляция подтверждена)"

# 2.8 своя DELETE -> 204, повтор -> 404, invalid id -> 400.
http DELETE "/api/notes/$idA" "" "$tokenA"
expect_status 204 "DELETE своей note A"
[ -z "$BODY" ] || fail "DELETE своей note A: 204 должен быть без тела (body=${BODY})"
ok "DELETE своей note A -> 204 без тела"

http DELETE "/api/notes/$idA" "" "$tokenA"
expect_status 404 "повторный DELETE note A"
expect_body '"error":"not found"' "повторный DELETE note A"
ok "повторный DELETE note A -> 404 not found"

http DELETE "/api/notes/abc" "" "$tokenA"
expect_status 400 "DELETE /api/notes/abc"
expect_body '"error":"invalid id"' "DELETE /api/notes/abc"
ok "DELETE /api/notes/abc -> 400 invalid id"

# 2.9 auth раньше method/id: без токена DELETE (в т.ч. чужой id) -> 401.
http DELETE "/api/notes/$idB"
expect_status 401 "unauth DELETE чужой note B"
expect_bearer "unauth DELETE чужой note B"
ok "unauth DELETE /api/notes/$idB -> 401"

# 2.10 уборка: B удаляет свою заметку.
http DELETE "/api/notes/$idB" "" "$tokenB"
expect_status 204 "DELETE своей note B"
ok "DELETE своей note B -> 204"

echo "e2e-preview: API smoke GREEN (auth 401, A/B isolation, 404/400, 204)"

# --- 3. Playwright chromium (fail-close) ------------------------------------
echo "e2e-preview: Playwright (chromium) против $base"
command -v node >/dev/null 2>&1 || fail "node не найден: Playwright E2E невозможен (fail-close, skip запрещён)"
command -v npx >/dev/null 2>&1 || fail "npx не найден: Playwright E2E невозможен (fail-close)"
[ -f "$ROOT/playwright.config.js" ] || fail "playwright.config.js отсутствует в $ROOT (нужен merge U02)"
[ -f "$ROOT/web/e2e/auth-notes.spec.js" ] || fail "web/e2e/auth-notes.spec.js отсутствует (fail-close)"

pw_chromium() { # pw_chromium DIR -> chromium.executablePath()
  ( cd "$1" && node -e 'process.stdout.write(require("@playwright/test").chromium.executablePath())' 2>/dev/null )
}
chromium="$(pw_chromium "$ROOT" || true)"
[ -n "$chromium" ] || chromium="$(pw_chromium "$ROOT/web" || true)"
[ -n "$chromium" ] || fail "@playwright/test не найден в $ROOT или $ROOT/web: npm ci && npx playwright install chromium (fail-close)"
if [ ! -f "$chromium" ]; then
  fail "chromium не установлен ($chromium): npx playwright install chromium (fail-close, не skip)"
fi
echo "e2e-preview: chromium=$chromium"
( cd "$ROOT" && E2E_BASE_URL="$base" PREVIEW_BASE_URL="$base" npx --no-install playwright test ) \
  || fail "Playwright E2E FAIL"

echo "e2e-preview: OK (health + auth-smoke + Playwright chromium)"
