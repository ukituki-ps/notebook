#!/usr/bin/env bash
# mobile-device — брокер реальных мобильных устройств (device-lab, path-1 mobile).
# Даёт тестерам/аудиторам интерфейса единый способ: список, аренда, запуск PWA/флоу,
# скриншоты — и всё машинно-доказуемо. Android — локальный adb+Maestro; iOS — Mac по ssh.
#
#   mobile-device list
#   mobile-device doctor
#   mobile-device lease <id> [--exec E####] [--ttl 120]
#   mobile-device release <id|--exec E####>
#   mobile-device url <id> <url> [--out DIR]     # открыть URL в браузере + скриншот
#   mobile-device test <id> <flow.yaml> [--out DIR]
#   mobile-device shot <id> <out.png>
#
# Транспорты (поле transport в реестре):
#   adb       — Android: локальный adb + Maestro (тапы/ассерты/скриншот);
#   simulator — iOS-симулятор на Mac: Maestro --udid (тапы/ассерты/скриншот);
#   appium    — ФИЗИЧЕСКИЙ iOS на Mac: Appium + XCUITest (WebDriverAgent) — ПОЛНЫЕ флоу
#               (открыть URL, DOM-ассерты, скриншот). Требования к среде Mac:
#                 * Appium запущен в GUI-сессии пользователя (иначе WDA не подписывается, code 65):
#                   sudo launchctl asuser 501 sudo -u ukituki /bin/bash -lc \
#                     'nohup /opt/homebrew/bin/appium --base-path /wd/hub --log-level info > /tmp/appium.log 2>&1 &'
#                 * команда/сертификат (поля реестра appium_team/appium_signing_id/
#                   appium_wda_bundle; env-перекрытия APPIUM_TEAM/APPIUM_SIGNING_ID/APPIUM_WDA_BUNDLE);
#                 * на устройстве: Developer Mode + «Enable UI Automation», Safari → Дополнительно →
#                   включены «Веб-инспектор» и «Удалённая автоматизация».
#               Капы/лимиты: APPIUM_BASE (default http://127.0.0.1:4723/wd/hub), APPIUM_ASSERT_WAIT.
#   devicectl — ФИЗИЧЕСКИЙ iOS на Mac БЕЗ подписи: `devicectl device process launch --payload-url`
#               + `device capture screenshot` (открыть URL + скриншот; тапы/ассерты НЕ поддерживаются) —
#               аварийный путь, когда Appium недоступен.
#
# iOS-ландшафт (почему так): Maestro/XCUITest/Appium для физического iOS строят XCUITest-раннер
# и требуют codesigning-identity на Mac (`security find-identity -v -p codesigning` ≥ 1;
# сейчас 0 → Maestro не перечисляет устройство). devicectl подписи не требует и закрывает
# «проба на реальном устройстве + скриншот». Для тапов/ассертов — добавить Apple ID (Personal
# Team) в Xcode, либо Appium+WDA.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REG="${MOBILE_DEVICES:-$DIR/mobile-devices.json}"
ADB="${ADB:-$HOME/android/platform-tools/adb}"
MAESTRO="${MAESTRO:-$HOME/.maestro/bin/maestro}"
MAC="${MOBILE_MAC_HOST:-mac}"
M_MAESTRO='/Users/ukituki/.maestro/bin/maestro'
M_JAVA='/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home'
LEASE_DIR="${MOBILE_LEASE_DIR:-/tmp/mobile-leases}"
die() { echo "mobile-device: $*" >&2; exit 1; }
dev_field() { python3 - "$REG" "$1" "$2" <<'PY'
import json,sys
reg,id_,f=sys.argv[1],sys.argv[2],sys.argv[3]
d=json.load(open(reg,encoding="utf-8"))
for x in d["devices"]:
    if x["id"]==id_: print(x.get(f,"")); break
PY
}
all_ids() { python3 - "$REG" <<'PY'
import json,sys
for x in json.load(open(sys.argv[1],encoding="utf-8"))["devices"]: print(x["id"])
PY
}
is_android() { [ "$(dev_field "$1" platform)" = android ]; }
is_devicectl() { [ "$(dev_field "$1" transport)" = devicectl ]; }

# --- MIUI/HyperOS: авто-подтверждение диалога «Установка через USB» -----------
# HyperOS перехватывает КАЖДУЮ установку по adb (в т.ч. драйвера Maestro, который
# ставится на каждый прогон и удаляется после) диалогом SecurityCenter
# com.miui.securitycenter/…install.AdbInstallActivity: «Установить это приложение
# через USB?» с галочкой «Запомнить выбор» и кнопками «Установить»/«Запретить (N)».
# Если никто не нажал — MIUI сам жмёт «Запретить» по таймеру ~5 c, установка падает
# с INSTALL_FAILED_USER_RESTRICTED. Галочка «Запомнить выбор» на HyperOS 2.0 НЕ
# сохраняется (проверено: сброшена даже при вставленной SIM и активном Mi-аккаунте).
# Поэтому на время прогона поднимаем watcher, который жмёт «Запомнить выбор» +
# «Установить» по координатам из uiautomator-дампа (устойчиво к разрешению экрана).
# Отключается: MOBILE_APPROVE=0. TTL watcher: MOBILE_APPROVE_TTL (по умолчанию 900 c).
MOBILE_APPROVE="${MOBILE_APPROVE:-1}"

_approve_tap() { # <serial> <bounds [x1,y1][x2,y2]>
  local d="$1" b="$2" x1 y1 x2 y2
  x1=${b%%][*}; x1=${x1#[}; y1=${b#*[}; y1=${y1%%]*}; x1=${x1%%,*}; y1=${y1##*,}
  x2=${b##*[}; x2=${x2%%,*}; y2=${b##*,}; y2=${y2%]}
  "$ADB" -s "$d" shell input tap $(( (x1 + x2) / 2 )) $(( (y1 + y2) / 2 )) >/dev/null 2>&1
}

_approve_loop() { # <serial> <seconds>
  local d="$1" end=$(( $(date +%s) + ${2:-900} )) xml cb ok
  while [ "$(date +%s)" -lt "$end" ]; do
    if "$ADB" -s "$d" shell 'dumpsys activity activities 2>/dev/null | grep -q AdbInstallActivity' 2>/dev/null; then
      xml=$("$ADB" -s "$d" shell 'uiautomator dump /sdcard/ad_approve.xml >/dev/null 2>&1; cat /sdcard/ad_approve.xml' 2>/dev/null)
      cb=$(printf '%s' "$xml" | grep -o 'do_not_ask_checkbox[^/]*bounds="\[[0-9,]*\]\[[0-9,]*\]"' | grep -o 'bounds="[^"]*"' | head -1 | cut -d'"' -f2)
      ok=$(printf '%s' "$xml" | grep -o 'android:id/button2[^/]*bounds="\[[0-9,]*\]\[[0-9,]*\]"' | grep -o 'bounds="[^"]*"' | head -1 | cut -d'"' -f2)
      [ -n "$cb" ] && _approve_tap "$d" "$cb"
      sleep 0.3
      [ -n "$ok" ] && _approve_tap "$d" "$ok"
      echo "mobile-device: MIUI-approve cb=$cb ok=$ok" >&2
      sleep 0.7
    fi
    sleep 0.3
  done
}

_approve_start() { # <serial> → печатает PID watcher (пусто, если выключен/не MIUI)
  [ "$MOBILE_APPROVE" = "1" ] || { echo ""; return 0; }
  # Только MIUI/HyperOS: у прочих вендоров диалога AdbInstallActivity нет.
  local miui
  miui=$("$ADB" -s "$1" shell 'getprop ro.miui.ui.version.name; getprop ro.mi.os.version.name' 2>/dev/null | tr -d '[:space:]')
  [ -n "$miui" ] || { echo ""; return 0; }
  # ВАЖНО: вывод в файл. Иначе фоновая задача держит stdout и `$(...)` зависает
  # (командная подстановка ждёт закрытия всех писателей в свой пайп).
  local log="/tmp/mobile-approve-${1}.log"
  _approve_loop "$1" "${MOBILE_APPROVE_TTL:-900}" >>"$log" 2>&1 &
  echo $!
}

_approve_stop() { # <pid>
  [ -n "${1:-}" ] && kill "$1" 2>/dev/null; true
}
is_appium() { [ "$(dev_field "$1" transport)" = appium ]; }

# _appium_caps <id> — JSON-капы Appium/XCUITest (Safari). Env-перекрытия:
# APPIUM_TEAM / APPIUM_SIGNING_ID / APPIUM_WDA_BUNDLE / APPIUM_BROWSER.
_appium_caps() {
  python3 - "$REG" "$1" <<'PYCAPS'
import json,os,sys
reg,id_=sys.argv[1],sys.argv[2]
m=[x for x in json.load(open(reg,encoding="utf-8"))["devices"] if x["id"]==id_][0]
caps={"platformName":"iOS","appium:automationName":"XCUITest","appium:udid":m.get("udid",""),
      "browserName":os.environ.get("APPIUM_BROWSER","Safari"),
      "appium:xcodeOrgId":os.environ.get("APPIUM_TEAM") or m.get("appium_team",""),
      "appium:xcodeSigningId":os.environ.get("APPIUM_SIGNING_ID") or m.get("appium_signing_id","Apple Development"),
      "appium:updatedWDABundleId":os.environ.get("APPIUM_WDA_BUNDLE") or m.get("appium_wda_bundle","pro.meins.wda"),
      "appium:newCommandTimeout":300}
print(json.dumps({"capabilities":{"alwaysMatch":{k:v for k,v in caps.items() if v}}}))
PYCAPS
}

# _run_flow_appium <id> <flow> <outdir> — прогон НА MAC через Appium (DOM-ассерты, скриншот).
_run_flow_appium() {
  local id="$1" flow="$2" out="${3:-}" capsf shotname
  local rscript="$DIR/_mobile-appium-remote.sh"
  [ -f "$rscript" ] || die "нет $rscript (кит не доставлен?)"
  capsf="$(mktemp /tmp/mobile-caps-XXXX.json)"; _appium_caps "$id" > "$capsf"
  shotname="$(grep -m1 -E 'takeScreenshot:' "$flow" | sed -E 's/.*takeScreenshot:[[:space:]]*"?//; s/"?[[:space:]]*$//')"
  scp -q "$rscript" "$MAC:/tmp/_mobile-appium-remote.sh" || die "scp на $MAC не удался"
  scp -q "$flow" "$MAC:/tmp/mobile-appium-flow.yaml" || die "scp flow на $MAC не удался"
  scp -q "$capsf" "$MAC:/tmp/mobile-appium-caps.json" || die "scp caps на $MAC не удался"
  local remote_shot="/tmp/mobile-appium-$id-$$.png"
  ssh -o BatchMode=yes "$MAC" \
    "APPIUM_BASE='${APPIUM_BASE:-http://127.0.0.1:4723/wd/hub}' APPIUM_CAPS=/tmp/mobile-appium-caps.json APPIUM_FLOW=/tmp/mobile-appium-flow.yaml APPIUM_SHOT='$remote_shot' bash /tmp/_mobile-appium-remote.sh"
  local rc=$?
  rm -f "$capsf"
  if [ -n "$out" ]; then
    mkdir -p "$out"
    scp -q "$MAC:$remote_shot" "$out/screenshot.png" 2>/dev/null || true
    [ -n "$shotname" ] && [ -f "$out/screenshot.png" ] && cp -f "$out/screenshot.png" "$out/$shotname.png"
  fi
  return $rc
}
host_of() { dev_field "$1" host; }
serial_of() { dev_field "$1" serial; }
udid_of() { dev_field "$1" udid; }

c_list() {
  echo "id            platform  os        host   status"
  for id in $(all_ids); do
    local st
    if is_android "$id"; then
      st=$("$ADB" devices 2>/dev/null | awk -v s="$(serial_of "$id")" '$1==s{print $2}')
      [ -z "${st:-}" ] && st="offline"
      [ "$st" = "device" ] && st="connected"
    else
      st=$(ssh -o BatchMode=yes -o ConnectTimeout=6 "$MAC" "xcrun devicectl list devices 2>/dev/null | grep -c '$(udid_of "$id")'" 2>/dev/null)
      [ "${st:-0}" != "0" ] && st="connected" || st="offline"
    fi
    printf '%-13s %-9s %-9s %-6s %s%s\n' "$id" "$(dev_field "$id" platform)" "$(dev_field "$id" os)" "$(host_of "$id")" "$st" "$([ -f "$LEASE_DIR/$id" ] && echo '  [leased]')"
  done
}
c_doctor() {
  local rc=0
  echo "== toolchain =="
  [ -x "$ADB" ] && echo "adb: $("$ADB" version 2>/dev/null | head -1)" || { echo "adb: НЕТ ($ADB)"; rc=1; }
  [ -x "$MAESTRO" ] && echo "maestro(local): $("$MAESTRO" --version 2>/dev/null | tail -1)" || { echo "maestro(local): НЕТ"; rc=1; }
  echo "== mac ($MAC) =="
  if ssh -o BatchMode=yes -o ConnectTimeout=8 "$MAC" "export JAVA_HOME=$M_JAVA; export PATH=\$HOME/.maestro/bin:\$PATH; $M_MAESTRO --version" >/tmp/_md_mac 2>&1; then
    echo "maestro(mac): $(tail -1 /tmp/_md_mac)"
  else echo "maestro(mac): недоступно ($(tail -1 /tmp/_md_mac))"; rc=1; fi
  echo "== devices =="
  for id in $(all_ids); do
    # Реестр может явно помечать устройство offline/maintenance (физически не подключено) —
    # это НЕ поломка device-lab: пропускаем, чтобы один отсутствующий телефон не блокировал гейт.
    dst="$(dev_field "$id" status)"
    if [ -n "$dst" ] && [ "$dst" != "available" ]; then
      echo "$id: skip (status=$dst)"
      continue
    fi
    if is_android "$id"; then
      s=$("$ADB" devices 2>/dev/null | awk -v s="$(serial_of "$id")" '$1==s{print $2}')
      [ "$s" = "device" ] && echo "$id: connected" || { echo "$id: $s"; rc=1; }
    else
      n=$(ssh -o BatchMode=yes -o ConnectTimeout=8 "$MAC" "xcrun devicectl list devices 2>/dev/null | grep -c '$(udid_of "$id")'" 2>/dev/null)
      [ "${n:-0}" != "0" ] && echo "$id: connected (via $MAC)" || { echo "$id: offline"; rc=1; }
    fi
  done
  return $rc
}
c_lease() {
  local id="$1"; shift; local ex="" ttl=120
  while [ $# -gt 0 ]; do case "$1" in --exec) ex="$2"; shift 2;; --ttl) ttl="$2"; shift 2;; *) shift;; esac; done
  mkdir -p "$LEASE_DIR"
  if [ -f "$LEASE_DIR/$id" ] && [ -z "$ex" ]; then die "$id уже арендован: $(cat "$LEASE_DIR/$id")"; fi
  echo "exec=${ex:-manual} ttl=${ttl}m at=$(date -Is)" > "$LEASE_DIR/$id"
  echo "leased: $id ($(cat "$LEASE_DIR/$id"))"
}
c_release() {
  local a="${1:-}"; [ "$a" = "--exec" ] && { rm -f "$LEASE_DIR"/*.nonexistent 2>/dev/null; for f in "$LEASE_DIR"/*; do [ -e "$f" ] && grep -q "exec=${2:-}" "$f" && rm -f "$f" && echo "released: $(basename "$f")"; done; return; }
  [ -n "$a" ] || die "release <id|--exec E####>"
  rm -f "$LEASE_DIR/$a" && echo "released: $a"
}
_run_flow() { # _run_flow <id> <flow_on_local> <outdir>
  local id="$1" flow="$2" out="${3:-}"
  # Убить зависший Maestro именно для этого устройства (гонки/gRPC-краши).
  pkill -f "maestro.cli.*--device $(serial_of "$id")" 2>/dev/null || true
  pkill -f "maestro.cli.*--udid $(udid_of "$id")" 2>/dev/null || true
  local outargs=()
  if [ -n "$out" ]; then mkdir -p "$out"; outargs=(--test-output-dir "$out" --debug-output "$out" --flatten-debug-output); fi
  local rc=1 attempt apid=""
  # MIUI/HyperOS: держим watcher на время прогона (Maestro ставит драйвер на каждый запуск).
  if is_android "$id"; then
    apid="$(_approve_start "$(serial_of "$id")")"
    [ -n "$apid" ] && echo "mobile-device: MIUI-approve watcher pid=$apid (serial=$(serial_of "$id"))" >&2
  fi
  for attempt in 1 2; do
    case "$(dev_field "$id" transport)" in
      appium)
        _run_flow_appium "$id" "$flow" "${out:-}"; rc=$? ;;
      devicectl)
        # Физический iOS через штатный Xcode (devicectl): без подписи и без Maestro.
        # Умеем «открыть URL на устройстве + снять скриншот»; тапы/ассерты недоступны
        # (XCUITest-драйверу нужна codesigning-identity, см. доки).
        local u shotname remote="/tmp/mobile-${id}-$$.png"
        u="$(grep -m1 -E 'openLink:' "$flow" | sed -E 's/.*openLink:[[:space:]]*"?//; s/"?[[:space:]]*$//')"
        shotname="$(grep -m1 -E 'takeScreenshot:' "$flow" | sed -E 's/.*takeScreenshot:[[:space:]]*"?//; s/"?[[:space:]]*$//')"
        [ -n "$u" ] || die "devicectl-транспорт умеет только openLink+screenshot: в $flow нет openLink"
        ssh -o BatchMode=yes "$MAC" "xcrun devicectl device process launch --device $(udid_of "$id") --terminate-existing --payload-url '$u' com.apple.mobilesafari >/dev/null 2>&1; sleep ${MOBILE_URL_SETTLE:-10}; xcrun devicectl device capture screenshot --device $(udid_of "$id") --destination $remote" >/dev/null 2>&1 || { rc=1; break; }
        if [ -n "$out" ]; then
          mkdir -p "$out"
          scp -q "$MAC:$remote" "$out/screenshot.png" 2>/dev/null || true
          [ -n "$shotname" ] && [ -f "$out/screenshot.png" ] && cp -f "$out/screenshot.png" "$out/$shotname.png"
        fi
        rc=0 ;;
      adb|local)
        "$ADB" -s "$(serial_of "$id")" wait-for-device >/dev/null 2>&1
        PATH="$(dirname "$ADB"):$(dirname "$MAESTRO"):$PATH" "$MAESTRO" --device "$(serial_of "$id")" test "$flow" "${outargs[@]}"; rc=$? ;;
      simulator|mac)
        local rf="/tmp/$(basename "$flow")" mout="/tmp/maestro-out-$id"
        scp -q "$flow" "$MAC:$rf" || die "scp на $MAC не удался"
        ssh -o BatchMode=yes "$MAC" "export JAVA_HOME=$M_JAVA; export PATH=\$HOME/.maestro/bin:\$PATH; mkdir -p $mout; $M_MAESTRO --udid $(udid_of "$id") test $rf --test-output-dir $mout --debug-output $mout --flatten-debug-output"; rc=$?
        if [ -n "$out" ]; then scp -q -r "$MAC:$mout/." "$out/" 2>/dev/null || true; fi ;;
      *) die "host $(host_of "$id") без транспорта" ;;
    esac
    if [ "$rc" -eq 0 ]; then
      if [ -n "$out" ]; then
        local newest; newest="$(find "$out" -name '*.png' ! -name 'screenshot.png' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2-)"
        [ -n "$newest" ] && cp -f "$newest" "$out/screenshot.png" && echo "mobile-device: screenshot → $out/screenshot.png"
      fi
      _approve_stop "$apid"
      return 0
    fi
    echo "mobile-device: maestro attempt $attempt rc=$rc; повтор" >&2
    pkill -f "maestro.cli.*device $(serial_of "$id")" 2>/dev/null || true
    sleep 3
  done
  _approve_stop "$apid"
  return $rc
}
c_url() { # url <id> <url> [--out DIR]
  local id="$1" url="$2"; shift 2; local out=""
  while [ $# -gt 0 ]; do case "$1" in --out) out="$2"; shift 2;; *) shift;; esac; done
  if is_appium "$id"; then
    local f; f=$(mktemp /tmp/mobile-url-XXXX.yaml)
    printf 'appId: com.apple.mobilesafari\n---\n- openLink: "%s"\n- takeScreenshot: "mobile-%s"\n' "$url" "$id" > "$f"
    _run_flow "$id" "$f" "$out"; local r=$?; rm -f "$f"; return $r
  fi
  if is_devicectl "$id"; then
    local f; f=$(mktemp /tmp/mobile-url-XXXX.yaml)
    printf 'appId: com.apple.mobilesafari\n---\n- openLink: "%s"\n- takeScreenshot: "mobile-%s"\n' "$url" "$id" > "$f"
    _run_flow "$id" "$f" "$out"; local r=$?; rm -f "$f"; return $r
  fi
  local app; app=$(dev_field "$id" browsers | tr -d '[" ]' | cut -d, -f1)
  local flow; flow=$(mktemp /tmp/mobile-flow-XXXX.yaml)
  cat > "$flow" <<EOF
appId: $app
---
- openLink: "$url"
- takeScreenshot: "mobile-${id}"
EOF
  _run_flow "$id" "$flow" "$out"; local rc=$?; rm -f "$flow"; return $rc
}
c_test() { # test <id> <flow.yaml> [--out DIR]
  local id="$1" flow="$2"; shift 2; local out=""
  while [ $# -gt 0 ]; do case "$1" in --out) out="$2"; shift 2;; *) shift;; esac; done
  [ -f "$flow" ] || die "нет флоу $flow"
  _run_flow "$id" "$flow" "$out"
}
c_shot() { # shot <id> <out.png> (только android; ios — через url/test)
  local id="$1" out="$2"
  if ! is_android "$id"; then
    local remote="/tmp/mobile-shot-${id}-$$.png"
    ssh -o BatchMode=yes "$MAC" "xcrun devicectl device capture screenshot --device $(udid_of "$id") --destination $remote" >/dev/null 2>&1 || die "devicectl screenshot failed ($id)"
    mkdir -p "$(dirname "$out")"; scp -q "$MAC:$remote" "$out" && echo "screenshot: $out"; return 0
  fi
  is_android "$id" || die "shot поддерживается для android или devicectl-ios"
  "$ADB" -s "$(serial_of "$id")" exec-out screencap -p > "$out" && echo "screenshot: $out"
}

case "${1:-}" in
  list) c_list ;;
  doctor) c_doctor ;;
  lease) shift; c_lease "$@" ;;
  release) shift; c_release "$@" ;;
  url) shift; c_url "$@" ;;
  test) shift; c_test "$@" ;;
  shot) shift; c_shot "$@" ;;
  *) sed -n '2,15p' "$0"; exit 2 ;;
esac
