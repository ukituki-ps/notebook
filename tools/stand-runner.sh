#!/usr/bin/env bash
# stand-runner (F180 / ADR-KIT-091 followup) — host-половина s20b.
#
# ORC-контейнер не имеет docker/ssh/docker.sock: tools/deploy-preview-stand.sh
# там уходит в tools/stand-runner-client.sh, который кладёт запрос в общую
# очередь. Этот скрипт запускается на хосте (pr01, user ukituki) и исполняет
# ровно один разрешённый сценарий: deploy-preview-stand.sh <E> из worktree
# исполнения, после проверки аренды стенда, статуса исполнения и hash-pin.
#
# Режимы:
#   stand-runner.sh --once <queue_dir>   один проход по очереди
#   stand-runner.sh --daemon             watch-loop (sleep 2)
#
# ENV (все опциональны):
#   STAND_RUNNER_REPOS_ROOT            default /home/ukituki/orc-repos
#   STAND_RUNNER_QUEUE                 default $REPOS_ROOT/.deploy-queue
#   STAND_RUNNER_CODE_ROOT             default <dir of this script>/..  (immutable
#                                      deploy tree: tools/ + deploy/; НЕ app worktree)
#   STAND_RUNNER_NEXUS_URL             default http://192.168.1.20:9182
#   STAND_RUNNER_NEXUS_TOKEN_FILE      default /home/ukituki/.secrets/lkfl-runner.token
#   STAND_RUNNER_MANIFEST              default /home/ukituki/lkfl-runner/manifest.sha256
#   STAND_RUNNER_AUDIT_LOG             default /home/ukituki/lkfl-runner/audit.log
#   STAND_RUNNER_HOME                  default /home/ukituki
#   STAND_RUNNER_RUN_TIMEOUT           default 1800 (timeout --kill-after=30)
#   STAND_RUNNER_RATE_LIMIT_SECONDS    default 30 (не более 1 запуска на E)
#   STAND_RUNNER_ALLOW_LEASE_ONLY      default 0; 1 — если endpoint статуса
#                                      исполнения недоступен, полагаться на аренду
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOS_ROOT="${STAND_RUNNER_REPOS_ROOT:-/home/ukituki/orc-repos}"
CODE_ROOT="${STAND_RUNNER_CODE_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
NEXUS_URL="${STAND_RUNNER_NEXUS_URL:-http://192.168.1.20:9182}"
TOKEN_FILE="${STAND_RUNNER_NEXUS_TOKEN_FILE:-/home/ukituki/.secrets/lkfl-runner.token}"
MANIFEST="${STAND_RUNNER_MANIFEST:-/home/ukituki/lkfl-runner/manifest.sha256}"
AUDIT_LOG="${STAND_RUNNER_AUDIT_LOG:-/home/ukituki/lkfl-runner/audit.log}"
RUNNER_HOME="${STAND_RUNNER_HOME:-/home/ukituki}"
RUN_TIMEOUT="${STAND_RUNNER_RUN_TIMEOUT:-1800}"
RATE_LIMIT_S="${STAND_RUNNER_RATE_LIMIT_SECONDS:-30}"
ALLOW_LEASE_ONLY="${STAND_RUNNER_ALLOW_LEASE_ONLY:-0}"
[[ "$RUN_TIMEOUT" =~ ^[0-9]+$ ]] || RUN_TIMEOUT=1800
[[ "$RATE_LIMIT_S" =~ ^[0-9]+$ ]] || RATE_LIMIT_S=30
[[ "$ALLOW_LEASE_ONLY" == "1" ]] || ALLOW_LEASE_ONLY=0
SAFE_PATH="${STAND_RUNNER_PATH:-/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin}"

ALLOWED_STANDS=" test1 test2 "

usage() {
  cat >&2 <<'USAGE'
usage: stand-runner.sh --once <queue_dir> | --daemon
USAGE
}

log_line() { printf '%s stand-runner: %s\n' "$(date -u +%FT%TZ)" "$*"; }

sanitize() { local s="$1"; s="${s//$'\n'/ }"; s="${s//$'\r'/ }"; s="${s//\"/\'}"; printf '%s' "$s"; }

write_atomic() { # <path> <content>
  local path="$1" content="$2" tmp
  tmp="$(dirname -- "$path")/.tmp.$(basename -- "$path").$$"
  ( umask 077; printf '%s\n' "$content" > "$tmp" )
  mv -f -- "$tmp" "$path"
}

audit() { # <eid> <worktree> <rc> <duration> <reason>
  local eid="$1" wt="$2" rc="$3" dur="$4" reason="$5" line
  mkdir -p -- "$(dirname -- "$AUDIT_LOG")"
  ( umask 077; touch -- "$AUDIT_LOG"; chmod 600 -- "$AUDIT_LOG" )
  line="$(printf '{"ts":"%s","execution_id":"%s","uid":%s,"worktree":"%s","rc":%s,"duration_s":%s,"reason":"%s"}' \
    "$(date -u +%FT%TZ)" "$eid" "$(id -u)" "$(sanitize "$wt")" "$rc" "$dur" "$(sanitize "$reason")")"
  printf '%s\n' "$line" >> "$AUDIT_LOG"
}

# reject <dir> <eid> <worktree> <started_epoch> <reason>
# Пишет run.log, res.json, status.json, audit; выходит из subshell-call-site.
reject() {
  local dir="$1" eid="$2" wt="$3" started="$4" reason="$5"
  local now dur
  now="$(date +%s)"; dur=$(( now - started ))
  printf 'stand-runner: reject: %s\n' "$reason" >> "$dir/run.log"
  write_atomic "$dir/res.json" \
    "$(printf '{"execution_id":"%s","rc":1,"reason":"%s","ts":"%s"}' "$eid" "$(sanitize "$reason")" "$(date -u +%FT%TZ)")"
  write_atomic "$dir/status.json" \
    "$(printf '{"execution_id":"%s","state":"rejected","reason":"%s","rc":1,"duration_s":%s,"worktree":"%s","finished_at":"%s"}' \
      "$eid" "$(sanitize "$reason")" "$dur" "$(sanitize "$wt")" "$(date -u +%FT%TZ)")"
  audit "$eid" "$wt" 1 "$dur" "reject: $reason"
  : > "$dir/.done"
}

# request_fields <req.json> — строгая проверка контракта запроса.
# stdout: "<execution_id>\t<project_id>\t<ts>\t<command>\t<transport>\t<commit>"
# exit 3 — не JSON/не объект; exit 4 — нарушение allowlist/семантики.
#
# Инварианты:
#   * ровно {execution_id,project_id,command,transport,ts} (+commit для git);
#   * неизвестные поля → reject (не игнор);
#   * command ∈ {deploy-preview,e2e-preview};
#   * transport ∈ {git,worktree};
#   * git  → commit обязателен, 40-hex;
#   * worktree → commit ЗАПРЕЩЁН (явное правило, не «молча игнорировать»).
request_fields() {
  python3 - "$1" <<'PY'
import json
import re
import sys

path = sys.argv[1]
try:
    with open(path, "rb") as fh:
        raw = fh.read(65536)
    data = json.loads(raw)
except Exception:
    sys.exit(3)
if not isinstance(data, dict):
    sys.exit(3)

base = {"execution_id", "project_id", "command", "transport", "gate_bundle_digest", "ts"}
keys = set(data.keys())
allowed = {frozenset(base | a | b)
           for a in (set(), {"commit"})
           for b in (set(), {"feature_dir"}, {"feature_id"}, {"feature_dir", "feature_id"})}
if frozenset(keys) not in allowed:
    sys.exit(4)

command = data.get("command")
if command not in ("deploy-preview", "e2e-preview"):
    sys.exit(4)
transport = data.get("transport")
if transport not in ("git", "worktree"):
    sys.exit(4)

eid = data.get("execution_id")
pid = data.get("project_id")
ts = data.get("ts")
if not all(isinstance(v, str) and v for v in (eid, pid, ts)):
    sys.exit(4)

gate_digest = data.get("gate_bundle_digest", "")
if not isinstance(gate_digest, str) or not re.fullmatch(r"sha256:[0-9a-fA-F]{64}", gate_digest):
    # The host runner is the enforcement point: a hand-written or old client
    # request must not deploy an unbound stand.
    sys.exit(4)
gate_digest = gate_digest.lower()

commit = data.get("commit")
if transport == "git":
    if not isinstance(commit, str) or not re.fullmatch(r"[0-9a-fA-F]{40}", commit):
        sys.exit(4)
    commit = commit.lower()
else:
    # worktree не несёт commit: присутствие поля — нарушение контракта.
    if "commit" in data:
        sys.exit(4)
    commit = ""

feature_dir = data.get("feature_dir", "")
feature_id = data.get("feature_id", "")
if not isinstance(feature_dir, str) or not isinstance(feature_id, str):
    sys.exit(4)
if feature_dir:
    if feature_dir.startswith("/") or any(part == ".." for part in feature_dir.split("/")):
        sys.exit(4)
if feature_id and not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{0,63}", feature_id):
    sys.exit(4)

print("%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s" % (
    eid, pid, ts, command, transport, commit, gate_digest, feature_dir, feature_id))
PY
}

# verify_manifest [root] — hash-pin по manifest.sha256.
# Проверяет IMMUTABLE RUNNER CODE ROOT (tools/ + deploy/), а не app worktree:
# app-репо (notebook) не обязан содержать platform tools, а подмена платформы
# должна ловиться до запуска. Формат строки: <sha256>  <relpath>. Fail-closed.
verify_manifest() {
  local wt="${1:-$CODE_ROOT}" line sha rel target actual count=0 has_deploy_script=0 has_deploy_dir=0 has_client=0
  [ -r "$MANIFEST" ] || { echo "manifest-missing: $MANIFEST"; return 1; }
  while IFS= read -r line || [ -n "$line" ]; do
    [ -z "$line" ] && continue
    case "$line" in \#*) continue ;; esac
    sha="${line%% *}"
    rel="${line#* }"
    while [ "${rel# }" != "$rel" ]; do rel="${rel# }"; done
    [[ "$sha" =~ ^[0-9a-fA-F]{64}$ ]] || { echo "manifest-bad-line: $line"; return 1; }
    case "$rel" in
      /*|"") echo "manifest-bad-path: $rel"; return 1 ;;
    esac
    case "/$rel/" in
      */../*) echo "manifest-escape: $rel"; return 1 ;;
    esac
    target="$wt/$rel"
    [ -f "$target" ] || { echo "manifest-missing-file: $rel"; return 1; }
    actual="$(sha256sum -- "$target" | awk '{print $1}')"
    if [ "${actual,,}" != "${sha,,}" ]; then
      echo "manifest-mismatch: $rel"
      return 1
    fi
    count=$((count + 1))
    case "$rel" in
      tools/deploy-preview-stand.sh) has_deploy_script=1 ;;
      tools/stand-runner-client.sh) has_client=1 ;;
      deploy/*) has_deploy_dir=1 ;;
    esac
  done < "$MANIFEST"
  [ "$count" -gt 0 ] || { echo "manifest-empty"; return 1; }
  [ "$has_deploy_script" = "1" ] || { echo "manifest-unpinned: tools/deploy-preview-stand.sh"; return 1; }
  [ "$has_client" = "1" ] || { echo "manifest-unpinned: tools/stand-runner-client.sh"; return 1; }
  [ "$has_deploy_dir" = "1" ] || { echo "manifest-unpinned: deploy/**"; return 1; }
  return 0
}

# verify_target_tree <target> <transport> <commit> — отдельная проверка app-дерева.
# Не требует tools/: платформенные скрипты живут в CODE_ROOT (E2703 followup).
#   * git worktree и tracked-чистота (untracked допустимы: .orc-eval/ и пр.);
#   * для git HEAD обязан совпасть с evaluated commit (fail-close).
# repair_eval_gitfile <target> — legacy eval worktrees created inside the ORC
# container carry `gitdir: /app/...`, which does not exist on the host. A
# relative gitdir is valid from both bind-mount sides; rewrite it before the
# host git commands run. No-op for healthy or non-eval worktrees.
repair_eval_gitfile() {
  local target="$1" gitfile="$1/.git" line gitdir name repo rel
  case "$target" in */.orc-eval/*/*) ;; *) return 0 ;; esac
  [ -f "$gitfile" ] || return 0
  line="$(head -c 4096 -- "$gitfile" 2>/dev/null || true)"
  case "$line" in gitdir:*) ;; *) return 0 ;; esac
  gitdir="${line#gitdir: }"
  gitdir="${gitdir%%$'\n'*}"
  [ -n "$gitdir" ] || return 0
  # Healthy on this host: leave it alone.
  if [ -e "$gitdir" ]; then return 0; fi
  name="${gitdir##*/}"
  [ -n "$name" ] || return 0
  repo="${target%%/.orc-eval/*}"
  rel="$(python3 -c 'import os,sys;print(os.path.relpath(sys.argv[1], sys.argv[2]))' "$repo/.git/worktrees/$name" "$target" 2>/dev/null || true)"
  [ -n "$rel" ] || return 0
  printf 'gitdir: %s\n' "$rel" > "$gitfile" 2>/dev/null || return 0
  echo "repair: relative gitdir for $target"
}

verify_target_tree() {
  local target="$1" transport="$2" commit="$3" dirty head
  [ -d "$target" ] || { echo "target-missing: $target"; return 1; }
  if ! git -C "$target" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    repair_eval_gitfile "$target"
  fi
  git -C "$target" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || { echo "target-not-git: $target"; return 1; }
  dirty="$(git -C "$target" status --porcelain --untracked-files=no 2>/dev/null || true)"
  [ -z "$dirty" ] || { echo "target-dirty: $dirty"; return 1; }
  if [ "$transport" = "git" ]; then
    head="$(git -C "$target" rev-parse HEAD 2>/dev/null || true)"
    [ "${head,,}" = "${commit,,}" ] || { echo "target-head-mismatch: HEAD=$head commit=$commit"; return 1; }
  fi
  return 0
}

# nexus_json <url> — GET с bearer; печатает тело, exit != 0 при недоступности.
nexus_json() {
  curl -fsS -m 15 -H "Authorization: Bearer $token" "$1"
}

request_main() {
  local dir="$1"
  local name eid req_fields exec_id project_id ts command transport commit gate_digest
  local project_root project_real expected expected_real worktree execution_root
  local lease_fields stand lease_pid status
  local started run_rc reason last now

  name="$(basename -- "$dir")"
  started="$(date +%s)"
  worktree=""

  # 1) Имя каталога = execution_id; allowlist E-формы.
  if [[ ! "$name" =~ ^E[0-9]+$ ]]; then
    reject "$dir" "$name" "" "$started" "bad-execution-id: $name"
    return 0
  fi
  eid="$name"
  [ -f "$dir/req.json" ] || return 0

  # 2) Строгие поля запроса (лишнее поле = reject, а не игнор).
  if req_fields="$(request_fields "$dir/req.json" 2>/dev/null)"; then
    :
  else
    local prc=$?
    if [ "$prc" = "4" ]; then
      reject "$dir" "$eid" "" "$started" "request-fields-invalid"
    else
      reject "$dir" "$eid" "" "$started" "request-not-json"
    fi
    return 0
  fi
  IFS=$'\t' read -r exec_id project_id ts command transport commit gate_digest feature_dir feature_id <<< "$req_fields"
  if [ "$exec_id" != "$eid" ]; then
    reject "$dir" "$eid" "" "$started" "execution-id-mismatch"
    return 0
  fi
  if [[ ! "$project_id" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]; then
    reject "$dir" "$eid" "" "$started" "project-id-invalid"
    return 0
  fi
  if [[ ! "$ts" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}([.][0-9]+)?(Z|[+-][0-9]{2}:[0-9]{2})$ ]]; then
    reject "$dir" "$eid" "" "$started" "timestamp-invalid"
    return 0
  fi

  # 3) Путь исполнения строго по транспорту:
  #      git      → $REPOS_ROOT/<project>/.orc-eval/<E>/<commit>
  #      worktree → $REPOS_ROOT/<project>/.orc-worktrees/<E>
  #    root/project/цель резолвим через realpath -e и требуем совпадения с
  #    ЛЕКСИЧЕСКИ ожидаемым путём: любой symlink-компонент наружу даёт другой
  #    realpath → reject (fail-closed). project_id входит в путь явно.
  local root_real
  root_real="$(realpath -e -- "$REPOS_ROOT" 2>/dev/null || true)"
  if [ -z "$root_real" ] || [ ! -d "$root_real" ]; then
    reject "$dir" "$eid" "" "$started" "repos-root-missing: $REPOS_ROOT"
    return 0
  fi
  project_root="$root_real/$project_id"
  project_real="$(realpath -e -- "$project_root" 2>/dev/null || true)"
  if [ -z "$project_real" ] || [ "$project_real" != "$project_root" ] || [ ! -d "$project_real" ]; then
    reject "$dir" "$eid" "$project_root" "$started" "project-path-mismatch: $project_root"
    return 0
  fi

  if [ "$transport" = "git" ]; then
    if [[ ! "$commit" =~ ^[0-9a-f]{40}$ ]]; then
      reject "$dir" "$eid" "" "$started" "commit-invalid: $commit"
      return 0
    fi
    expected="$project_real/.orc-eval/$eid/$commit"
    execution_root="$project_real/.orc-eval/$eid"
  elif [ "$transport" = "worktree" ]; then
    expected="$project_real/.orc-worktrees/$eid"
    # Per-run артефакты worktree-транспорта, как раньше: корень проекта.
    execution_root="$project_real"
  else
    reject "$dir" "$eid" "" "$started" "transport-not-allowed: $transport"
    return 0
  fi
  expected_real="$expected"
  worktree="$(realpath -e -- "$expected" 2>/dev/null || true)"
  if [ -z "$worktree" ] || [ "$worktree" != "$expected_real" ] || [ ! -d "$worktree" ]; then
    if [ "$transport" = "git" ]; then
      reject "$dir" "$eid" "$expected" "$started" "eval-worktree-missing: $expected"
    else
      reject "$dir" "$eid" "$expected" "$started" "worktree-path-mismatch: $expected"
    fi
    return 0
  fi

  # 4) Single-flight per E (flock, non-blocking). Занято — оставляем другой
  #    инстанс, res.json напишет он.
  exec 9>"$dir/.lock"
  if ! flock -n 9; then
    log_line "skip $eid: already in flight"
    return 0
  fi

  # 5) Rate-limit: не более одного запуска в RATE_LIMIT_S на E.
  now="$(date +%s)"
  if [ -f "$dir/.last-run" ]; then
    last="$(cat -- "$dir/.last-run" 2>/dev/null || echo 0)"
    [[ "$last" =~ ^[0-9]+$ ]] || last=0
    if [ $(( now - last )) -lt "$RATE_LIMIT_S" ]; then
      reject "$dir" "$eid" "$worktree" "$started" "rate-limited: last run $(( now - last ))s ago (limit ${RATE_LIMIT_S}s)"
      return 0
    fi
  fi

  # 6) Hash-pin IMMUTABLE RUNNER CODE ROOT (tools/ + deploy/). App-дерево
  #    проверяется отдельно: наличие/git/чистота/commit, БЕЗ требования tools/.
  reason="$(verify_manifest "$CODE_ROOT" || true)"
  if [ -n "$reason" ]; then
    reject "$dir" "$eid" "$worktree" "$started" "hash-pin: $reason"
    return 0
  fi
  reason="$(verify_target_tree "$worktree" "$transport" "$commit" || true)"
  if [ -n "$reason" ]; then
    reject "$dir" "$eid" "$worktree" "$started" "target-tree: $reason"
    return 0
  fi

  # 7) Nexus: токен из файла; аренда test1/test2 + тот же project_id.
  token="$(tr -d '\r\n' < "$TOKEN_FILE" 2>/dev/null || true)"
  if [ -z "$token" ]; then
    reject "$dir" "$eid" "$worktree" "$started" "nexus-token-missing"
    return 0
  fi

  local leases
  if ! leases="$(nexus_json "$NEXUS_URL/api/v1/stands/leases?execution_id=$eid" 2>/dev/null)"; then
    reject "$dir" "$eid" "$worktree" "$started" "nexus-leases-unavailable (fail-closed)"
    return 0
  fi
  lease_fields="$(printf '%s' "$leases" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(2)
if not d.get("active"):
    print("none\t")
    sys.exit(0)
l = d.get("lease") or {}
print("%s\t%s" % (l.get("stand_name") or "", l.get("project_id") or ""))
' 2>/dev/null)" || {
    reject "$dir" "$eid" "$worktree" "$started" "nexus-leases-unavailable (bad response)"
    return 0
  }
  IFS=$'\t' read -r stand lease_pid <<< "$lease_fields"
  if [ -z "$stand" ]; then
    reject "$dir" "$eid" "$worktree" "$started" "lease-not-found"
    return 0
  fi
  case "$ALLOWED_STANDS" in
    *" $stand "*) ;;
    *) reject "$dir" "$eid" "$worktree" "$started" "lease-stand-not-allowed: $stand"; return 0 ;;
  esac
  if [ "${lease_pid,,}" != "${project_id,,}" ]; then
    reject "$dir" "$eid" "$worktree" "$started" "lease-project-mismatch: lease=$lease_pid request=$project_id"
    return 0
  fi

  # 8) Статус исполнения (Nexus REST /api/v1/executions). На dev-контуре такого
  #    endpoint нет (302 → /healthz), поэтому оператор может разрешить
  #    lease-only: аренда уже проверена выше, а источник истины о статусе — ORC.
  #    Без флага endpoint недоступен → reject (fail-closed).
  local exec_resp status
  if exec_resp="$(nexus_json "$NEXUS_URL/api/v1/executions/$eid" 2>/dev/null)"; then
    status="$(printf '%s' "$exec_resp" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(2)
v = d.get("status")
if v is None and isinstance(d.get("execution"), dict):
    v = d["execution"].get("status")
print(v or "")
' 2>/dev/null)" || {
      if [ "$ALLOW_LEASE_ONLY" = "1" ]; then
        audit "$eid" "$worktree" 0 0 "lease-only: executions response unparsable"
        status=""
      else
        reject "$dir" "$eid" "$worktree" "$started" "nexus-executions-unavailable (bad response)"
        return 0
      fi
    }
  else
    if [ "$ALLOW_LEASE_ONLY" = "1" ]; then
      audit "$eid" "$worktree" 0 0 "lease-only: executions endpoint unavailable"
      status=""
    else
      reject "$dir" "$eid" "$worktree" "$started" "nexus-executions-unavailable (fail-closed)"
      return 0
    fi
  fi
  if [ -n "$status" ] && [ "$status" != "running" ]; then
    reject "$dir" "$eid" "$worktree" "$started" "execution-not-running: ${status:-unknown}"
    return 0
  fi

  # 9) Запуск: платформенный скрипт из RUNNER_CODE_ROOT (cwd=CODE_ROOT), а
  #    app-дерево передаётся ЯВНО через ORC_TARGET_ROOT. Platform tools в
  #    app worktree не копируются и не требуются.
  case "$command" in
    deploy-preview) run_script="$CODE_ROOT/tools/deploy-preview-stand.sh" ;;
    e2e-preview)    run_script="$CODE_ROOT/tools/run-stand-e2e.sh" ;;
    *) reject "$dir" "$eid" "$worktree" "$started" "command-not-allowed: $command"; return 0 ;;
  esac
  [ -f "$run_script" ] || {
    reject "$dir" "$eid" "$worktree" "$started" "runner-script-missing: $run_script"
    return 0
  }
  if [ "$command" = "e2e-preview" ] && ! grep -qE "[[:space:]]tools/run-stand-e2e\.sh$" "$MANIFEST" 2>/dev/null; then
    reject "$dir" "$eid" "$worktree" "$started" "manifest-unpinned: tools/run-stand-e2e.sh"
    return 0
  fi
  write_atomic "$dir/.last-run" "$now"
  : > "$dir/run.log"
  printf 'stand-runner: start %s command=%s transport=%s stand=%s target=%s execution_root=%s code_root=%s\n' \
    "$eid" "$command" "$transport" "$stand" "$worktree" "$execution_root" "$CODE_ROOT" >> "$dir/run.log"
  run_rc=0
  (
    cd "$CODE_ROOT"
    timeout --kill-after=30 "$RUN_TIMEOUT" \
      env -i \
        PATH="$SAFE_PATH" \
        HOME="$RUNNER_HOME" \
        STAND_RUNNER_EXECUTE=1 \
        NEXUS_BASE_URL="$NEXUS_URL" \
        NEXUS_TOKEN="$token" \
        ORC_PROJECT_ID="$project_id" \
        ORC_EXECUTION_ID="$eid" \
        ORC_TARGET_ROOT="$worktree" \
        ORC_EXECUTION_ROOT="$execution_root" \
        ORC_EXECUTION_TRANSPORT="$transport" \
        ORC_EVALUATED_SHA="$commit" \
        NEXUS_GATE_BUNDLE_DIGEST="$gate_digest" \
        ORC_FEATURE_DIR="$feature_dir" \
        FEATURE_ID="$feature_id" \
        E2E_MODE="${STAND_RUNNER_E2E_MODE:-auto}" \
        E2E_SEM_DIR="$RUNNER_HOME/.cache/archkit-e2e-sem" \
        PLAYWRIGHT_BROWSERS_PATH="$RUNNER_HOME/.cache/ms-playwright" \
        bash "$run_script" "$eid"
  ) >> "$dir/run.log" 2>&1 || run_rc=$?

  local dur finished
  finished="$(date -u +%FT%TZ)"
  dur=$(( $(date +%s) - started ))
  if [ "$run_rc" -eq 0 ]; then
    reason="ok"
  else
    reason="deploy-failed rc=$run_rc"
  fi
  write_atomic "$dir/res.json" \
    "$(printf '{"execution_id":"%s","rc":%s,"reason":"%s","duration_s":%s,"ts":"%s"}' \
      "$eid" "$run_rc" "$(sanitize "$reason")" "$dur" "$finished")"
  write_atomic "$dir/status.json" \
    "$(printf '{"execution_id":"%s","state":"%s","reason":"%s","rc":%s,"stand":"%s","worktree":"%s","duration_s":%s,"finished_at":"%s"}' \
      "$eid" "$([ "$run_rc" -eq 0 ] && echo done || echo failed)" "$(sanitize "$reason")" \
      "$run_rc" "$stand" "$(sanitize "$worktree")" "$dur" "$finished")"
  audit "$eid" "$worktree" "$run_rc" "$dur" "$reason"
  : > "$dir/.done"
  return 0
}

process_request() {
  local dir="$1"
  ( request_main "$dir" )
}

# queue_dir <mode> ...
queue="${STAND_RUNNER_QUEUE:-$REPOS_ROOT/.deploy-queue}"
mode=""
case "${1:-}" in
  --once)
    mode="once"
    [ -n "${2:-}" ] || { usage; exit 2; }
    queue="$2"
    ;;
  --daemon)
    mode="daemon"
    ;;
  -h|--help)
    usage; exit 0
    ;;
  *)
    usage; exit 2
    ;;
esac

mkdir -p -- "$queue"

if [ "$mode" = "once" ]; then
  found=0
  for dir in "$queue"/E*; do
    [ -d "$dir" ] || continue
    name="$(basename -- "$dir")"
    [[ "$name" =~ ^E[0-9]+$ ]] || continue
    [ -f "$dir/.done" ] && continue
    [ -f "$dir/req.json" ] || continue
    found=1
    process_request "$dir" || true
  done
  [ "$found" = "1" ] || log_line "queue empty: $queue"
  exit 0
fi

log_line "daemon started (queue=$queue, repos=$REPOS_ROOT, nexus=$NEXUS_URL)"
while :; do
  for dir in "$queue"/E*; do
    [ -d "$dir" ] || continue
    name="$(basename -- "$dir")"
    [[ "$name" =~ ^E[0-9]+$ ]] || continue
    [ -f "$dir/.done" ] && continue
    [ -f "$dir/req.json" ] || continue
    process_request "$dir" || true
  done
  sleep 2
done
