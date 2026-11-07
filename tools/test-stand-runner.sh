#!/usr/bin/env bash
# test-stand-runner.sh — no-root tests for the s20b/s20c host runner.
#
# Покрывает контракт path-10:
#   * request: transport git|worktree, commit 40-hex (git), отсутствие commit
#     для worktree, отклонение неизвестных полей;
#   * path resolution: .orc-eval/<E>/<commit> и .orc-worktrees/<E>, symlink
#     escape, project_id, fail-closed;
#   * runner code root vs app worktree: манифест проверяется в CODE_ROOT,
#     app worktree без tools/ не ломает выкат;
#   * execution root: preview-deploy.json для .orc-eval пишется в <E>/, не в
#     commit-subdir;
#   * e2e-preview (API-only e2e.command);
#   * клиент, мост deploy-preview-stand/e2e, rate-limit, audit, systemd.
#
# Запуск: bash tools/test-stand-runner.sh
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/stand-runner-test.XXXXXX")"
PASS=0
FAIL=0
NEXUS_PID=""
DAEMON_PID=""

cleanup() {
  [ -n "$DAEMON_PID" ] && kill "$DAEMON_PID" 2>/dev/null
  [ -n "$NEXUS_PID" ] && kill "$NEXUS_PID" 2>/dev/null
  wait 2>/dev/null
  rm -rf -- "$TMP"
}
trap cleanup EXIT

ok() { PASS=$((PASS + 1)); printf 'PASS  %s\n' "$1"; }
no() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; }

expect_eq() { # <name> <actual> <expected>
  if [ "$2" = "$3" ]; then ok "$1"; else no "$1 (expected [$3], got [$2])"; fi
}
expect_ne() { # <name> <actual> <unexpected>
  if [ "$2" != "$3" ]; then ok "$1"; else no "$1 (must not equal [$3])"; fi
}
expect_contains() { # <name> <haystack> <needle>
  case "$2" in
    *"$3"*) ok "$1" ;;
    *) no "$1 (missing [$3] in [$2])" ;;
  esac
}
expect_not_contains() { # <name> <haystack> <needle>
  case "$2" in
    *"$3"*) no "$1 (unexpected [$3] in [$2])" ;;
    *) ok "$1" ;;
  esac
}
expect_file() { # <name> <path>
  if [ -f "$2" ]; then ok "$1"; else no "$1 (missing file $2)"; fi
}
expect_nofile() { # <name> <path>
  if [ ! -e "$2" ]; then ok "$1"; else no "$1 (unexpected $2)"; fi
}

jget() { # <file> <key>
  python3 -c 'import json,sys
try:
    print(json.load(open(sys.argv[1], encoding="utf-8")).get(sys.argv[2], ""))
except Exception:
    print("")' "$1" "$2"
}

git_commit() { # <dir> <msg>
  git -C "$1" add -A >/dev/null 2>&1
  git -C "$1" -c user.email=t@t -c user.name=t commit -q -m "$2" >/dev/null 2>&1
  git -C "$1" rev-parse HEAD
}

# ─── sandbox ────────────────────────────────────────────────────────────────
PROJ1="11111111-1111-4111-8111-111111111111"
PROJ2="22222222-2222-4222-8222-222222222222"
GATE="sha256:$(printf 'c%.0s' $(seq 1 64))"
export NEXUS_GATE_BUNDLE_DIGEST="$GATE"

QUEUE="$TMP/queue"
REPOS="$TMP/repos"
CODE="$TMP/code"
RUNNER_DIR="$TMP/runner"
TOKEN_FILE="$TMP/runner.token"
MANIFEST="$RUNNER_DIR/manifest.sha256"
AUDIT="$RUNNER_DIR/audit.log"
RUNNER_HOME="$TMP/home"
STATE="$TMP/nexus-state.json"
mkdir -p "$QUEUE" "$REPOS" "$CODE/tools" "$CODE/deploy/stands/ci" "$RUNNER_DIR" "$RUNNER_HOME"
printf 'test-token\n' > "$TOKEN_FILE"
printf '{}\n' > "$STATE"

# ─── immutable runner code root (platform tools) ─────────────────────────────
cp "$DIR/stand-runner-client.sh" "$CODE/tools/stand-runner-client.sh"
cp "$DIR/_path1_project.py" "$CODE/tools/_path1_project.py"
cat > "$CODE/tools/deploy-preview-stand.sh" <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
echo "fake deploy: exec=${1:-} runner=${STAND_RUNNER_EXECUTE:-unset} nexus=${NEXUS_BASE_URL:-unset} token=${NEXUS_TOKEN:-unset} leak=${LEAK:-unset}"
echo "fake deploy: target=${ORC_TARGET_ROOT:-unset} exec_root=${ORC_EXECUTION_ROOT:-unset} transport=${ORC_EXECUTION_TRANSPORT:-unset} commit=${ORC_EVALUATED_SHA:-unset} gate=${NEXUS_GATE_BUNDLE_DIGEST:-unset} feature=${ORC_FEATURE_DIR:-unset} fid=${FEATURE_ID:-unset}"
[ -d "${ORC_TARGET_ROOT:?}" ] || exit 3
[ ! -e "${ORC_TARGET_ROOT}/tools" ] || echo "fake deploy: WARN app worktree has tools/"
printf '{"execution_id":"%s","stand":"test1","platform_tools":"runner-root"}\n' "${1:-}" > "${ORC_EXECUTION_ROOT:?}/preview-deploy.json"
EOS
chmod +x "$CODE/tools/deploy-preview-stand.sh"
cat > "$CODE/tools/run-stand-e2e.sh" <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
echo "fake e2e: exec=${1:-} target=${ORC_TARGET_ROOT:-unset} exec_root=${ORC_EXECUTION_ROOT:-unset} command=${E2E_FAKE:-unset}"
printf '{"execution_id":"%s","result":"pass"}\n' "${1:-}" > "${ORC_EXECUTION_ROOT:?}/e2e-report.json"
EOS
chmod +x "$CODE/tools/run-stand-e2e.sh"
cat > "$CODE/deploy/stands/ci/deploy-stand.sh" <<'EOS'
#!/usr/bin/env bash
echo "fake stand deploy $*"
EOS
chmod +x "$CODE/deploy/stands/ci/deploy-stand.sh"

manifest_for_code() {
  ( cd "$CODE" && find tools/deploy-preview-stand.sh tools/stand-runner-client.sh \
      tools/_path1_project.py tools/run-stand-e2e.sh deploy -type f -print0 \
      | sort -z | xargs -0 sha256sum ) > "$MANIFEST"
}
manifest_for_code

# ─── app worktree (НЕ содержит platform tools) ──────────────────────────────
make_worktree() { # <E> <project> → realpath; git HEAD
  local eid="$1" pid="$2"
  local wt="$REPOS/$pid/.orc-worktrees/$1"
  mkdir -p "$wt/deploy/stands/ci"
  printf '{"deploy":{"stand_command":"bash deploy/stands/ci/deploy-stand.sh {stand}"}}\n' > "$wt/path1.project.json"
  printf '{}\n' > "$wt/path1.ui.json"
  cat > "$wt/deploy/stands/ci/deploy-stand.sh" <<'EOS'
#!/usr/bin/env bash
echo "fake app stand deploy $*"
EOS
  chmod +x "$wt/deploy/stands/ci/deploy-stand.sh"
  git init -q "$wt"
  git_commit "$wt" "app $eid" >/dev/null
}

# make_eval_worktree <E> <project> [base_commit] → prints full sha; path = .orc-eval/<E>/<sha>
make_eval_worktree() {
  local eid="$1" pid="$2"
  local parent="$REPOS/$pid/.orc-eval/$eid"
  local tmp="$parent/.new.$$"
  mkdir -p "$parent"
  git init -q "$tmp"
  printf '{"deploy":{"stand_command":"bash deploy/stands/ci/deploy-stand.sh {stand}"}}\n' > "$tmp/path1.project.json"
  printf '{}\n' > "$tmp/path1.ui.json"
  mkdir -p "$tmp/deploy/stands/ci"
  cat > "$tmp/deploy/stands/ci/deploy-stand.sh" <<'EOS'
#!/usr/bin/env bash
echo "fake app stand deploy $*"
EOS
  chmod +x "$tmp/deploy/stands/ci/deploy-stand.sh"
  local sha
  sha="$(git_commit "$tmp" "eval $eid")"
  mv "$tmp" "$parent/$sha"
  printf '%s' "$sha"
}

# ─── fake Nexus ─────────────────────────────────────────────────────────────
cat > "$TMP/fake_nexus.py" <<'PY'
import json
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

PORT = int(sys.argv[1])
STATE = sys.argv[2]


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def send_json(self, code, obj):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.headers.get("Authorization") != "Bearer test-token":
            self.send_json(401, {"error": "unauthorized"})
            return
        try:
            with open(STATE, encoding="utf-8") as fh:
                state = json.load(fh)
        except Exception:
            state = {}
        url = urlparse(self.path)
        if url.path == "/api/v1/stands/leases":
            eid = (parse_qs(url.query).get("execution_id") or [""])[0]
            ent = state.get(eid) or {}
            lease = ent.get("lease")
            if lease:
                self.send_json(200, {"active": True, "lease": lease})
            else:
                self.send_json(200, {"active": False, "lease": None})
            return
        if url.path.startswith("/api/v1/executions/"):
            eid = url.path.rsplit("/", 1)[-1]
            ent = state.get(eid)
            if ent is None:
                self.send_json(404, {"error": "not found"})
                return
            if ent.get("executions_http"):
                self.send_json(int(ent["executions_http"]), {"error": "unavailable"})
                return
            self.send_json(200, {"execution_id": eid, "status": ent.get("execution", "")})
            return
        self.send_json(404, {"error": "not found"})


ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
PY

PORT="$(python3 - <<'PY'
import socket
s = socket.socket()
s.bind(("127.0.0.1", 0))
print(s.getsockname()[1])
s.close()
PY
)"
python3 "$TMP/fake_nexus.py" "$PORT" "$STATE" >"$TMP/nexus.log" 2>&1 &
NEXUS_PID=$!
NEXUS_URL="http://127.0.0.1:$PORT"
for _ in $(seq 1 50); do
  curl -s -o /dev/null -m 1 "$NEXUS_URL/api/v1/stands" && break
  sleep 0.1
done

set_state() { # <eid> <execution-status> <stand_name|-> <project_id>
  python3 - "$STATE" "$1" "$2" "$3" "$4" <<'PY'
import json
import sys

path, eid, status, stand, pid = sys.argv[1:6]
try:
    with open(path, encoding="utf-8") as fh:
        data = json.load(fh)
except Exception:
    data = {}
lease = None
if stand != "-":
    lease = {"stand_name": stand, "project_id": pid, "stand_url": "http://127.0.0.1:9/"}
data[eid] = {"execution": status, "lease": lease}
with open(path, "w", encoding="utf-8") as fh:
    json.dump(data, fh)
PY
}

set_state_http() { # <eid> <http-code>
  python3 - "$STATE" "$1" "$2" <<'PY'
import json
import sys

path, eid, code = sys.argv[1:4]
try:
    with open(path, encoding="utf-8") as fh:
        data = json.load(fh)
except Exception:
    data = {}
data[eid] = {"execution": "running", "executions_http": int(code),
             "lease": {"stand_name": "test1", "project_id": "11111111-1111-4111-8111-111111111111",
                       "stand_url": "http://127.0.0.1:9/"}}
with open(path, "w", encoding="utf-8") as fh:
    json.dump(data, fh)
PY
}

# enqueue <eid> <project> <transport> [commit] [command]
enqueue() {
  local eid="$1" pid="$2" transport="$3" commit="${4:-}" command="${5:-deploy-preview}"
  local d="$QUEUE/$eid"
  mkdir -p -m 700 -- "$d"
  if [ "$transport" = "git" ]; then
    printf '{"execution_id":"%s","project_id":"%s","command":"%s","transport":"git","commit":"%s","gate_bundle_digest":"%s","ts":"%s"}\n' \
      "$eid" "$pid" "$command" "$commit" "$GATE" "$(date -u +%FT%TZ)" > "$d/req.json"
  else
    printf '{"execution_id":"%s","project_id":"%s","command":"%s","transport":"worktree","gate_bundle_digest":"%s","ts":"%s"}\n' \
      "$eid" "$pid" "$command" "$GATE" "$(date -u +%FT%TZ)" > "$d/req.json"
  fi
  chmod 600 -- "$d/req.json"
}

run_once() {
  env \
    STAND_RUNNER_REPOS_ROOT="$REPOS" \
    STAND_RUNNER_QUEUE="$QUEUE" \
    STAND_RUNNER_CODE_ROOT="$CODE" \
    STAND_RUNNER_NEXUS_URL="$NEXUS_URL" \
    STAND_RUNNER_NEXUS_TOKEN_FILE="$TOKEN_FILE" \
    STAND_RUNNER_MANIFEST="$MANIFEST" \
    STAND_RUNNER_AUDIT_LOG="$AUDIT" \
    STAND_RUNNER_HOME="$RUNNER_HOME" \
    STAND_RUNNER_RUN_TIMEOUT=60 \
    LEAK=secret \
    "$DIR/stand-runner.sh" --once "$QUEUE" >"$TMP/runner.out" 2>&1
  RC=$?
}

run_client() { # <eid> [VAR=VAL ...]
  local eid="$1"
  shift
  OUT="$(env STAND_RUNNER_QUEUE="$QUEUE" STAND_RUNNER_TIMEOUT=30 "$@" \
    "$DIR/stand-runner-client.sh" "$eid" 2>&1)"
  RC=$?
}

assert_reject() { # <eid> <reason-substring>
  local eid="$1" needle="$2" rc reason status audit
  rc="$(jget "$QUEUE/$eid/res.json" rc)"
  status="$(jget "$QUEUE/$eid/status.json" reason)"
  if [ -n "$rc" ] && [ "$rc" != "0" ]; then
    ok "reject $eid: res.json rc=$rc"
  else
    no "reject $eid: res.json rc=[$rc]"
  fi
  expect_contains "reject $eid: reason" "$status" "$needle"
  audit="$(cat "$AUDIT" 2>/dev/null || true)"
  expect_contains "reject $eid: audit" "$audit" "\"execution_id\":\"$eid\""
}

# ─── 0. syntax ──────────────────────────────────────────────────────────────
for f in deploy-preview-stand.sh stand-runner-client.sh stand-runner.sh run-stand-e2e.sh test-stand-runner.sh; do
  if bash -n "$DIR/$f" 2>"$TMP/bashn.err"; then
    ok "bash -n tools/$f"
  else
    no "bash -n tools/$f: $(cat "$TMP/bashn.err")"
  fi
done

# ─── 1. client: no-op without queue ────────────────────────────────────────
if [ -d /app/orc-repos/.deploy-queue ]; then
  ok "client no-op without queue (skipped: /app queue present)"
else
  mkdir -p "$TMP/empty-home"
  OUT="$(env -u STAND_RUNNER_QUEUE -u STAND_RUNNER_PROJECT_ID HOME="$TMP/empty-home" \
    ORC_PROJECT_ID="$PROJ1" STAND_RUNNER_TRANSPORT=worktree "$DIR/stand-runner-client.sh" E9001 2>&1)"
  RC=$?
  expect_eq "client no-op without queue: rc" "$RC" "0"
  if [ ! -e "$TMP/empty-home/orc-repos" ]; then
    ok "client no-op without queue: no dirs created"
  else
    no "client no-op without queue: created orc-repos"
  fi
fi

# ─── 2. client: argument/env validation ────────────────────────────────────
env -u STAND_RUNNER_PROJECT_ID -u ORC_PROJECT_ID "$DIR/stand-runner-client.sh" E1 >/dev/null 2>&1
RC=$?
expect_eq "client: missing project_id -> rc 2" "$RC" "2"

env STAND_RUNNER_PROJECT_ID="$PROJ1" "$DIR/stand-runner-client.sh" 'E1;rm' >/dev/null 2>&1
RC=$?
expect_eq "client: invalid execution_id -> rc 2" "$RC" "2"

env STAND_RUNNER_PROJECT_ID="$PROJ1" STAND_RUNNER_TRANSPORT=git STAND_RUNNER_QUEUE="$TMP/q-bad" \
  "$DIR/stand-runner-client.sh" E1 >/dev/null 2>&1
RC=$?
expect_eq "client: git without commit -> rc 2" "$RC" "2"

env -u STAND_RUNNER_TRANSPORT -u ORC_EXECUTION_TRANSPORT STAND_RUNNER_PROJECT_ID="$PROJ1" \
  "$DIR/stand-runner-client.sh" E1 >/dev/null 2>&1
RC=$?
expect_eq "client: no transport is fail-close (no silent worktree)" "$RC" "2"

env -u NEXUS_GATE_BUNDLE_DIGEST -u ORC_GATE_BUNDLE_DIGEST -u ORC_GATE_TOOLS_DIGEST \
  -u PREVIEW_GATE_BUNDLE_DIGEST STAND_RUNNER_PROJECT_ID="$PROJ1" STAND_RUNNER_TRANSPORT=worktree \
  "$DIR/stand-runner-client.sh" E1 >/dev/null 2>&1
RC=$?
expect_eq "client: missing gate digest is fail-close" "$RC" "2"

# ─── 3. client: request contract ───────────────────────────────────────────
Q2="$TMP/queue2"
OUT="$(env STAND_RUNNER_QUEUE="$Q2" STAND_RUNNER_PROJECT_ID="$PROJ1" \
  STAND_RUNNER_TIMEOUT=2 STAND_RUNNER_EXECUTE=1 STAND_RUNNER_TRANSPORT=worktree \
  "$DIR/stand-runner-client.sh" E9100 2>&1)"
RC=$?
expect_eq "client ignores STAND_RUNNER_EXECUTE: timeout rc" "$RC" "124"
keys="$(python3 -c 'import json,sys;print(",".join(sorted(json.load(open(sys.argv[1])).keys())))' "$Q2/E9100/req.json" 2>/dev/null || true)"
expect_eq "client req.json worktree: strict fields" "$keys" "command,execution_id,feature_dir,feature_id,gate_bundle_digest,project_id,transport,ts"
expect_eq "client req.json worktree: transport" "$(jget "$Q2/E9100/req.json" transport)" "worktree"
mode="$(stat -c %a "$Q2/E9100" 2>/dev/null || true)"
expect_eq "client queue dir mode" "$mode" "700"

SHA1="$(printf 'a%.0s' $(seq 1 40))"
OUT="$(env STAND_RUNNER_QUEUE="$Q2" STAND_RUNNER_PROJECT_ID="$PROJ1" \
  STAND_RUNNER_TIMEOUT=2 STAND_RUNNER_TRANSPORT=git STAND_RUNNER_COMMIT="$SHA1" \
  ORC_FEATURE_DIR="doc/идеи/F1" FEATURE_ID="F1" \
  "$DIR/stand-runner-client.sh" E9101 2>&1)"
RC=$?
keys="$(python3 -c 'import json,sys;print(",".join(sorted(json.load(open(sys.argv[1])).keys())))' "$Q2/E9101/req.json" 2>/dev/null || true)"
expect_eq "client req.json git: strict fields" "$keys" "command,commit,execution_id,feature_dir,feature_id,gate_bundle_digest,project_id,transport,ts"
expect_eq "client req.json git: commit" "$(jget "$Q2/E9101/req.json" commit)" "$SHA1"
expect_eq "client req.json git: gate" "$(jget "$Q2/E9101/req.json" gate_bundle_digest)" "$GATE"
expect_eq "client req.json git: feature_dir" "$(jget "$Q2/E9101/req.json" feature_dir)" "doc/идеи/F1"
expect_eq "client req.json git: feature_id" "$(jget "$Q2/E9101/req.json" feature_id)" "F1"

# ─── 4. runner: rejects ─────────────────────────────────────────────────────
# 4.1 extra/unknown field
enqueue E2005 "$PROJ1" worktree
python3 - "$QUEUE/E2005/req.json" "$PROJ1" <<'PY'
import json
import sys
path, pid = sys.argv[1:3]
with open(path, "w", encoding="utf-8") as fh:
    json.dump({"execution_id": "E2005", "project_id": pid, "command": "deploy-preview",
               "transport": "worktree", "ts": "2026-01-01T00:00:00Z", "cmd": "rm -rf /"}, fh)
PY
run_once
assert_reject E2005 "request-fields-invalid"

# 4.2 git without commit
enqueue E2011 "$PROJ1" worktree
python3 - "$QUEUE/E2011/req.json" "$PROJ1" <<'PY'
import json
import sys
path, pid = sys.argv[1:3]
with open(path, "w", encoding="utf-8") as fh:
    json.dump({"execution_id": "E2011", "project_id": pid, "command": "deploy-preview",
               "transport": "git", "ts": "2026-01-01T00:00:00Z"}, fh)
PY
run_once
assert_reject E2011 "request-fields-invalid"

# 4.3 worktree carrying commit
enqueue E2012 "$PROJ1" worktree
python3 - "$QUEUE/E2012/req.json" "$PROJ1" <<'PY'
import json
import sys
path, pid = sys.argv[1:3]
with open(path, "w", encoding="utf-8") as fh:
    json.dump({"execution_id": "E2012", "project_id": pid, "command": "deploy-preview",
               "transport": "worktree", "commit": "a"*40, "ts": "2026-01-01T00:00:00Z"}, fh)
PY
run_once
assert_reject E2012 "request-fields-invalid"

# 4.4 invalid commit (not 40hex)
enqueue E2013 "$PROJ1" worktree
python3 - "$QUEUE/E2013/req.json" "$PROJ1" <<'PY'
import json
import sys
path, pid = sys.argv[1:3]
with open(path, "w", encoding="utf-8") as fh:
    json.dump({"execution_id": "E2013", "project_id": pid, "command": "deploy-preview",
               "transport": "git", "commit": "deadbee", "ts": "2026-01-01T00:00:00Z"}, fh)
PY
run_once
assert_reject E2013 "request-fields-invalid"

# 4.4b gate digest missing from a hand-written request
enqueue E2016 "$PROJ1" worktree
python3 -c 'import json,sys; p=sys.argv[1]; d=json.load(open(p)); d.pop("gate_bundle_digest", None); json.dump(d, open(p,"w"))' "$QUEUE/E2016/req.json"
run_once
assert_reject E2016 "request-fields-invalid"

# 4.5 worktree symlink escape
outside="$TMP/outside"
mkdir -p "$outside" "$REPOS/$PROJ1/.orc-worktrees"
ln -sfn "$outside" "$REPOS/$PROJ1/.orc-worktrees/E2004"
set_state E2004 running test1 "$PROJ1"
enqueue E2004 "$PROJ1" worktree
run_once
assert_reject E2004 "worktree-path-mismatch"

# 4.6 eval symlink escape (git)
SHA_E="$REPOS/$PROJ1/.orc-eval/E2014/$SHA1"
mkdir -p "$(dirname "$SHA_E")"
ln -sfn "$outside" "$SHA_E"
set_state E2014 running test1 "$PROJ1"
enqueue E2014 "$PROJ1" git "$SHA1"
run_once
assert_reject E2014 "eval-worktree-missing"

# 4.7 git commit not materialized
set_state E2015 running test1 "$PROJ1"
enqueue E2015 "$PROJ1" git "$SHA1"
run_once
assert_reject E2015 "eval-worktree-missing"

# 4.8 execution not running
make_worktree E2002 "$PROJ1"
set_state E2002 paused test1 "$PROJ1"
enqueue E2002 "$PROJ1" worktree
run_once
assert_reject E2002 "execution-not-running"

# 4.9 lease project mismatch
make_worktree E2003 "$PROJ1"
set_state E2003 running test1 "$PROJ2"
enqueue E2003 "$PROJ1" worktree
run_once
assert_reject E2003 "lease-project-mismatch"

# 4.10 stand not from allowlist
make_worktree E2009 "$PROJ1"
set_state E2009 running prod "$PROJ1"
enqueue E2009 "$PROJ1" worktree
run_once
assert_reject E2009 "lease-stand-not-allowed"

# 4.11 Nexus executions endpoint unavailable → fail-closed
make_worktree E2008 "$PROJ1"
set_state_http E2008 503
enqueue E2008 "$PROJ1" worktree
run_once
assert_reject E2008 "nexus-executions-unavailable"

# 4.12 hash-pin mismatch in RUNNER CODE ROOT (not app worktree)
make_worktree E2006 "$PROJ1"
set_state E2006 running test1 "$PROJ1"
enqueue E2006 "$PROJ1" worktree
printf '\necho tampered\n' >> "$CODE/tools/deploy-preview-stand.sh"
run_once
assert_reject E2006 "hash-pin"
manifest_for_code
expect_eq "manifest restored: deploy tool sha" "$(sha256sum "$CODE/tools/deploy-preview-stand.sh" | awk '{print $1}')" \
  "$(grep 'tools/deploy-preview-stand.sh$' "$MANIFEST" | awk '{print $1}')"

# ─── 5. runner: worktree happy path (app without tools) ────────────────────
make_worktree E2001 "$PROJ1"
expect_nofile "happy: app worktree has no tools/" "$REPOS/$PROJ1/.orc-worktrees/E2001/tools"
set_state E2001 running test1 "$PROJ1"
enqueue E2001 "$PROJ1" worktree
run_once
expect_eq "happy: runner rc" "$RC" "0"
expect_eq "happy: res.json rc" "$(jget "$QUEUE/E2001/res.json" rc)" "0"
expect_eq "happy: status state" "$(jget "$QUEUE/E2001/status.json" state)" "done"
log="$(cat "$QUEUE/E2001/run.log" 2>/dev/null || true)"
expect_contains "happy: run.log deploy output" "$log" "fake deploy: exec=E2001"
expect_contains "happy: runner mode env" "$log" "runner=1"
expect_contains "happy: nexus env" "$log" "nexus=$NEXUS_URL"
expect_contains "happy: only allowed env" "$log" "leak=unset"
expect_contains "happy: target is app worktree" "$log" "target=$REPOS/$PROJ1/.orc-worktrees/E2001"
expect_contains "happy: code root is runner root" "$log" "code_root=$CODE"
expect_file "happy worktree: preview-deploy.json in execution root" "$REPOS/$PROJ1/preview-deploy.json"
audit="$(cat "$AUDIT" 2>/dev/null || true)"
expect_contains "happy: audit line" "$audit" '"execution_id":"E2001","uid":'
expect_contains "happy: audit rc" "$audit" '"rc":0'
expect_eq "audit mode" "$(stat -c %a "$AUDIT" 2>/dev/null || true)" "600"

# rate-limit: повторный запрос на тот же E в пределах 30 c
rm -f "$QUEUE/E2001/.done"
run_once
expect_contains "rate-limit: reason" "$(jget "$QUEUE/E2001/status.json" reason)" "rate-limited"

# ─── 6. runner: git (.orc-eval) happy path ─────────────────────────────────
SHA_EVAL="$(make_eval_worktree E2030 "$PROJ1")"
expect_eq "git: eval path name == commit" "$(basename "$(dirname "$REPOS/$PROJ1/.orc-eval/E2030/$SHA_EVAL")")" "E2030"
set_state E2030 running test1 "$PROJ1"
enqueue E2030 "$PROJ1" git "$SHA_EVAL"
python3 - "$QUEUE/E2030/req.json" "$GATE" <<'PY'
import json, sys
p, gate = sys.argv[1:3]
d = json.load(open(p))
d["gate_bundle_digest"] = gate
d["feature_dir"] = "doc/идеи/F1"
d["feature_id"] = "F1"
json.dump(d, open(p, "w"))
PY
run_once
expect_eq "git happy: runner rc" "$RC" "0"
log="$(cat "$QUEUE/E2030/run.log" 2>/dev/null || true)"
expect_contains "git happy: target is eval commit-subdir" "$log" "target=$REPOS/$PROJ1/.orc-eval/E2030/$SHA_EVAL"
expect_contains "git happy: exec root is .orc-eval/<E>" "$log" "exec_root=$REPOS/$PROJ1/.orc-eval/E2030"
expect_contains "git happy: transport" "$log" "transport=git"
expect_contains "git happy: commit" "$log" "commit=$SHA_EVAL"
expect_contains "git happy: gate bundle env" "$log" "gate=$GATE"
expect_contains "git happy: feature env" "$log" "feature=doc/идеи/F1"
expect_contains "git happy: feature id env" "$log" "fid=F1"
expect_file "git happy: preview-deploy.json in execution root" "$REPOS/$PROJ1/.orc-eval/E2030/preview-deploy.json"
expect_nofile "git happy: preview-deploy.json NOT in commit-subdir" "$REPOS/$PROJ1/.orc-eval/E2030/$SHA_EVAL/preview-deploy.json"

# ─── 6b. runner: legacy /app gitdir is repaired to a relative path ──────────
REPO_GIT="$REPOS/$PROJ1"
git init -q "$REPO_GIT"
git -C "$REPO_GIT" config user.email t@t
git -C "$REPO_GIT" config user.name t
printf 'base\n' > "$REPO_GIT/base.txt"
git -C "$REPO_GIT" add base.txt
git -C "$REPO_GIT" commit -q -m base
SHA_REPAIR="$(git -C "$REPO_GIT" rev-parse HEAD)"
WT_REPAIR="$REPO_GIT/.orc-eval/E2032/$SHA_REPAIR"
mkdir -p "$(dirname "$WT_REPAIR")"
git -C "$REPO_GIT" worktree add --detach "$WT_REPAIR" "$SHA_REPAIR" >/dev/null
printf 'gitdir: /app/orc-repos/%s/.git/worktrees/%s\n' "$PROJ1" "$SHA_REPAIR" > "$WT_REPAIR/.git"
set_state E2032 running test1 "$PROJ1"
enqueue E2032 "$PROJ1" git "$SHA_REPAIR"
run_once
expect_eq "gitdir repair: runner rc" "$RC" "0"
expect_not_contains "gitdir repair: .git no longer points at /app" "$(head -c 200 "$WT_REPAIR/.git" 2>/dev/null || true)" "/app/"
expect_contains "gitdir repair: .git is relative" "$(head -c 200 "$WT_REPAIR/.git" 2>/dev/null || true)" "gitdir: ../"

# ─── 7. runner: e2e-preview command ────────────────────────────────────────
make_worktree E2031 "$PROJ1"
set_state E2031 running test1 "$PROJ1"
enqueue E2031 "$PROJ1" worktree "" e2e-preview
run_once
expect_eq "e2e: runner rc" "$RC" "0"
log="$(cat "$QUEUE/E2031/run.log" 2>/dev/null || true)"
expect_contains "e2e: e2e script executed" "$log" "fake e2e: exec=E2031"
expect_file "e2e: e2e-report in execution root" "$REPOS/$PROJ1/e2e-report.json"

# ─── 8. daemon + client integration ───────────────────────────────────────
make_worktree E2010 "$PROJ1"
set_state E2010 running test1 "$PROJ1"
make_worktree E2020 "$PROJ1"
set_state E2020 paused test1 "$PROJ1"

env \
  STAND_RUNNER_REPOS_ROOT="$REPOS" \
  STAND_RUNNER_QUEUE="$QUEUE" \
  STAND_RUNNER_CODE_ROOT="$CODE" \
  STAND_RUNNER_NEXUS_URL="$NEXUS_URL" \
  STAND_RUNNER_NEXUS_TOKEN_FILE="$TOKEN_FILE" \
  STAND_RUNNER_MANIFEST="$MANIFEST" \
  STAND_RUNNER_AUDIT_LOG="$AUDIT" \
  STAND_RUNNER_HOME="$RUNNER_HOME" \
  STAND_RUNNER_RUN_TIMEOUT=60 \
  "$DIR/stand-runner.sh" --daemon >"$TMP/daemon.log" 2>&1 &
DAEMON_PID=$!
sleep 1

run_client E2010 STAND_RUNNER_PROJECT_ID="$PROJ1" STAND_RUNNER_TRANSPORT=worktree
expect_eq "daemon+client happy: rc" "$RC" "0"
expect_contains "daemon+client happy: streamed log" "$OUT" "fake deploy: exec=E2010"
expect_eq "daemon+client happy: res rc" "$(jget "$QUEUE/E2010/res.json" rc)" "0"

run_client E2020 STAND_RUNNER_PROJECT_ID="$PROJ1" STAND_RUNNER_TRANSPORT=worktree
expect_eq "daemon+client reject: rc" "$RC" "1"
expect_contains "daemon+client reject: status" "$(jget "$QUEUE/E2020/status.json" reason)" "execution-not-running"

kill "$DAEMON_PID" 2>/dev/null
wait "$DAEMON_PID" 2>/dev/null
DAEMON_PID=""

# ─── 9. deploy-preview-stand → client bridge (no docker) ───────────────────
NODOCKER="$TMP/nodocker"
mkdir -p "$NODOCKER"
for b in bash mkdir chmod rm date stat tail python3 sleep dirname basename cat tr mv sha256sum env realpath awk grep; do
  src="$(command -v "$b" 2>/dev/null || true)"
  [ -n "$src" ] && ln -sf "$src" "$NODOCKER/$b"
done
if PATH="$NODOCKER" command -v docker >/dev/null 2>&1; then
  no "bridge: failed to mask docker"
else
  # worktree bridge: transport=worktree, no commit
  OUT="$(env -u STAND_RUNNER_EXECUTE STAND_RUNNER_QUEUE="$TMP/queue3" \
    STAND_RUNNER_PROJECT_ID="$PROJ1" STAND_RUNNER_TIMEOUT=1 \
    STAND_RUNNER_TRANSPORT=worktree PATH="$NODOCKER" \
    bash "$DIR/deploy-preview-stand.sh" E9200 2>&1)"
  RC=$?
  expect_eq "bridge: deploy-preview-stand -> client rc" "$RC" "124"
  expect_file "bridge: client req.json" "$TMP/queue3/E9200/req.json"
  expect_eq "bridge: transport" "$(jget "$TMP/queue3/E9200/req.json" transport)" "worktree"

  # git bridge: explicit commit
  OUT="$(env -u STAND_RUNNER_EXECUTE STAND_RUNNER_QUEUE="$TMP/queue3b" \
    STAND_RUNNER_PROJECT_ID="$PROJ1" STAND_RUNNER_TIMEOUT=1 \
    STAND_RUNNER_TRANSPORT=git STAND_RUNNER_COMMIT="$SHA1" PATH="$NODOCKER" \
    bash "$DIR/deploy-preview-stand.sh" E9202 2>&1)"
  RC=$?
  expect_eq "bridge git: rc" "$RC" "124"
  expect_eq "bridge git: commit" "$(jget "$TMP/queue3b/E9202/req.json" commit)" "$SHA1"
  expect_eq "bridge git: transport" "$(jget "$TMP/queue3b/E9202/req.json" transport)" "git"

  # E2E bridge
  OUT="$(env -u STAND_RUNNER_EXECUTE STAND_RUNNER_QUEUE="$TMP/queue4" \
    STAND_RUNNER_PROJECT_ID="$PROJ1" STAND_RUNNER_TIMEOUT=1 \
    STAND_RUNNER_TRANSPORT=worktree PATH="$NODOCKER" \
    bash "$DIR/run-stand-e2e.sh" E9201 2>&1)"
  RC=$?
  expect_eq "bridge e2e: rc" "$RC" "124"
  expect_eq "bridge e2e: command" "$(jget "$TMP/queue4/E9201/req.json" command)" "e2e-preview"
  expect_eq "bridge e2e: transport" "$(jget "$TMP/queue4/E9201/req.json" transport)" "worktree"
fi

# ─── 10. stand_cmd does not see nexus credentials; execution root honored ───
FAKE="$TMP/fakeproj"
mkdir -p "$FAKE/tools" "$FAKE/deploy" "$FAKE/exe" "$TMP/bin"
cp "$DIR/deploy-preview-stand.sh" "$FAKE/tools/deploy-preview-stand.sh"
cp "$DIR/_path1_project.py" "$FAKE/tools/_path1_project.py"
cat > "$FAKE/path1.project.json" <<'JSON'
{"deploy":{"stand_command":"bash deploy/probe.sh {stand} {ref} {execution_id}","dsn_command":"echo postgres://fake/db"}}
JSON
cat > "$FAKE/deploy/probe.sh" <<'EOS'
#!/usr/bin/env bash
{
  printf 'stand=%s ref=%s exec=%s\n' "${1:-}" "${2:-}" "${3:-}"
  printf 'NEXUS_TOKEN=%s\n' "${NEXUS_TOKEN-<unset>}"
  printf 'ORC_NEXUS_TOKEN=%s\n' "${ORC_NEXUS_TOKEN-<unset>}"
  printf 'NEXUS_BASE_URL=%s\n' "${NEXUS_BASE_URL-<unset>}"
} > "${PROBE_OUT:?}"
mkdir -p deploy/stands/.runtime/"${1:-test1}"
printf '{"image_digest":"sha256:%s","commit":"deadbee","build_ref":"deadbee","build_args_hash":"sha256:%s","gate_bundle_digest":"sha256:%s"}\n' \
  "$(printf 'a%.0s' $(seq 1 64))" "$(printf 'b%.0s' $(seq 1 64))" "$(printf 'c%.0s' $(seq 1 64))" \
  > deploy/stands/.runtime/"${1:-test1}"/build-provenance.json
EOS
chmod +x "$FAKE/deploy/probe.sh"
cat > "$TMP/bin/docker" <<'EOS'
#!/bin/sh
exit 0
EOS
cat > "$TMP/bin/git" <<'EOS'
#!/bin/sh
echo deadbee
EOS
cat > "$TMP/bin/curl" <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
url=""
for a in "$@"; do
  case "$a" in http://*|https://*) url="$a" ;; esac
done
case "$url" in
  */api/v1/stands/leases*)
    printf '%s\n' '{"active":true,"lease":{"stand_name":"test1","stand_url":"http://127.0.0.1:9/"}}'
    ;;
  *)
    printf '%s\n' '<html><script src="assets/index-abc123.js"></script></html>'
    ;;
esac
EOS
chmod +x "$TMP/bin/docker" "$TMP/bin/git" "$TMP/bin/curl"

PROBE_OUT="$TMP/probe.out"
export PROBE_OUT
OUT="$(PATH="$TMP/bin:$PATH" PROBE_OUT="$PROBE_OUT" \
  NEXUS_TOKEN="secret-token" ORC_NEXUS_TOKEN="orc-secret" \
  NEXUS_BASE_URL="http://127.0.0.1:9" ORC_TARGET_ROOT="$FAKE" ORC_EXECUTION_ROOT="$FAKE/exe" \
  ORC_EXECUTION_TRANSPORT=worktree \
  bash "$FAKE/tools/deploy-preview-stand.sh" E7001 2>&1)"
RC=$?
expect_eq "creds: deploy-preview-stand rc" "$RC" "0"
probe="$(cat "$PROBE_OUT" 2>/dev/null || true)"
expect_contains "creds: stand_cmd called" "$probe" "stand=test1 ref=deadbee exec=E7001"
expect_contains "creds: NEXUS_TOKEN hidden" "$probe" "NEXUS_TOKEN=<unset>"
expect_contains "creds: ORC_NEXUS_TOKEN hidden" "$probe" "ORC_NEXUS_TOKEN=<unset>"
expect_contains "creds: NEXUS_BASE_URL hidden" "$probe" "NEXUS_BASE_URL=<unset>"
expect_eq "creds: preview-deploy.json stand" "$(jget "$FAKE/exe/preview-deploy.json" stand)" "test1"

# ─── 10b. manifest generator (Deploy Dev post-step) ────────────────────────
MAN_ROOT="$TMP/man-root"
MAN_OUT="$TMP/man.out"
mkdir -p "$MAN_ROOT/tools/__pycache__" "$MAN_ROOT/deploy/stands/.runtime" "$MAN_ROOT/deploy/app"
printf '#!/bin/sh\n' > "$MAN_ROOT/tools/a.sh"
printf 'x\n' > "$MAN_ROOT/deploy/app/b.sh"
printf 'bytecode\n' > "$MAN_ROOT/tools/__pycache__/a.pyc"
printf 'runtime\n' > "$MAN_ROOT/deploy/stands/.runtime/ignore"
bash "$DIR/gen-stand-runner-manifest.sh" "$MAN_ROOT" "$MAN_OUT" >/dev/null
expect_eq "manifest: two source files" "$(wc -l < "$MAN_OUT" | tr -d ' ')" "2"
expect_contains "manifest: tools included" "$(cat "$MAN_OUT")" "tools/a.sh"
expect_contains "manifest: deploy included" "$(cat "$MAN_OUT")" "deploy/app/b.sh"
expect_not_contains "manifest: pyc excluded" "$(cat "$MAN_OUT")" "__pycache__"
expect_not_contains "manifest: runtime excluded" "$(cat "$MAN_OUT")" "deploy/stands/.runtime"
expect_eq "manifest: mode" "$(stat -c %a "$MAN_OUT")" "644"
printf 'y\n' >> "$MAN_ROOT/deploy/app/b.sh"
bash "$DIR/gen-stand-runner-manifest.sh" "$MAN_ROOT" "$MAN_OUT" >/dev/null
expect_ne "manifest: hash follows content" "$(grep 'deploy/app/b.sh' "$MAN_OUT" | awk '{print $1}')" \
  "$(printf 'x\n' | sha256sum | awk '{print $1}')"

# ─── 11. systemd unit ──────────────────────────────────────────────────────
UNIT="$DIR/stand-runner.service"
unit_text="$(cat "$UNIT" 2>/dev/null || true)"
expect_contains "unit: User" "$unit_text" "User=ukituki"
expect_contains "unit: ExecStart" "$unit_text" "ExecStart=/srv/archkit/deploy-dev/tools/stand-runner.sh --daemon"
expect_contains "unit: CODE_ROOT" "$unit_text" "STAND_RUNNER_CODE_ROOT=/srv/archkit/deploy-dev"
expect_contains "unit: ALLOW_LEASE_ONLY" "$unit_text" "STAND_RUNNER_ALLOW_LEASE_ONLY=1"
expect_contains "unit: NoNewPrivileges" "$unit_text" "NoNewPrivileges=yes"
expect_contains "unit: ProtectSystem" "$unit_text" "ProtectSystem=strict"
expect_contains "unit: PrivateTmp" "$unit_text" "PrivateTmp=no"
expect_contains "unit: Restart" "$unit_text" "Restart=on-failure"
expect_contains "unit: docker socket" "$unit_text" "/var/run/docker.sock"

if command -v systemd-analyze >/dev/null 2>&1; then
  fake_exec="$TMP/fake-exec.sh"
  printf '#!/bin/sh\nexit 0\n' > "$fake_exec"
  chmod +x "$fake_exec"
  verify_unit="$TMP/stand-runner-verify.service"
  sed -e "s#^ExecStart=.*#ExecStart=$fake_exec --daemon#" \
      -e "s#^ReadWritePaths=.*#ReadWritePaths=$TMP#" \
      "$UNIT" > "$verify_unit"
  if out="$(systemd-analyze verify "$verify_unit" 2>&1)"; then
    ok "systemd-analyze verify"
  else
    no "systemd-analyze verify: $out"
  fi
else
  ok "systemd-analyze verify (skipped: not installed)"
fi

# ─── summary ────────────────────────────────────────────────────────────────
printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
