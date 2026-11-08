#!/usr/bin/env bash
# _mobile-appium-remote.sh — исполняется НА MAC (не на dev-хосте).
# Прогон флоу через Appium + XCUITest (WebDriverAgent) на ФИЗИЧЕСКОМ iOS:
#   1) создать Safari-сессию (капы в APPIUM_CAPS),
#   2) открыть URL из флоу (openLink),
#   3) дождаться и проверить DOM-ассерты (assertVisible) с ретраями,
#   4) снять скриншот,
#   5) удалить сессию.
# Вход (env): APPIUM_BASE, APPIUM_CAPS, APPIUM_FLOW, APPIUM_SHOT.
# Замечания: переменные подставляем через ${}, JSON собираем python'ом (не строковой
# склейкой) — иначе bash 3.2/macOS-локаль ломает разбор имени переменной рядом с UTF-8.
set -uo pipefail

BASE="${APPIUM_BASE:-http://127.0.0.1:4723/wd/hub}"
CAPS="${APPIUM_CAPS:?APPIUM_CAPS не задан}"
FLOW="${APPIUM_FLOW:?APPIUM_FLOW не задан}"
SHOT="${APPIUM_SHOT:-/tmp/mobile-appium.png}"
WAIT_SECONDS="${APPIUM_ASSERT_WAIT:-45}"

url="$(grep -m1 -E 'openLink:' "${FLOW}" | sed -E 's/.*openLink:[[:space:]]*"?//; s/"?[[:space:]]*$//')"
[ -n "${url}" ] || { echo "appium: во флоу нет openLink" >&2; exit 2; }

sid="$(curl -sS -m 900 -H 'Content-Type: application/json' -X POST -d @"${CAPS}" "${BASE}/session" \
  | python3 -c 'import sys,json;print((json.load(sys.stdin).get("value") or {}).get("sessionId",""))')"
[ -n "${sid}" ] || { echo "appium: сессия не создалась (WDA/подпись? смотри лог Appium)" >&2; exit 1; }
trap 'curl -sS -m 30 -X DELETE "${BASE}/session/${sid}" >/dev/null 2>&1 || true' EXIT

payload_url="$(python3 -c 'import json,sys;print(json.dumps({"url":sys.argv[1]}))' "${url}")"
curl -sS -m 180 -H 'Content-Type: application/json' -X POST -d "${payload_url}" "${BASE}/session/${sid}/url" >/dev/null 2>&1 \
  || { echo "appium: navigation failed (${url})" >&2; exit 1; }

asserts="$(mktemp /tmp/mobile-asserts.XXXXXX)" || { echo "appium: mktemp недоступен (fail-close)" >&2; exit 2; }
grep -oE 'assertVisible:[[:space:]]*"[^"]+"' "${FLOW}" | sed -E 's/.*"([^"]+)"/\1/' > "${asserts}" || true
n_expected="$(grep -cE 'assertVisible:' "${FLOW}" || true)"
if [ "${n_expected:-0}" -gt 0 ] && [ ! -s "${asserts}" ]; then
  echo "appium: во флоу ${n_expected} assertVisible, разобрать не удалось (fail-close)" >&2
  exit 2
fi

fail=0
if [ -s "${asserts}" ]; then
  while IFS= read -r txt; do
    [ -n "${txt}" ] || continue
    xpath="//*[contains(normalize-space(.), \"${txt}\")]"
    payload="$(python3 -c 'import json,sys;print(json.dumps({"using":"xpath","value":sys.argv[1]}))' "${xpath}")"
    ok=0
    deadline=$(( $(date +%s) + WAIT_SECONDS ))
    while :; do
      r="$(curl -sS -m 20 -H 'Content-Type: application/json' -X POST -d "${payload}" "${BASE}/session/${sid}/element" 2>/dev/null || true)"
      case "${r}" in *ELEMENT*|*sessionId*) ok=1; break;; esac
      [ "$(date +%s)" -ge "${deadline}" ] && break
      sleep 2
    done
    if [ "${ok}" = 1 ]; then
      echo "appium: assert OK — ${txt}"
    else
      echo "appium: assert НЕ найден — ${txt}" >&2
      fail=1
    fi
  done < "${asserts}"
else
  echo "appium: во флоу нет assertVisible (только открытие URL + скриншот)"
fi
rm -f "${asserts}"

curl -sS -m 90 "${BASE}/session/${sid}/screenshot" \
  | python3 -c "import sys,json,base64;open(sys.argv[1],'wb').write(base64.b64decode(json.load(sys.stdin)['value']))" "${SHOT}" \
  || { echo "appium: скриншот не снят" >&2; exit 1; }
echo "appium: скриншот → ${SHOT}"
exit "${fail}"
