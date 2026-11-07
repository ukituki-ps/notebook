#!/usr/bin/env bash
# seed-mobile-devices — зарегистрировать устройства device-lab в Nexus (идемпотентно).
# Запускать ПОСЛЕ деплоя Nexus с миграцией 0041 (mobile_devices/mobile_leases).
# Требует admin/developer токен (mobile_register → CanPublishCanon).
set -uo pipefail
BASE="${NEXUS_MCP_URL:-http://192.168.1.20:9290/mcp}"
TOK="${NEXUS_TOKEN:-$(python3 -c "import json;print(json.load(open('/home/ukituki/.config/kilo/kilo.json'))['mcp']['nexus']['headers']['Authorization'].split()[-1])" 2>/dev/null)}"
[ -n "$TOK" ] || { echo "нет токена (NEXUS_TOKEN)"; exit 1; }
RUNNER="${MOBILE_RUNNER_URL:-http://192.168.1.17:8099}"

reg() { # reg <name> <platform> <os> <host> <transport> <serial> <udid> <browsers_json> <caps_json>
  local name="$1"
  python3 - "$@" "$RUNNER" <<'PY' > /tmp/_mdreg.json
import json,sys
_,name,plat,osv,host,tr,serial,udid,br,cp,runner = sys.argv
print(json.dumps({"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"mobile_register","arguments":{
 "name":name,"platform":plat,"os":osv,"host":host,"transport":tr,"serial":serial,"udid":udid,
 "browsers":json.loads(br),"capabilities":json.loads(cp),"runner_url":runner}}}))
PY
  curl -sS -m 30 -X POST "$BASE" -H "Authorization: Bearer $TOK" \
    -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
    --data-binary @/tmp/_mdreg.json | sed 's/^data: //' | tr -d '\n' | \
    python3 -c "import sys,json
d=json.loads(sys.stdin.read());r=d.get('result',d)
err = isinstance(r,dict) and r.get('isError')
print('  ', 'ERR' if err else 'OK', '(', sys.argv[1], ')', '' if not err else r['content'][0]['text'][:120])" "$name" 2>/dev/null || echo "   FAIL ($name)"
}

echo "seed mobile devices → $BASE (runner=$RUNNER)"
reg and-xiaomi   android 15     local adb 6TJNTSVCL7EUXODQ "" \
    '["com.android.chrome","com.mi.globalbrowser","org.mozilla.fennec_fdroid"]' \
    '["pwa","chrome-cdp","maestro","screenshot","gms","gecko"]'
reg and-huawei   android 12     local adb JUP0223A09000028 "" \
    '["com.huawei.browser","com.yandex.browser"]' \
    '["pwa","maestro","screenshot","no-gms"]'
reg ios-iphone11 ios     27.0.1  mac   devicectl "" 00008030-001438840208802E \
    '["com.apple.mobilesafari"]' \
    '["pwa","webkit-only","maestro","screenshot","xcuitest"]'
echo "done. проверь: mobile_list"
