#!/usr/bin/env bash
# Host-run evidence signing (R-S22B-02). Private key stays outside the repo.
# Usage: sign-host-evidence.sh <evidence.json> [key]
set -euo pipefail
ev="${1:?evidence.json}"; key="${2:-$HOME/.orc-evidence/ed25519}"
canon="$(mktemp)"; trap 'rm -f "$canon"' EXIT
python3 - "$ev" > "$canon" <<'PY'
import json,sys
ev=json.load(open(sys.argv[1]))
sys.stdout.write(json.dumps({"code_commit":ev["code_commit"],"log_sha256":ev["log_sha256"],"failed":sorted(ev.get("failed",[]))},sort_keys=True,separators=(",",":")))
PY
sig="${ev}.sig"
ssh-keygen -Y sign -q -f "$key" -n orc-evidence - < "$canon" > "$sig"
python3 - "$ev" "$sig" <<'PY'
import json,sys
p=sys.argv[1]; ev=json.load(open(p)); ev["signature_path"]=sys.argv[2]
json.dump(ev,open(p,'w'),ensure_ascii=False,indent=2)
PY
echo "signed: $sig"
