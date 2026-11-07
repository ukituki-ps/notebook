#!/usr/bin/env bash
# stand-runner-client (F180 / ADR-KIT-091 followup) — клиентская половина
# host-runner'а для шагов s20b/s20c.
#
# Зачем: в ORC-контейнере нет docker/ssh/docker.sock, а стенды живут на
# pr01 (192.168.1.20). Вместо прямого выката клиент кладёт запрос в общую
# очередь (bind-mount orc-repos) и ждёт результат, который положит
# tools/stand-runner.sh, запущенный на хосте под ukituki.
#
# Request contract (строгий; runner отклоняет неизвестные поля):
#   {
#     "execution_id": "E123",            # ^E[0-9]+$
#     "project_id":  "<uuid>",
#     "command":     "deploy-preview" | "e2e-preview",
#     "transport":   "git" | "worktree",
#     "commit":      "<40-hex>",         # только transport=git
#     "gate_bundle_digest": "sha256:<64hex>",
#     "ts":          "<RFC3339>"
#   }
#
# transport/commit resolution:
#   1) STAND_RUNNER_TRANSPORT | ORC_EXECUTION_TRANSPORT
#   2) путь исполнения: .../.orc-eval/<E>/<sha> → git + commit=<sha>;
#      .../.orc-worktrees/<E> → worktree
#   3) иначе fail-close: silent worktree fallback удалён (ADR-KIT-079).
#   commit: STAND_RUNNER_COMMIT | ORC_EVALUATED_SHA | EVALUATED_SHA, затем sha
#   из пути .orc-eval. Для git commit обязателен: угадывание HEAD запрещено.
#
# Контракт вызова:
#   stand-runner-client.sh <execution_id> [command]
#     ENV: STAND_RUNNER_PROJECT_ID | ORC_PROJECT_ID   (обязателен)
#          STAND_RUNNER_QUEUE                         (default: /app/orc-repos/.deploy-queue,
#                                                      иначе $HOME/orc-repos/.deploy-queue)
#          STAND_RUNNER_TIMEOUT                       (default 1800 c)
#   exit: rc из res.json; 2 — некорректные аргументы/окружение;
#         124 — таймаут; 0 — no-op, если очереди нет вовсе.
#
# Клиент НЕ исполняет deploy и не может включить runner-режим: любые
# STAND_RUNNER_EXECUTE из окружения отбрасываются.
set -euo pipefail

unset STAND_RUNNER_EXECUTE

die() { printf 'stand-runner-client: %s\n' "$*" >&2; exit 2; }

exec_id="${1:-}"
[[ "$exec_id" =~ ^E[0-9]+$ ]] || die "invalid execution_id (expected ^E[0-9]+\$)"
command="${2:-deploy-preview}"
case "$command" in
  deploy-preview|e2e-preview) ;;
  *) die "invalid command: $command (allowed: deploy-preview|e2e-preview)" ;;
esac

project_id="${STAND_RUNNER_PROJECT_ID:-${ORC_PROJECT_ID:-}}"
[ -n "$project_id" ] || die "project_id is required (STAND_RUNNER_PROJECT_ID or ORC_PROJECT_ID)"
[[ "$project_id" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]] || die "invalid project_id"

# ── transport/commit: явное окружение → вывод из пути исполнения ────────────
here="$(pwd -P 2>/dev/null || pwd)"
transport="${STAND_RUNNER_TRANSPORT:-${ORC_EXECUTION_TRANSPORT:-}}"
commit="${STAND_RUNNER_COMMIT:-${ORC_EVALUATED_SHA:-${EVALUATED_SHA:-}}}"

path_commit=""
case "$here" in
  */.orc-eval/"$exec_id"/*)
    _tail="${here##*/.orc-eval/"$exec_id"/}"
    path_commit="${_tail%%/*}"
    if [ -z "$transport" ]; then transport="git"; fi
    ;;
  */.orc-worktrees/"$exec_id"|*/.orc-worktrees/"$exec_id"/*)
    if [ -z "$transport" ]; then transport="worktree"; fi
    ;;
esac
if [ -z "$commit" ] && [ -n "$path_commit" ]; then commit="$path_commit"; fi
[ -n "$transport" ] || die "execution_transport is required (git|worktree); silent worktree fallback is removed"

case "$transport" in
  git)
    [[ "$commit" =~ ^[0-9a-fA-F]{40}$ ]] || die "transport=git requires a 40-hex commit (got '${commit:-<empty>}')"
    commit="${commit,,}"
    ;;
  worktree)
    # worktree-транспорт не несёт commit: игнорировать молча нельзя, поэтому
    # просто не передаём его (runner требует отсутствие поля).
    commit=""
    ;;
  *) die "invalid transport: $transport (allowed: git|worktree)" ;;
esac

# Gate bundle digest is part of provenance: an empty digest lets the stand
# /healthz lie about which gate bundle produced the verdict. Fail closed at the
# client instead of silently deploying an unbound preview.
gate_digest="${NEXUS_GATE_BUNDLE_DIGEST:-${ORC_GATE_BUNDLE_DIGEST:-${ORC_GATE_TOOLS_DIGEST:-${PREVIEW_GATE_BUNDLE_DIGEST:-}}}}"
gate_digest="${gate_digest,,}"
[[ "$gate_digest" =~ ^sha256:[0-9a-f]{64}$ ]] || die "gate_bundle_digest is required (sha256:<64hex>); set NEXUS_GATE_BUNDLE_DIGEST/ORC_GATE_BUNDLE_DIGEST"

# Очередь: явная настройка → контейнерный bind-mount → хостовый путь.
# Отсутствие очереди = no-op (клиент не создаёт каталоги, которых не просили).
if [ -n "${STAND_RUNNER_QUEUE:-}" ]; then
  queue="$STAND_RUNNER_QUEUE"
elif [ -d /app/orc-repos/.deploy-queue ]; then
  queue="/app/orc-repos/.deploy-queue"
elif [ -n "${HOME:-}" ] && [ -d "$HOME/orc-repos/.deploy-queue" ]; then
  queue="$HOME/orc-repos/.deploy-queue"
else
  echo "stand-runner-client: deploy queue not configured/found — no-op" >&2
  exit 0
fi

timeout_s="${STAND_RUNNER_TIMEOUT:-1800}"
[[ "$timeout_s" =~ ^[0-9]+$ ]] || timeout_s=1800

mkdir -p -- "$queue"
dir="$queue/$exec_id"
mkdir -p -- "$dir"
chmod 700 -- "$dir"

# Свежий запрос: подчищаем артефакты прошлого прогона (клиент пишет первым,
# до появления req.json runner каталог не трогает).
rm -f -- "$dir/res.json" "$dir/status.json" "$dir/.done"
umask 077
: > "$dir/run.log"
chmod 600 -- "$dir/run.log"

# Feature scope is part of the request: the host runner executes gates with
# `env -i`, so without it multi-feature repos lose ORC_FEATURE_DIR and
# _feature_dir.py becomes ambiguous (api-mode E2E instead of UI).
feature_dir="${ORC_FEATURE_DIR:-}"
feature_id="${FEATURE_ID:-}"
case "$feature_dir" in
  /*|..|../*|*/../*|*/..) feature_dir="" ;;
  *[\"\\]*) feature_dir="" ;;
esac
case "$feature_id" in
  *[\"\\]*) feature_id="" ;;
esac

ts="$(date -u +%FT%TZ)"
tmp="$dir/.req.json.$$"
if [ "$transport" = "git" ]; then
  printf '{"execution_id":"%s","project_id":"%s","command":"%s","transport":"git","commit":"%s","gate_bundle_digest":"%s","feature_dir":"%s","feature_id":"%s","ts":"%s"}\n' \
    "$exec_id" "$project_id" "$command" "$commit" "$gate_digest" "$feature_dir" "$feature_id" "$ts" > "$tmp"
else
  printf '{"execution_id":"%s","project_id":"%s","command":"%s","transport":"worktree","gate_bundle_digest":"%s","feature_dir":"%s","feature_id":"%s","ts":"%s"}\n' \
    "$exec_id" "$project_id" "$command" "$gate_digest" "$feature_dir" "$feature_id" "$ts" > "$tmp"
fi
chmod 600 -- "$tmp"
mv -f -- "$tmp" "$dir/req.json"

deadline=$(( $(date +%s) + timeout_s ))
offset=0

flush_log() {
  local size
  [ -f "$dir/run.log" ] || return 0
  size="$(stat -c %s -- "$dir/run.log" 2>/dev/null || echo 0)"
  if [ "$size" -gt "$offset" ]; then
    tail -c +"$((offset + 1))" -- "$dir/run.log" || true
    offset="$size"
  fi
}

while :; do
  flush_log
  if [ -f "$dir/res.json" ]; then
    flush_log
    rc="$(python3 -c 'import json,sys
try:
    d=json.load(open(sys.argv[1], encoding="utf-8"))
    v=d.get("rc", 1)
    print(int(v) if isinstance(v, int) else 1)
except Exception:
    print(1)' "$dir/res.json" 2>/dev/null || echo 1)"
    exit "$rc"
  fi
  if [ "$(date +%s)" -ge "$deadline" ]; then
    echo "stand-runner-client: timeout ${timeout_s}s waiting for ${exec_id} (queue=$queue)" >&2
    exit 124
  fi
  sleep 1
done
