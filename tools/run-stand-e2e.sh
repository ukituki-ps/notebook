#!/usr/bin/env bash
# s20c / gate-e2e-preview — E2E по сценариям НА АРЕНДОВАННОМ СТЕНДЕ.
# Запускается АГЕНТОМ (или host-runner'ом из RUNNER_CODE_ROOT).
#
# Разделение ролей (как в deploy-preview-stand):
#   CODE_ROOT   — платформенные tools/ (этот скрипт), НЕ app-репо;
#   TARGET_ROOT — app worktree исполнения (.orc-eval/<E>/<commit> или
#                 .orc-worktrees/<E>); здесь фича, preview-deploy.json-контекст
#                 и e2e.command проекта.
#
# Режимы прогона:
#   * e2e.command (path1.project.json) или PREVIEW_E2E_CMD — проектная команда
#     (API smoke для backend-only проекта; UI-команда для фронтенда). Стенд,
#     URL и каталог доказательств передаются env'ами.
#   * иначе — Playwright по спеке фичи (UI-проект): браузерный контур берётся
#     откуда есть (host/container).
#
# Артефакты (execution root, переживает пересоздание eval worktree):
#   * preview-verdict.json      — для gate-e2e-preview;
#   * e2e-report.json           — API-only: exit/stdout-digest прогона;
#   * для UI: <feature_dir>/screenshots + scenario-evidence/evidence-manifest.
#   $1 = execution_id.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODE_ROOT="$(cd "$DIR/.." && pwd)"
INVOKE_DIR="$(pwd -P 2>/dev/null || pwd)"
TARGET_ROOT="${ORC_TARGET_ROOT:-$INVOKE_DIR}"
PY="$DIR/_path1_project.py"
ROOT="$TARGET_ROOT"
exec_id="${1:-${EXECUTION_ID:-}}"
base="${NEXUS_BASE_URL:-http://nexus:9182}"
tok="${NEXUS_TOKEN:-${ORC_NEXUS_TOKEN:-}}"

fail() { echo "run-stand-e2e: FAIL — $1" >&2; exit 1; }

# execution root: git → .orc-eval/<E>; worktree → корень проекта; явно — env.
execution_root="${ORC_EXECUTION_ROOT:-}"
if [ -z "$execution_root" ]; then
  case "$TARGET_ROOT" in
    */.orc-eval/*/*) execution_root="${TARGET_ROOT%/*}" ;;
    */.orc-worktrees/*) execution_root="${TARGET_ROOT%%/.orc-worktrees/*}" ;;
    *) execution_root="$TARGET_ROOT" ;;
  esac
fi
[ -n "$execution_root" ] && [ -d "$execution_root" ] || execution_root="$TARGET_ROOT"
preview_deploy_json="$execution_root/preview-deploy.json"
preview_verdict_json="$execution_root/preview-verdict.json"
# A stale verdict from a previous run must never satisfy the gate after this
# run fails to write a fresh one.
rm -f -- "$preview_verdict_json"

# Platform-owned gate digest. ORC sets ORC_GATE_*; the deploy wrapper sets
# NEXUS_*/PREVIEW_*. Accept all, but require a valid sha256 before any verdict.
ENV_GATE="${NEXUS_GATE_BUNDLE_DIGEST:-${PREVIEW_GATE_BUNDLE_DIGEST:-${ORC_GATE_BUNDLE_DIGEST:-${ORC_GATE_TOOLS_DIGEST:-}}}}"
ENV_GATE="${ENV_GATE,,}"
[[ "$ENV_GATE" =~ ^sha256:[0-9a-f]{64}$ ]] || fail "gate_bundle_digest is required (sha256:<64hex>); refusing an unbound verdict"
export NEXUS_GATE_BUNDLE_DIGEST="$ENV_GATE"

# Портируемость: конфиг проекта — из TARGET_ROOT (app-репо).
cfg() { python3 "$PY" --root "$TARGET_ROOT" --line "$1" 2>/dev/null || true; }
FE_DIR="$(cfg e2e.frontend_dir)"
FE_CMD="$(cfg e2e.command)"

# Host-runner bridge: в контейнере исполнителя нет node/npx/docker — уходим на
# хост-раннер (та же очередь, что у s20b). STAND_RUNNER_EXECUTE=1 ставит только хост.
if [ "${STAND_RUNNER_EXECUTE:-}" != "1" ] && ! command -v npx >/dev/null 2>&1 && ! command -v docker >/dev/null 2>&1; then
  transport="${ORC_EXECUTION_TRANSPORT:-${STAND_RUNNER_TRANSPORT:-}}"
  commit="${ORC_EVALUATED_SHA:-}"
  if [ -z "$transport" ]; then
    case "$TARGET_ROOT" in
      */.orc-eval/*/*) transport="git" ;;
      */.orc-worktrees/*) transport="worktree" ;;
      *) echo "run-stand-e2e: FAIL — execution transport is not declared and TARGET_ROOT is not a known ORC layout; pass ORC_EXECUTION_TRANSPORT=git|worktree" >&2; exit 2 ;;
    esac
  fi
  if [ -z "$commit" ] && [ "$transport" = "git" ]; then
    commit="$(git -C "$TARGET_ROOT" rev-parse HEAD 2>/dev/null || true)"
  fi
  # Pass the feature scope as a repo-relative path: the host runner executes
  # with `env -i`, and an absolute /app/... path is meaningless there.
  feature_rel="${ORC_FEATURE_DIR:-}"
  case "$feature_rel" in
    /*) case "$feature_rel" in "$TARGET_ROOT"/*) feature_rel="${feature_rel#"$TARGET_ROOT"/}" ;; *) feature_rel="" ;; esac ;;
  esac
  case "$feature_rel" in ..|../*) feature_rel="" ;; esac
  exec env STAND_RUNNER_TRANSPORT="$transport" STAND_RUNNER_COMMIT="$commit" \
    ORC_FEATURE_DIR="$feature_rel" FEATURE_ID="${FEATURE_ID:-}" \
    bash "$DIR/stand-runner-client.sh" "$exec_id" e2e-preview
fi

# ── 1. Стенд из аренды (dev Nexus) ──────────────────────────────────────────
url=""; stand_name=""
if [ -n "$exec_id" ] && [ -n "$tok" ]; then
  lease="$(curl -fsS -m 12 -H "Authorization: Bearer $tok" \
      "${base}/api/v1/stands/leases?execution_id=${exec_id}" 2>/dev/null || true)"
  url="$(printf '%s' "$lease" | python3 -c 'import sys,json;print((json.load(sys.stdin).get("lease") or {}).get("stand_url",""))' 2>/dev/null || true)"
  stand_name="$(printf '%s' "$lease" | python3 -c 'import sys,json;print((json.load(sys.stdin).get("lease") or {}).get("stand_name",""))' 2>/dev/null || true)"
fi
# Fallback (F-A-S20C-01): привилегированная аренда недоступна → стенд из preview-deploy.
if [ -z "$url" ] && [ -f "$preview_deploy_json" ]; then
  url="$(python3 -c 'import sys,json;print(json.load(open(sys.argv[1])).get("url","") or "")' "$preview_deploy_json" 2>/dev/null || true)"
  [ -n "$url" ] && echo "run-stand-e2e: warn — аренда недоступна, стенд из preview-deploy.json: $url" >&2
fi
[ -n "$url" ] || fail "нет арендованного стенда (execution=${exec_id:-?})"
# Дев-контур: test1/test2, никогда prod.
case "$stand_name" in
  ""|test1|test2) ;;
  *) fail "стенд '$stand_name' не из dev-allowlist (test1|test2)" ;;
esac
case "$url" in
  *prod*) fail "prod-стенд запрещён в dev: $url" ;;
esac

# ── 2. Проектная команда / UI-контур ────────────────────────────────────────
FEAT_DIR_ABS=""
scen_path=""
if [ -n "${ORC_FEATURE_DIR:-}" ]; then
  case "$ORC_FEATURE_DIR" in /*) FEAT_DIR_ABS="$ORC_FEATURE_DIR" ;; *) FEAT_DIR_ABS="$TARGET_ROOT/$ORC_FEATURE_DIR" ;; esac
  scen_path="$FEAT_DIR_ABS/scenarios.json"
elif [ -f "$DIR/_feature_dir.py" ]; then
  _f="$(python3 "$DIR/_feature_dir.py" --root "$TARGET_ROOT" --name scenarios.json 2>/dev/null | xargs -r dirname || true)"
  if [ -n "$_f" ]; then
    case "$_f" in /*) FEAT_DIR_ABS="$_f" ;; *) FEAT_DIR_ABS="$TARGET_ROOT/$_f" ;; esac
    scen_path="$FEAT_DIR_ABS/scenarios.json"
  fi
fi
api_mode=0
if [ -n "${PREVIEW_E2E_CMD:-}" ] || [ -n "$FE_CMD" ]; then
  if [ -z "$scen_path" ] || [ ! -f "$scen_path" ]; then api_mode=1; fi
fi
if [ "$api_mode" = "0" ]; then
  [ -n "$FEAT_DIR_ABS" ] || fail "не удалось определить каталог фичи (ORC_FEATURE_DIR / git-diff)"
  [ -d "$FEAT_DIR_ABS" ] || fail "каталог фичи не найден: $FEAT_DIR_ABS"
  [ -d "$TARGET_ROOT/$FE_DIR" ] || [ -n "${PREVIEW_E2E_CMD:-}" ] || [ -n "$FE_CMD" ] \
    || fail "нет $FE_DIR и не задана команда E2E (e2e.command / PREVIEW_E2E_CMD)"
fi

# ── 3. Семафор (mkdir атомарен) ─────────────────────────────────────────────
SEM_DIR="${E2E_SEM_DIR:-/tmp/archkit-e2e-sem}"; mkdir -p "$SEM_DIR"
MAX="${E2E_MAX_CONCURRENCY:-2}"; WAIT="${E2E_WAIT_SECONDS:-900}"
find "$SEM_DIR" -maxdepth 1 -name 'token-*' -mmin +120 -exec rm -rf {} + 2>/dev/null || true
TOKEN=""; deadline=$(( $(date +%s) + WAIT ))
while [ -z "$TOKEN" ]; do
  for s in $(seq 1 "$MAX"); do
    if mkdir "$SEM_DIR/token-$s" 2>/dev/null; then TOKEN="$SEM_DIR/token-$s"; echo "$$" >"$TOKEN/pid"; break; fi
  done
  [ -n "$TOKEN" ] && break
  if [ "$(date +%s)" -ge "$deadline" ]; then fail "не дождался слота E2E (max=$MAX за ${WAIT}s)"; fi
  sleep 2
done
trap 'rm -rf "$TOKEN"' EXIT INT TERM

# ── 4. Каталоги прогона ─────────────────────────────────────────────────────
RUN_STARTED_EPOCH="$(date +%s)"
RUN_TMP="$(mktemp -d "${TMPDIR:-/tmp}/archkit-e2e-XXXXXX")"
OUT_DIR="${E2E_OUT_DIR:-$execution_root/.e2e-artifacts/${exec_id:-run}-$(date -u +%H%M%S)}"
SHOTS_DIR="${E2E_SHOTS_DIR:-${FEAT_DIR_ABS:-$execution_root}/screenshots}"
mkdir -p "$OUT_DIR" "$SHOTS_DIR"; export TMPDIR="$RUN_TMP"
if [ "$api_mode" = "0" ]; then
  rm -f "$SHOTS_DIR"/*.png "$SHOTS_DIR"/*.jpg "$SHOTS_DIR"/*.jpeg 2>/dev/null || true
fi

export STAND_ADMIN_EMAIL="${STAND_ADMIN_EMAIL:-admin@stand.test}"
export STAND_ADMIN_PASSWORD="${STAND_ADMIN_PASSWORD:-stand-admin}"
export TEST_ADMIN_EMAIL="${TEST_ADMIN_EMAIL:-$STAND_ADMIN_EMAIL}"
export TEST_ADMIN_PASSWORD="${TEST_ADMIN_PASSWORD:-$STAND_ADMIN_PASSWORD}"
export E2E_BASE_URL="$url" PREVIEW_BASE_URL="$url" E2E_SHOTS_DIR="$SHOTS_DIR"
export PATH1_FEATURE_DIR="${FEAT_DIR_ABS:-$execution_root}"
export ORC_EXECUTION_ROOT="$execution_root" ORC_TARGET_ROOT="$TARGET_ROOT"

verdict() { # $1 status (verified|e2e_failed), $2 artifact_digest
  PV_STATUS="$1" PV_ARTIFACT="${2:-}" PV_URL="$url" PV_EXEC="${exec_id:-run}" \
  PV_OUT="$SHOTS_DIR" PV_REF="${dep_ref:-$(git -C "$TARGET_ROOT" rev-parse --short HEAD 2>/dev/null || echo)}" \
  PV_BUNDLE="$dep_bundle" PV_MODE="$([ "$api_mode" = 1 ] && echo api || echo ui)" \
  python3 - "$preview_deploy_json" "$preview_verdict_json" <<'PY'
import json, os, sys, datetime
dep_p, out_p = sys.argv[1], sys.argv[2]
try:
    dep = json.load(open(dep_p, encoding="utf-8"))
    if not isinstance(dep, dict):
        dep = {}
except Exception:
    dep = {}
status = os.environ.get("PV_STATUS", "")
env_gate = str(os.environ.get("NEXUS_GATE_BUNDLE_DIGEST") or os.environ.get("PREVIEW_GATE_BUNDLE_DIGEST") or "").strip().lower()
dep_gate = str(dep.get("gate_bundle_digest") or "").strip().lower()
if env_gate and dep_gate and env_gate != dep_gate:
    sys.exit("run-stand-e2e: FAIL — preview-deploy gate_bundle_digest != platform gate bundle")
if not dep_gate:
    sys.exit("run-stand-e2e: FAIL — preview-deploy.json has no gate_bundle_digest")
result = "pass" if status == "verified" else "fail"
now = datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
out = {
    "schema": "orc.preview-verdict/v1",
    "execution_id": os.environ.get("PV_EXEC", ""),
    "evaluated_sha": str(dep.get("evaluated_sha") or dep.get("commit") or ""),
    "stand": str(dep.get("stand") or ""),
    "stand_image_digest": str(dep.get("stand_image_digest") or ""),
    "gate_bundle_digest": dep_gate,
    "build_args_hash": str(dep.get("build_args_hash") or ""),
    "artifact_digest": os.environ.get("PV_ARTIFACT", ""),
    "url": os.environ.get("PV_URL", ""),
    "checked_at": now,
    "result": result,
    "mode": os.environ.get("PV_MODE", ""),
    "target": os.environ.get("PV_URL", ""),
    "status": status,
    "execution": os.environ.get("PV_EXEC", ""),
    "ref": os.environ.get("PV_REF", ""),
    "bundle": os.environ.get("PV_BUNDLE", ""),
    "out_dir": os.environ.get("PV_OUT", ""),
    "evidence_manifest_sha256": os.environ.get("PV_ARTIFACT", ""),
    "ts": now,
}
json.dump(out, open(out_p, "w", encoding="utf-8"), ensure_ascii=False)
PY
}

# ref/bundle выкаченного билда (preview-deploy.json).
dep_ref="$(python3 -c 'import json,sys
try: print(json.load(open(sys.argv[1])).get("ref","") or "")
except Exception: print("")' "$preview_deploy_json" 2>/dev/null || true)"
dep_bundle="$(python3 -c 'import json,sys
try: print(json.load(open(sys.argv[1])).get("bundle","") or "")
except Exception: print("")' "$preview_deploy_json" 2>/dev/null || true)"
if [ -z "$dep_bundle" ]; then
  dep_bundle="$(curl -kfsS -L -m 12 "${url%/}/" 2>/dev/null | grep -oE 'assets/index-[A-Za-z0-9_-]+\.js' | head -1 || true)"
fi

# The verdict must bind to the platform bundle, not to app-written provenance.
dep_gate="$(python3 -c 'import json,sys
try: print(json.load(open(sys.argv[1])).get("gate_bundle_digest","") or "")
except Exception: print("")' "$preview_deploy_json" 2>/dev/null || true)"
dep_gate="${dep_gate,,}"
[ "$dep_gate" = "$ENV_GATE" ] || fail "preview-deploy gate_bundle_digest='${dep_gate:-<empty>}' != platform '${ENV_GATE}'"

# ── 5. API-only: проектная команда как smoke ────────────────────────────────
if [ "$api_mode" = "1" ]; then
  cmd="${PREVIEW_E2E_CMD:-$FE_CMD}"
  [ -n "$cmd" ] || fail "API-режим без e2e.command"
  echo "run-stand-e2e: exec=${exec_id} target=$url mode=api command=$(printf '%s' "$cmd" | head -c 120)"
  report="$execution_root/e2e-report.json"
  out="$( cd "$TARGET_ROOT" && bash -c "$cmd" 2>&1 )"
  rc=$?
  printf '%s\n' "$out" | tail -c 20000 > "$OUT_DIR/e2e-stdout.log" 2>/dev/null || true
  ART_SHA="sha256:$(printf '%s' "$out" | sha256sum | awk '{print $1}')"
  python3 - "$report" "$rc" "$ART_SHA" "$url" "$exec_id" "$OUT_DIR" <<'PY'
import json, sys, datetime
out_p, rc, sha, url, eid, outdir = sys.argv[1:7]
now = datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
json.dump({"schema":"orc.e2e-report/v1","execution_id":eid,"url":url,"exit_code":int(rc),
           "artifact_digest":sha,"out_dir":outdir,"checked_at":now},
          open(out_p,"w",encoding="utf-8"), ensure_ascii=False)
PY
  if [ "$rc" -ne 0 ]; then
    verdict e2e_failed "$ART_SHA"
    echo "BLOCK: stand E2E (api) failed rc=$rc" >&2
    exit 1
  fi
  verdict verified "$ART_SHA" || fail "preview-verdict not written (gate digest/verdict error)"
  [ -s "$preview_verdict_json" ] || fail "preview-verdict not written"
  echo "gate-e2e-preview (stand/api): OK — $preview_verdict_json"
  exit 0
fi

# ── 6. UI-контур (Playwright) ───────────────────────────────────────────────
e2e_mode="${E2E_MODE:-auto}"
if [ "$e2e_mode" = "auto" ]; then
  e2e_mode="local"
  shell_bin="$(ls -d "$HOME"/.cache/ms-playwright/chromium_headless_shell-*/chrome-headless-shell-linux64/chrome-headless-shell 2>/dev/null | tail -1 || true)"
  if [ ! -x "$shell_bin" ] || [ "$(ldd "$shell_bin" 2>/dev/null | grep -c 'not found')" -gt 0 ]; then
    if command -v docker >/dev/null 2>&1; then e2e_mode="container"; else e2e_mode="local"; fi
  fi
fi
echo "run-stand-e2e: exec=${exec_id} target=$url slot=${TOKEN##*/} mode=$e2e_mode feature=${FEAT_DIR_ABS:-}"

PLAY=("npx" "--no-install" "playwright" "test"
      "--workers=${E2E_WORKERS:-1}" "--output=$OUT_DIR" "--reporter=line")

e2e_specs="${E2E_SPECS:-}"
if [ -z "$e2e_specs" ] && [ -z "${PREVIEW_E2E_CMD:-}" ] && [ -z "$FE_CMD" ]; then
  _dbase="${E2E_DIFF_BASE:-origin/main}"
  if git -C "$TARGET_ROOT" rev-parse -q --verify "$_dbase" >/dev/null 2>&1; then
    while IFS= read -r _s; do
      [ -n "$_s" ] || continue
      e2e_specs="$e2e_specs ${_s#"$FE_DIR"/}"
    done < <(git -C "$TARGET_ROOT" diff --name-only "${_dbase}...HEAD" -- "$FE_DIR/tests/e2e" 2>/dev/null \
             | grep -E '\.(spec|test)\.(ts|js|tsx)$' || true)
  fi
fi
if [ -n "$e2e_specs" ]; then
  # shellcheck disable=SC2206
  PLAY+=($e2e_specs)
  echo "run-stand-e2e: спеки фичи:${e2e_specs}"
fi

if [ -n "${PREVIEW_E2E_CMD:-}" ]; then
  RUN_CMD=(bash -c "$PREVIEW_E2E_CMD")
elif [ -n "$FE_CMD" ]; then
  RUN_CMD=(bash -c "$FE_CMD")
elif [ "$e2e_mode" = "container" ]; then
  E2E_IMAGE="${E2E_CONTAINER_IMAGE:-mcr.microsoft.com/playwright:v1.53.0-noble}"
  RUN_CMD=(docker run --rm --network host --init
    -e PLAYWRIGHT_BROWSERS_PATH=/root/.cache/ms-playwright
    -e E2E_BASE_URL="$url" -e PREVIEW_BASE_URL="$url"
    -e E2E_SHOTS_DIR="$SHOTS_DIR"
    -e STAND_ADMIN_EMAIL -e STAND_ADMIN_PASSWORD -e TEST_ADMIN_EMAIL -e TEST_ADMIN_PASSWORD
    -e TMPDIR=/tmp
    -v "$HOME/.cache/ms-playwright:/root/.cache/ms-playwright"
    -v "$TARGET_ROOT:$TARGET_ROOT" -w "$TARGET_ROOT/$FE_DIR"
    "$E2E_IMAGE" "${PLAY[@]}")
else
  RUN_CMD=(env "E2E_BASE_URL=$url" "PREVIEW_BASE_URL=$url" "E2E_SHOTS_DIR=$SHOTS_DIR" "${PLAY[@]}")
fi

if [ "$e2e_mode" = "container" ] || [ -n "${PREVIEW_E2E_CMD:-}" ] || [ -n "$FE_CMD" ]; then
  ( cd "$TARGET_ROOT" && "${RUN_CMD[@]}" )
else
  ( cd "$TARGET_ROOT/$FE_DIR" && "${RUN_CMD[@]}" )
fi
rc=$?
if [ "$rc" -ne 0 ]; then
  verdict e2e_failed
  echo "BLOCK: stand E2E failed" >&2
  exit 1
fi

if [ -f "$DIR/pngdiff.py" ] && [ -d "$SHOTS_DIR" ]; then
  shots=()
  while IFS= read -r _p; do shots+=("$_p"); done < <(find "$SHOTS_DIR" -maxdepth 1 -name '*.png' | sort)
  if [ "${#shots[@]}" -ge 2 ] && ! python3 "$DIR/pngdiff.py" --thresh 0.005 "${shots[@]}" >/dev/null 2>&1; then
    verdict e2e_failed
    echo "gate-e2e-preview: FAIL — near-duplicate скриншоты сценариев (pngdiff)." >&2
    exit 1
  fi
fi

# scenario-evidence по фактическим артефактам (UI).
E2E_EXECUTION_ID="$exec_id" E2E_OUT_REF="$OUT_DIR" E2E_STARTED="$RUN_STARTED_EPOCH" python3 - "$TARGET_ROOT" "$FEAT_DIR_ABS" "$SHOTS_DIR" <<'PYEOF' || exit 1
import hashlib, json, os, sys
root, feat, shots = sys.argv[1], sys.argv[2], sys.argv[3]
started = int(os.environ.get("E2E_STARTED") or 0)
sc_path = os.path.join(feat, "scenarios.json")
if not os.path.isfile(sc_path):
    print(f"run-stand-e2e: FAIL — нет {sc_path} (scenarios.json обязателен)", file=sys.stderr)
    sys.exit(1)
scen = (json.load(open(sc_path, encoding="utf-8")).get("scenarios") or [])
if not scen:
    print("run-stand-e2e: FAIL — scenarios.json пуст", file=sys.stderr)
    sys.exit(1)
items, missing = [], []
for s in scen:
    sid = s.get("id") or ""
    # oracle=unit: the state is not reachable on the stand; require a real
    # test_ref instead of a screenshot (same contract as gate-evidence-authentic).
    # This is the supported alternative to decorative screenshots that only
    # exist to pass pngdiff.
    if str(s.get("oracle") or "").strip().lower() == "unit":
        tref = str(s.get("test_ref") or "").strip()
        tf = tref.split("::", 1)[0].strip()
        if not tf:
            print(f"run-stand-e2e: FAIL — {sid}: oracle=unit без test_ref", file=sys.stderr)
            sys.exit(1)
        if not (os.path.isabs(tf) or os.path.exists(os.path.join(root, tf))):
            print(f"run-stand-e2e: FAIL — {sid}: test_ref не найден: {tref}", file=sys.stderr)
            sys.exit(1)
        items.append({"id": sid, "status": "pass", "oracle": "unit", "test_ref": tref})
        continue
    shot = ""
    sha = ""
    for ext in (".png", ".jpg", ".jpeg"):
        cand = os.path.join(shots, sid + ext)
        if os.path.isfile(cand) and os.path.getsize(cand) > 0:
            mtime = int(os.path.getmtime(cand))
            if started and mtime < started:
                print(f"run-stand-e2e: FAIL — скриншот {sid} не свежий: {cand}", file=sys.stderr)
                sys.exit(1)
            sha = hashlib.sha256(open(cand, "rb").read()).hexdigest()
            shot = os.path.relpath(cand, root)
            break
    if shot:
        items.append({"id": sid, "status": "pass", "screenshot": shot, "sha256": sha,
                      "e2e_ref": os.environ.get("E2E_OUT_REF", "")})
    else:
        missing.append(sid)
if missing:
    print("run-stand-e2e: FAIL — нет скриншотов для сценариев: " + ", ".join(missing), file=sys.stderr)
    sys.exit(1)
out = os.path.join(feat, "scenario-evidence.json")
json.dump({"execution": os.environ.get("E2E_EXECUTION_ID", ""), "scenarios": items},
          open(out, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print(f"run-stand-e2e: scenario-evidence.json → {out} ({len(items)} сценариев)")
PYEOF

EVID_MANIFEST="$FEAT_DIR_ABS/evidence-manifest.json"
python3 - "$TARGET_ROOT" "$FEAT_DIR_ABS" <<'PY' || exit 1
import hashlib, json, os, sys
root, feat = sys.argv[1], sys.argv[2]
files = {}
p = os.path.join(feat, "scenario-evidence.json")
if os.path.isfile(p):
    files[os.path.relpath(p, root)] = hashlib.sha256(open(p, "rb").read()).hexdigest()
shots = os.path.join(feat, "screenshots")
if os.path.isdir(shots):
    for f in sorted(os.listdir(shots)):
        if f.lower().endswith((".png", ".jpg", ".jpeg")):
            fp = os.path.join(shots, f)
            files[os.path.relpath(fp, root)] = hashlib.sha256(open(fp, "rb").read()).hexdigest()
out = os.path.join(feat, "evidence-manifest.json")
json.dump({"files": files}, open(out, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print(f"run-stand-e2e: evidence-manifest.json → {out} ({len(files)} файлов)")
PY
MANIFEST_SHA="$(sha256sum "$EVID_MANIFEST" | awk '{print $1}')"
# F-RUN-02b: UI-evidence обязан пережить пересоздание eval-worktree.
# Копируем в execution root (<E>); gate-e2e-preview делает оттуда fallback.
if [ -n "${FEAT_DIR_ABS:-}" ] && [ "$execution_root" != "$TARGET_ROOT" ]; then
  _feat_rel="${FEAT_DIR_ABS#"$TARGET_ROOT"/}"
  case "$_feat_rel" in
    "$FEAT_DIR_ABS"|/*|..|../*) _feat_rel="" ;;
  esac
  if [ -n "$_feat_rel" ]; then
    _edir="$execution_root/$_feat_rel"
    mkdir -p "$_edir/screenshots"
    cp -f "$FEAT_DIR_ABS/scenario-evidence.json" "$_edir/" 2>/dev/null || true
    cp -f "$EVID_MANIFEST" "$_edir/" 2>/dev/null || true
    find "$SHOTS_DIR" -maxdepth 1 -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' \) \
      -exec cp -f {} "$_edir/screenshots/" \; 2>/dev/null || true
    echo "run-stand-e2e: evidence persisted → $_edir"
  fi
fi
verdict verified "$MANIFEST_SHA" || fail "preview-verdict not written (gate digest/verdict error)"
[ -s "$preview_verdict_json" ] || fail "preview-verdict not written"

echo "gate-e2e-preview (stand): OK"
exit 0
