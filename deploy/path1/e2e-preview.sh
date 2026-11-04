#!/usr/bin/env bash
# e2e-preview.sh — API smoke для backend-only notebook на арендованном стенде.
# Стенд/URL приходят из platform-скрипта run-stand-e2e.sh (env E2E_BASE_URL).
set -euo pipefail
base="${E2E_BASE_URL:-${PREVIEW_BASE_URL:-}}"
[ -n "$base" ] || { echo "e2e-preview: E2E_BASE_URL не задан" >&2; exit 2; }
base="${base%/}"

echo "e2e-preview: target=$base"
hz="$(curl -fsS -m 10 "$base/healthz")"
python3 - "$hz" <<'PY'
import json, sys, re
try:
    d = json.loads(sys.argv[1])
except Exception:
    sys.exit("e2e-preview: /healthz не JSON")
br = str(d.get("build_ref") or "")
cm = str(d.get("commit") or "")
if not br:
    sys.exit("e2e-preview: /healthz без build_ref")
if not re.fullmatch(r"[0-9a-f]{40}", cm or ""):
    sys.exit(f"e2e-preview: /healthz.commit={cm!r} не 40hex")
print(f"e2e-preview: health build_ref={br} commit={cm}")
PY

curl -fsS -m 10 "$base/api/notes" >/dev/null
curl -fsS -m 10 -X POST -H 'Content-Type: application/json' \
  -d '{"text":"e2e smoke"}' "$base/api/notes" >/dev/null
notes="$(curl -fsS -m 10 "$base/api/notes")"
printf '%s' "$notes" | grep -q 'e2e smoke' || { echo "e2e-preview: POST note не виден в GET" >&2; exit 1; }
echo "e2e-preview: OK (health + GET/POST /api/notes)"
