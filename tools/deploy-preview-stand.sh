#!/usr/bin/env bash
# deploy-preview-stand (ADR-KIT-091) — ВЫКАТ ветки на арендованный стенд.
# Запускается АГЕНТОМ (s20b) на хосте, где есть docker (dev), НЕ из контейнера ORC;
# либо host-runner'ом из RUNNER_CODE_ROOT с явным ORC_TARGET_ROOT.
#
# Разделение ролей:
#   CODE_ROOT   — неизменяемое дерево платформы (tools/, deploy/); отсюда
#                 исполняется ЭТОТ скрипт, здесь лежат платформенные тулы.
#   TARGET_ROOT — app worktree исполнения: .orc-eval/<E>/<commit> (git) или
#                 .orc-worktrees/<E> (worktree). Здесь app-код и его
#                 path1.project.json/deploy-скрипты.
# Platform tools в app worktree НЕ копируются (E2703 follow-up).
#
# $1 = execution_id (или EXECUTION_ID). Резолвит стенд из аренды, выкатывает
# HEAD TARGET_ROOT проектной командой, пишет preview-deploy.json (для гейта) и DSN.
#
# Раскладка артефактов (execution root):
#   git      → <project>/.orc-eval/<E>/preview-deploy.json  (НЕ commit-subdir;
#              иначе артефакт исчезает вместе с одноразовым worktree)
#   worktree → <project>/preview-deploy.json                (как раньше)
#   явно     → $ORC_EXECUTION_ROOT/preview-deploy.json
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODE_ROOT="$(cd "$DIR/.." && pwd)"
INVOKE_DIR="$(pwd -P 2>/dev/null || pwd)"
TARGET_ROOT="${ORC_TARGET_ROOT:-$INVOKE_DIR}"
PY="$DIR/_path1_project.py"

exec_id="${1:-${EXECUTION_ID:-}}"
base="${NEXUS_BASE_URL:-http://nexus:9182}"
tok="${NEXUS_TOKEN:-${ORC_NEXUS_TOKEN:-}}"

# transport/commit — для моста в очередь и для provenance.
transport="${ORC_EXECUTION_TRANSPORT:-${STAND_RUNNER_TRANSPORT:-}}"
commit="${ORC_EVALUATED_SHA:-${STAND_RUNNER_COMMIT:-}}"
if [ -z "$transport" ]; then
  case "$TARGET_ROOT" in
    */.orc-eval/*/*) transport="git" ;;
    */.orc-worktrees/*) transport="worktree" ;;
    *) echo "deploy-preview-stand: FAIL — execution transport is not declared and TARGET_ROOT is not a known ORC layout; pass ORC_EXECUTION_TRANSPORT=git|worktree" >&2; exit 2 ;;
  esac
fi
if [ "$transport" = "git" ]; then
  [[ "$commit" =~ ^[0-9a-fA-F]{40}$ ]] || { echo "deploy-preview-stand: FAIL — transport=git requires evaluated_sha (40-hex), got '${commit:-<empty>}'" >&2; exit 2; }
  commit="${commit,,}"
else
  commit=""
fi

# Gate bundle provenance is platform-owned: normalize it BEFORE the host-runner
# bridge and before stand_cmd runs. An empty/invalid value must never reach the
# stand, otherwise /healthz claims an unbound preview.
if [ -z "${NEXUS_GATE_BUNDLE_DIGEST:-}" ]; then
  NEXUS_GATE_BUNDLE_DIGEST="${PREVIEW_GATE_BUNDLE_DIGEST:-${ORC_GATE_BUNDLE_DIGEST:-${ORC_GATE_TOOLS_DIGEST:-}}}"
fi
NEXUS_GATE_BUNDLE_DIGEST="${NEXUS_GATE_BUNDLE_DIGEST,,}"
[[ "$NEXUS_GATE_BUNDLE_DIGEST" =~ ^sha256:[0-9a-f]{64}$ ]] || {
  echo "deploy-preview-stand: FAIL — gate_bundle_digest is required (sha256:<64hex>); refusing to deploy an unbound preview" >&2
  exit 2
}
export NEXUS_GATE_BUNDLE_DIGEST
export PREVIEW_GATE_BUNDLE_DIGEST="$NEXUS_GATE_BUNDLE_DIGEST"

# Host-runner bridge (F180): в ORC-контейнере нет docker/ssh/docker.sock.
# Без docker и без runner-режима уходим в клиент общей очереди; исполняет
# запрос tools/stand-runner.sh на хосте (pr01, user ukituki). transport/commit
# передаём явно — runner не угадывает путь.
if ! command -v docker >/dev/null 2>&1 && [ "${STAND_RUNNER_EXECUTE:-}" != "1" ]; then
  exec env STAND_RUNNER_TRANSPORT="$transport" STAND_RUNNER_COMMIT="$commit" \
    bash "$DIR/stand-runner-client.sh" "$exec_id"
fi

cfg() { python3 "$PY" --root "$TARGET_ROOT" --line "$1" 2>/dev/null || true; }

command -v docker >/dev/null 2>&1 || { echo "deploy-preview-stand: docker недоступен (запусти на docker-хосте)" >&2; exit 1; }
[ -d "$TARGET_ROOT" ] || { echo "deploy-preview-stand: TARGET_ROOT не найден: $TARGET_ROOT" >&2; exit 1; }
resolved="$(curl -fsS -m 12 -H "Authorization: Bearer $tok" \
    "${base}/api/v1/stands/leases?execution_id=${exec_id}" 2>/dev/null \
  | python3 -c 'import sys,json;l=(json.load(sys.stdin).get("lease") or {});print(l.get("stand_name","")+"\t"+l.get("stand_url",""))')"
stand="${resolved%%$'\t'*}"; url="${resolved##*$'\t'}"
[ -n "$stand" ] || { echo "deploy-preview-stand: нет арендованного стенда (execution=${exec_id})" >&2; exit 1; }

ref="$(git -C "$TARGET_ROOT" rev-parse --short HEAD)"
head_full="$(git -C "$TARGET_ROOT" rev-parse HEAD)"
[ -n "$ref" ] && [ -n "$head_full" ] || { echo "deploy-preview-stand: TARGET_ROOT не git-дерево: $TARGET_ROOT" >&2; exit 1; }
echo "deploy-preview-stand: target=$TARGET_ROOT transport=$transport stand=$stand ref=$ref commit=$head_full"

# W5/E2703: target repo — из project context TARGET_ROOT. App-репо обязан
# объявить свою команду; fallback на archkit layout запрещён.
stand_cmd="$(cfg deploy.stand_command)"
if [ -z "$stand_cmd" ]; then
  echo "deploy-preview-stand: FAIL — deploy.stand_command не объявлен в TARGET_ROOT/path1.project.json (app-репо; archkit default запрещён; E2703)" >&2
  exit 2
fi
# Optional explicit target project pin: не даём выкатить не тот репозиторий.
want_pid="$(cfg deploy.project_id)"
if [ -n "$want_pid" ]; then
  target_real="$(cd "$TARGET_ROOT" && pwd -P)"
  case "$target_real" in
    *"/$want_pid"|*"/$want_pid/"*) : ;;
    *) echo "deploy-preview-stand: FAIL — target_repo_mismatch: TARGET_ROOT=$target_real не принадлежит project_id=$want_pid" >&2; exit 2 ;;
  esac
fi

# ── execution root: per-run артефакты, переживающие удаление eval worktree ──
execution_root="${ORC_EXECUTION_ROOT:-}"
if [ -z "$execution_root" ]; then
  case "$TARGET_ROOT" in
    */.orc-eval/*/*) execution_root="${TARGET_ROOT%/*}" ;;          # .orc-eval/<E>
    */.orc-worktrees/*) execution_root="${TARGET_ROOT%%/.orc-worktrees/*}" ;;
    *) execution_root="$TARGET_ROOT" ;;
  esac
fi
[ -n "$execution_root" ] && [ -d "$execution_root" ] || execution_root="$TARGET_ROOT"
preview_out="$execution_root/preview-deploy.json"

stand_cmd="${stand_cmd//\{stand\}/$stand}"
stand_cmd="${stand_cmd//\{ref\}/$ref}"
stand_cmd="${stand_cmd//\{execution_id\}/$exec_id}"
# Проектная команда исполняется из app-репо и не должна видеть nexus-креды.
( cd "$TARGET_ROOT" && env -u NEXUS_TOKEN -u ORC_NEXUS_TOKEN -u NEXUS_BASE_URL bash -c "$stand_cmd" )

# bundle выкаченного образа (p.5 аудита F003/E5438): без него UI-пробу нельзя
# привязать к билду. Для API-only проекта bundle пуст (warn, не fail).
bundle="$(curl -kfsS -L -m 12 "${url%/}/" 2>/dev/null | grep -oE 'assets/index-[A-Za-z0-9_-]+\.js' | head -1 || true)"
[ -n "$bundle" ] || echo "deploy-preview-stand: warn — bundle не определён (API-only стенд или нет index.html)" >&2

# ADR-10 / W3.7: preview-deploy несёт digest + полный commit/evaluated_sha.
runtime_dir="$(cfg deploy.runtime_dir)"; [ -n "$runtime_dir" ] || runtime_dir="deploy/stands/.runtime"
prov_deploy="$TARGET_ROOT/$runtime_dir/${stand}/deploy-provenance.json"
prov_build="$TARGET_ROOT/$runtime_dir/${stand}/build-provenance.json"
if ! PREVIEW_RUNTIME_DIR="$runtime_dir" PREVIEW_EXEC_ID="$exec_id" PREVIEW_STAND="$stand" \
   PREVIEW_URL="${url%/}" PREVIEW_REF="$ref" PREVIEW_BUNDLE="$bundle" \
   PREVIEW_HEAD="$head_full" PREVIEW_TRANSPORT="$transport" \
   PREVIEW_TS="$(date -u +%FT%TZ)" \
   python3 - "$prov_deploy" "$prov_build" "$preview_out" <<'PY'
import json, os, re, sys
deploy_p, build_p, out_p = sys.argv[1], sys.argv[2], sys.argv[3]

def load(p):
    try:
        d = json.load(open(p, encoding="utf-8"))
        return d if isinstance(d, dict) else {}
    except Exception:
        return {}

deploy = load(deploy_p)
build = load(build_p)
prov = deploy if deploy.get("image_digest") else (build if build.get("image_digest") else (deploy or build))
digest = str(prov.get("image_digest") or os.environ.get("PREVIEW_STAND_IMAGE_DIGEST") or "").strip()
commit = str(prov.get("commit") or os.environ.get("PREVIEW_STAND_COMMIT") or os.environ.get("PREVIEW_HEAD") or "").strip()
args_hash = str(prov.get("build_args_hash") or os.environ.get("PREVIEW_BUILD_ARGS_HASH") or "").strip()
env_gate = str(os.environ.get("NEXUS_GATE_BUNDLE_DIGEST") or os.environ.get("PREVIEW_GATE_BUNDLE_DIGEST") or "").strip().lower()
prov_gate = str(prov.get("gate_bundle_digest") or "").strip().lower()
if prov_gate and env_gate and prov_gate != env_gate:
    sys.exit("deploy-preview-stand: FAIL — provenance gate_bundle_digest != platform gate bundle")
gate_digest = env_gate or prov_gate
build_ref = str(prov.get("build_ref") or os.environ.get("PREVIEW_BUILD_REF") or os.environ.get("PREVIEW_REF") or "").strip()

if not digest.startswith("sha256:") or len(digest) != len("sha256:") + 64:
    sys.exit("deploy-preview-stand: FAIL — нет image_digest (deploy/build provenance); "
             "preview без digest недопустим (docker tag old new не должен проходить)")
if not commit:
    sys.exit("deploy-preview-stand: FAIL — нет commit/evaluated_sha в provenance")
if not re.fullmatch(r"sha256:[0-9a-f]{64}", gate_digest):
    sys.exit("deploy-preview-stand: FAIL — нет gate_bundle_digest (sha256:<64hex>); "
             "preview без привязки к gate bundle недопустим")
out = {
    "schema": "orc.preview-deploy/v1",
    "execution_id": os.environ.get("PREVIEW_EXEC_ID", ""),
    "stand": os.environ.get("PREVIEW_STAND", ""),
    "url": os.environ.get("PREVIEW_URL", ""),
    "ref": os.environ.get("PREVIEW_REF", ""),
    "commit": commit,
    "evaluated_sha": commit,
    "build_ref": build_ref,
    "stand_image_digest": digest,
    "build_args_hash": args_hash,
    "gate_bundle_digest": gate_digest,
    "transport": os.environ.get("PREVIEW_TRANSPORT", ""),
    "bundle": os.environ.get("PREVIEW_BUNDLE", ""),
    "ts": os.environ.get("PREVIEW_TS", ""),
}
json.dump(out, open(out_p, "w", encoding="utf-8"), ensure_ascii=False)
PY
then
  echo "deploy-preview-stand: FAIL — не удалось записать provenance $preview_out" >&2
  exit 1
fi

# DSN стенда для гейтов прогона (адрес, достижимый из ORC-контейнера).
dsn_cmd="$(cfg deploy.dsn_command)"
runtime_dir="$(cfg deploy.runtime_dir)"; [ -n "$runtime_dir" ] || runtime_dir="deploy/stands/.runtime"
stands_env="$(cfg deploy.stands_env)"; [ -n "$stands_env" ] || stands_env="deploy/stands/stands.env"
# Рантайм-DSN: исходная раскладка (TARGET_ROOT/deploy/stands/.runtime/<stand>/dsn,
# её читает gate-fault-catalog-exec) + копия в execution root, переживающая
# пересоздание одноразового eval worktree.
dsn_file="$TARGET_ROOT/$runtime_dir/${stand}/dsn"
dsn_exec_file="$execution_root/${stand}.dsn"
mkdir -p "$(dirname "$dsn_file")" "$(dirname "$dsn_exec_file")"
_old_umask="$(umask)"; umask 077
if [ -n "$dsn_cmd" ]; then
  dsn_cmd="${dsn_cmd//\{stand\}/$stand}"; dsn_cmd="${dsn_cmd//\{execution_id\}/$exec_id}"
  ( cd "$TARGET_ROOT" && bash -c "$dsn_cmd" ) > "$dsn_file" 2>/dev/null || true
else
  pg_port="$(sed -n "s/^${stand}_PG_PORT=//p" "$TARGET_ROOT/$stands_env" 2>/dev/null | tr -d '[:space:]' || true)"
  dsn_host="${STAND_DSN_HOST:-$(hostname -I 2>/dev/null | awk '{print $1}')}"
  db="nexus_${stand}_test"
  if [ -n "$pg_port" ] && [ -n "$dsn_host" ]; then
    printf 'postgres://%s:%s@%s:%s/%s?sslmode=disable\n' "$db" "$db" "$dsn_host" "$pg_port" "$db" > "$dsn_file" 2>/dev/null || true
  else
    printf 'postgres://%s:%s@stand-%s-postgres:5432/%s?sslmode=disable\n' "$db" "$db" "$stand" "$db" > "$dsn_file" 2>/dev/null || true
  fi
fi
cp -f -- "$dsn_file" "$dsn_exec_file" 2>/dev/null || true
umask "$_old_umask"
echo "deploy-preview-stand: GREEN ($preview_out, target=$TARGET_ROOT, execution_root=$execution_root, dsn=$dsn_file)"
