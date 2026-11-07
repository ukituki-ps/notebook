#!/usr/bin/env bash
# gate-stand-leased (F188 / ADR-KIT-091) — FAIL-CLOSE, если у исполнения нет
# активной аренды тестового стенда.
#
# Два пути:
#   1) PREFERRED — ORC-signed lease proof (F188 hotfix). ORC проверяет аренду
#      через Nexus server-to-server и кладёт в env ЭТОГО гейта только
#      ORC_STAND_LEASE_PROOF + pinned ORC_LEASE_PROOF_PUBKEY. Скрипт проверяет
#      схему, execution_id, срок и Ed25519-подпись. Raw Nexus token в gate env
#      не попадает. Нет/просрочен/чужая подпись/чужой execution → fail-close.
#   2) LEGACY (local/legacy only) — прямой REST-запрос с NEXUS_TOKEN /
#      ORC_NEXUS_TOKEN, если proof не задан. В production gate env токена нет.
#
# Аргументы: $1 execution_id (или EXECUTION_ID), $2 project_id (опц.).
set -uo pipefail

exec_id="${1:-${EXECUTION_ID:-}}"
proj="${2:-${PROJECT_ID:-}}"
base="${NEXUS_BASE_URL:-http://nexus:9182}"
proof="${ORC_STAND_LEASE_PROOF:-}"
pubkey="${ORC_LEASE_PROOF_PUBKEY:-}"
token="${NEXUS_TOKEN:-${ORC_NEXUS_TOKEN:-}}"

fail() {
  echo "gate-stand-leased: FAIL — $*" >&2
  exit 1
}

if [ -z "$exec_id" ]; then
  fail "execution_id не задан (fail-close, ADR-KIT-091)"
fi

# ── 1. Signed ORC lease proof (preferred) ────────────────────────────────
if [ -n "$proof" ]; then
  if [ -z "$pubkey" ]; then
    fail "ORC_STAND_LEASE_PROOF задан, но ORC_LEASE_PROOF_PUBKEY отсутствует (fail-close)"
  fi
  python3 - "$exec_id" "$proj" "$pubkey" <<'PY' || exit 1
import base64
import datetime as dt
import json
import os
import shutil
import subprocess
import sys
import tempfile

exec_id, project_id, pubkey_b64 = sys.argv[1], sys.argv[2], sys.argv[3]
raw = os.environ.get("ORC_STAND_LEASE_PROOF", "")

FIELDS = ("schema", "lease_id", "stand", "stand_url", "execution_id", "project_id", "issued_at", "expires_at")
SCHEMA = "orc.stand-lease-proof/v1"


def die(msg):
    print(f"gate-stand-leased: FAIL — {msg} (fail-close)", file=sys.stderr)
    sys.exit(1)


try:
    data = json.loads(raw)
except Exception as exc:  # noqa: BLE001
    die(f"lease proof не является JSON: {exc}")

if not isinstance(data, dict):
    die("lease proof должен быть JSON-объектом")
if data.get("schema") != SCHEMA:
    die(f"неподдерживаемая схема proof: {data.get('schema')!r}")
for key in FIELDS:
    if not isinstance(data.get(key), str) or not data.get(key):
        die(f"поле proof {key} отсутствует/пустое")
if data["execution_id"] != exec_id:
    die(f"proof выдан для execution {data['execution_id']}, а не {exec_id}")
if project_id and data["project_id"] != project_id:
    die(f"proof выдан для project {data['project_id']}, а не {project_id}")


def parse_ts(value, field):
    try:
        ts = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except Exception as exc:  # noqa: BLE001
        die(f"поле proof {field} не является RFC3339: {exc}")
    if ts.tzinfo is None:
        ts = ts.replace(tzinfo=dt.timezone.utc)
    return ts.astimezone(dt.timezone.utc)


issued = parse_ts(data["issued_at"], "issued_at")
expires = parse_ts(data["expires_at"], "expires_at")
now = dt.datetime.now(dt.timezone.utc)
if expires <= now:
    die(f"lease proof истёк в {data['expires_at']} (now {now.isoformat()})")
if issued >= expires:
    die("lease proof issued_at >= expires_at")

try:
    pub = base64.b64decode(pubkey_b64, validate=True)
except Exception as exc:  # noqa: BLE001
    die(f"ORC_LEASE_PROOF_PUBKEY не base64: {exc}")
if len(pub) != 32:
    die(f"ORC_LEASE_PROOF_PUBKEY: ожидалось 32 байта, получено {len(pub)}")

try:
    sig = base64.b64decode(data.get("signature", ""), validate=True)
except Exception as exc:  # noqa: BLE001
    die(f"signature не base64: {exc}")
if len(sig) != 64:
    die(f"signature: ожидалось 64 байта, получено {len(sig)}")

# Canonical JSON: тот же порядок полей и separators, что в
# orc/acceptance/stand_lease_proof.go (signature исключён).
canonical = json.dumps(
    {k: data[k] for k in FIELDS},
    separators=(",", ":"),
    ensure_ascii=False,
).encode("utf-8")

tmp = tempfile.mkdtemp(prefix="orc-lease-proof-")
try:
    msg_path = os.path.join(tmp, "msg.bin")
    sig_path = os.path.join(tmp, "sig.bin")
    pem_path = os.path.join(tmp, "pub.pem")
    with open(msg_path, "wb") as fh:
        fh.write(canonical)
    with open(sig_path, "wb") as fh:
        fh.write(sig)
    # Ed25519 SubjectPublicKeyInfo prefix 302a300506032b6570032100.
    der = bytes.fromhex("302a300506032b6570032100") + pub
    body = base64.encodebytes(der).decode("ascii")
    with open(pem_path, "w", encoding="ascii") as fh:
        fh.write("-----BEGIN PUBLIC KEY-----\n")
        fh.write(body)
        fh.write("-----END PUBLIC KEY-----\n")
    try:
        proc = subprocess.run(
            ["openssl", "pkeyutl", "-verify", "-pubin", "-inkey", pem_path,
             "-rawin", "-in", msg_path, "-sigfile", sig_path],
            capture_output=True,
            text=True,
        )
    except Exception as exc:  # noqa: BLE001
        die(f"openssl недоступен: {exc}")
    if proc.returncode != 0:
        die(f"неверная Ed25519-подпись lease proof: {(proc.stderr or proc.stdout).strip()}")
finally:
    shutil.rmtree(tmp, ignore_errors=True)

print(f"gate-stand-leased: OK — signed lease proof (execution={exec_id}, lease={data['lease_id']}, stand={data['stand']})")
PY
  exit $?
fi

# ── 2. Legacy REST fallback (local/legacy only; no token in gate env) ────
if [ -z "$token" ]; then
  fail "нет ORC_STAND_LEASE_PROOF и нет NEXUS_TOKEN/ORC_NEXUS_TOKEN (fail-close)"
fi

url="${base}/api/v1/stands/leases?execution_id=${exec_id}"
[ -n "$proj" ] && url="${url}&project_id=${proj}"

resp="$(curl -fsS -m 10 -H "Authorization: Bearer ${token}" "$url" 2>/dev/null)" || {
  fail "Nexus недоступен (${base})"
}

active="$(printf '%s' "$resp" | python3 -c 'import sys,json;print("1" if json.load(sys.stdin).get("active") else "0")' 2>/dev/null)"
if [ "$active" = "1" ]; then
  echo "gate-stand-leased: OK — аренда активна (execution=${exec_id})"
  exit 0
fi

fail "у исполнения ${exec_id} нет активной аренды стенда. → Сначала: stand_lease(project_id, stand, execution_id) (ADR-KIT-091)."
