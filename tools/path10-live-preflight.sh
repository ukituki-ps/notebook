#!/usr/bin/env bash
# path10-live-preflight — готовность live-контура к unattended path-10.
#
# Проверяет (fail-close):
#   1) Nexus /healthz.commit == base_sha (D2: образ не старее базы);
#   2) ORC /version.revision == Nexus commit (lockstep платформы);
#   3) свободное место на диске >= MIN_DISK_GB;
#   4) healthz арендованного стенда (если передан STAND_URL/EXECUTION_ID).
#
# Использование:
#   bash tools/path10-live-preflight.sh [base_sha]
# ENV:
#   NEXUS_URL (default https://nexus.ukituki.tech)
#   ORC_URL   (default http://192.168.1.20:8290)
#   MIN_DISK_GB (default 20), DISK_PATH (default /)
#   STAND_URL (опц.) — проверить healthz стенда
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DIR/.." && pwd)"
base="${1:-${BASE_SHA:-}}"
[ -n "$base" ] || base="$(git -C "$ROOT" rev-parse origin/main 2>/dev/null || git -C "$ROOT" rev-parse HEAD)"
nexus="${NEXUS_URL:-https://nexus.ukituki.tech}"
orc="${ORC_URL:-http://192.168.1.20:8290}"
min_gb="${MIN_DISK_GB:-20}"
disk_path="${DISK_PATH:-/}"
fail=0
ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; }
bad()  { printf '  \033[31m✗\033[0m %s\n' "$1"; fail=$((fail+1)); }
warn() { printf '  \033[33m!\033[0m %s\n' "$1"; }

echo "path10-live-preflight: base=$base nexus=$nexus orc=$orc"

# 1) Nexus commit
njson="$(curl -fsS -m 10 "$nexus/healthz" 2>/dev/null || true)"
ncommit="$(printf '%s' "$njson" | python3 -c 'import json,sys
try: print((json.load(sys.stdin) or {}).get("commit","") or "")
except Exception: print("")' 2>/dev/null || true)"
if [ -z "$ncommit" ]; then
  bad "Nexus /healthz недоступен или без commit"
elif [ "$ncommit" = "$base" ]; then
  ok "Nexus commit == base_sha ($ncommit)"
elif [[ "$base" == "$ncommit"* || "$ncommit" == "$base"* ]]; then
  ok "Nexus commit согласован с base_sha ($ncommit ~ $base)"
else
  bad "Nexus commit=$ncommit, base_sha=$base — образ старее/новее базы (D2)"
fi

# 2) ORC revision == Nexus commit (lockstep)
ov="$(curl -fsS -m 10 "$orc/version" 2>/dev/null || true)"
ocommit="$(printf '%s' "$ov" | sed -n 's/^revision=//p' | head -1 | tr -d '\r\n ' || true)"
if [ -z "$ocommit" ]; then
  bad "ORC /version недоступен или без revision"
elif [ -n "$ncommit" ] && [ "$ocommit" != "$ncommit" ]; then
  bad "ORC revision=$ocommit != Nexus commit=$ncommit (расхождение образов)"
else
  ok "ORC revision == Nexus commit ($ocommit)"
fi

# 3) disk
free_gb="$(python3 - "$disk_path" <<'PY'
import os, sys
p = sys.argv[1]
st = os.statvfs(p)
print(int(st.f_bavail * st.f_frsize / (1024**3)))
PY
)"
if [ "${free_gb:-0}" -lt "$min_gb" ]; then
  bad "free disk $disk_path = ${free_gb} GB < ${min_gb} GB (disk_insufficient)"
else
  ok "free disk $disk_path = ${free_gb} GB (>= ${min_gb})"
fi

# 4) stand health (optional)
if [ -n "${STAND_URL:-}" ]; then
  code="$(curl -k -o /dev/null -s -m 8 -w '%{http_code}' "${STAND_URL%/}/healthz" 2>/dev/null || true)"
  if [ "$code" = "200" ]; then ok "stand healthz 200 ($STAND_URL)"; else bad "stand healthz=$code ($STAND_URL) — stand_unavailable"; fi
else
  warn "STAND_URL не задан — health стенда не проверен (проверит runner precondition)"
fi

if [ "$fail" -eq 0 ]; then
  echo "path10-live-preflight: PASS"
  exit 0
fi
echo "path10-live-preflight: FAIL ($fail)" >&2
exit 1
