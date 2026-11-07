#!/usr/bin/env bash
# =============================================================================
# canary-run.sh — canary-контур пути 1 (ADR-KIT-090), generic для любого проекта/фичи.
#
# Честная проверка «детектор ЛОВИТ подложенный дефект»: для каждой канарейки
# создаётся ИЗОЛИРОВАННЫЙ git worktree от HEAD (реальная ветка не трогается),
# в копию подкладывается seed-дефект, затем запускается production-детектор и
# ожидается FALL (exit != 0). Только падение детектора = детекция.
#
# Артефакты прогона (data/ — gitignored, не коммитится):
#   data/audit/runs/${RUN_ID}/canary.json        — манифест (canaries + clean_units)
#   data/audit/runs/${RUN_ID}/findings.json      — находки (canary_id + detector_exit)
#   data/audit/runs/${RUN_ID}/proof-execute.json — вывод fault-catalog-check --mode execute
#   data/audit/runs/${RUN_ID}/canary-*.log       — логи детекторов
#
# Нотация канареек — из контракта проекта `path1.project.json`:
#   canaries.items[] = {id, seed, detect}   (shell-команды; {worktree} подставляется)
#   canaries.clean_units[]                  (что остаётся «чистым» в прогоне)
#   canaries.require_dsn (default true)     — требовать ли TEST_DATABASE_URL
#   detectors.catalog_dir (default audit/fault-catalog)
# Пустой список канареек = FAIL (нельзя «пройти» канарейки, ничего не проверив).
#
# Аргумент/$EXECUTION_ID → RUN_ID (run-scoped доказательства). TEST_DATABASE_URL — env
# либо DSN арендованного стенда (env:VAR из /stands/leases).
# =============================================================================
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RUN_ID="${1:-${EXECUTION_ID:-${RUN_ID:-}}}"
[ -n "$RUN_ID" ] || { echo "canary-run: FAIL — не задан RUN_ID (передай execution_id или RUN_ID=…)" >&2; exit 2; }
RUN_DIR="data/audit/runs/${RUN_ID}"
mkdir -p "$RUN_DIR"

CATALOG="$(python3 "$DIR/_path1_project.py" --root "$REPO_ROOT" --line detectors.catalog_dir 2>/dev/null || true)"
[ -n "$CATALOG" ] || CATALOG="audit/fault-catalog"
REQUIRE_DSN="$(python3 "$DIR/_path1_project.py" --root "$REPO_ROOT" --line canaries.require_dsn 2>/dev/null || true)"
[ -n "$REQUIRE_DSN" ] || REQUIRE_DSN="true"

# plan — печатает канарейки из контракта: id \x1f seed \x1f detect (по строке).
plan() {
  python3 - "$REPO_ROOT" "$DIR" <<'PYPLAN'
import json, subprocess, sys
root, d = sys.argv[1], sys.argv[2]
out = subprocess.run(["python3", f"{d}/_path1_project.py", "--root", root,
                      "--get", "canaries.items", "--json"],
                     capture_output=True, text=True).stdout
try:
    items = json.loads(out or "[]") or []
except Exception:
    items = []
for it in items:
    if not isinstance(it, dict):
        continue
    print("\x1f".join([str(it.get("id", "")), str(it.get("seed", "")), str(it.get("detect", ""))]))
PYPLAN
}

PLAN="$(plan)"
if [ -z "${PLAN//[[:space:]]/}" ]; then
  echo "canary-run: FAIL — в path1.project.json не объявлено ни одной канарейки (canaries.items)" >&2
  echo "  Вакуумный проход запрещён: канарейки проверяют, что детекторы РЕАЛЬНО ловят дефекты." >&2
  exit 2
fi

# Идемпотентность: если артефакты прогона уже есть и выглядят валидными (манифест+находки+proof),
# не перегенерируем их на приёмке. Иначе продюсер-гейт (kind: command) перезапускал канарейки
# в окружении БЕЗ DSN стенда и затирал корректный proof «not-executed» (инцидент E8141:
# ORC-контейнер не достаёт PG стенда — другой docker-network). Перегенерация: CANARY_FORCE=1.
if [ "${CANARY_FORCE:-0}" != "1" ] && [ -s "$RUN_DIR/canary.json" ] && [ -s "$RUN_DIR/findings.json" ] && [ -s "$RUN_DIR/proof-execute.json" ]; then
  if python3 - "$RUN_DIR" "$RUN_ID" "$CATALOG" <<'PYEOF2' >/dev/null 2>&1
import json, sys, glob as _g
import yaml as _y
d, run, catalog = sys.argv[1], sys.argv[2], sys.argv[3]
c = json.load(open(f"{d}/canary.json", encoding="utf-8"))
f = json.load(open(f"{d}/findings.json", encoding="utf-8"))
p = json.load(open(f"{d}/proof-execute.json", encoding="utf-8"))
assert c.get("run_id") == run and c.get("canaries"), "manifest run_id/canaries"
ids = {x.get("canary_id") for x in (f.get("findings") or [])}
assert ids and ids == {x.get("id") for x in c["canaries"]}, "findings не покрывают канарейки"
res = p.get("results") or []
assert p.get("ok") is True and res, "proof-execute: ok!=true/пуст"
bad = [x.get("id") for x in res if (x.get("status") or "") != "ok"]
assert not bad, f"детекторы не ok: {bad}"
# Дрейф каталога (review F-CANARY-1): классы, добавленные после proof, при reuse молча не исполнились бы.
cats = set()
for _f in _g.glob(f"{catalog}/*.yaml"):
    _d = _y.safe_load(open(_f, encoding="utf-8"))
    _seq = _d if isinstance(_d, list) else (_d.get("classes") or _d.get("items") or [])
    for _it in _seq:
        if isinstance(_it, dict) and _it.get("id"):
            cats.add(_it["id"])
assert cats and cats <= {x.get("id") for x in res}, f"каталог изменился: нет proof для {sorted(cats - {x.get('id') for x in res})[:4]}"
PYEOF2
  then
    echo "canary-run: reuse — артефакты прогона ${RUN_ID} уже валидны (canary.json/findings.json/proof-execute.json)"
    exit 0
  fi
fi

# Integration-оракулы требуют DSN стенда. Приоритет: env → DSN аренды (env:VAR).
if [ -z "${TEST_DATABASE_URL:-}" ] && [ -n "$RUN_ID" ] && [ -n "${NEXUS_TOKEN:-${ORC_NEXUS_TOKEN:-}}" ]; then
  _ref="$(curl -fsS -m 10 -H "Authorization: Bearer ${NEXUS_TOKEN:-${ORC_NEXUS_TOKEN}}" \
      "${NEXUS_BASE_URL:-http://nexus:9182}/api/v1/stands/leases?execution_id=${RUN_ID}" 2>/dev/null \
    | python3 -c 'import sys,json;print((json.load(sys.stdin).get("lease") or {}).get("stand_dsn_ref",""))' 2>/dev/null || true)"
  case "$_ref" in env:*) TEST_DATABASE_URL="${!_ref#env:}";; "") : ;; *) TEST_DATABASE_URL="$_ref";; esac
fi
# Fallback-дефолт УБРАН (E8141): он молча подставлял чужую БД и глушил DB-детекторы.
if [ "$REQUIRE_DSN" = "true" ] && [ -z "${TEST_DATABASE_URL:-}" ]; then
  echo "canary-run: FAIL — нет TEST_DATABASE_URL (ни env, ни аренда stand_dsn_ref)." >&2
  echo "  Задай DSN стенда: TEST_DATABASE_URL=postgres://<db>:<pw>@<host>:<PORT>/<db>?sslmode=disable" >&2
  echo "  (или canaries.require_dsn=false в path1.project.json, если DB-детекторов нет)" >&2
  exit 2
fi
export TEST_DATABASE_URL="${TEST_DATABASE_URL:-}"

TMPBASE="${TMPDIR:-/tmp}"
WORKTREES=()
cleanup() {
  local wt
  for wt in "${WORKTREES[@]:-}"; do
    [ -n "$wt" ] || continue
    git worktree remove --force "$wt" >/dev/null 2>&1 || true
  done
  git worktree prune >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

EXITS_FILE="$RUN_DIR/.canary-exits"
: > "$EXITS_FILE"

while IFS=$'\x1f' read -r cid seed detect; do
  [ -n "${cid// }" ] || continue
  if [ -z "${seed// }" ] || [ -z "${detect// }" ]; then
    echo "canary-run: FAIL — канарейка '$cid' без seed/detect (path1.project.json)" >&2
    exit 2
  fi
  wt="${TMPBASE}/canary-${cid}-$$"
  rm -rf "$wt"
  git worktree add --detach "$wt" HEAD >/dev/null
  WORKTREES+=("$wt")

  # Seed применяется из КОРНЯ репо (команда канарейки обычно патчит файлы в {worktree}).
  if ! bash -c "${seed//\{worktree\}/$wt}"; then
    echo "canary-run: FAIL — seed канарейки '$cid' не применился (детектор проверять нечем)" >&2
    exit 2
  fi

  rc=0
  ( cd "$wt" && bash -c "$detect" ) >"$RUN_DIR/canary-${cid}.log" 2>&1 || rc=$?
  printf '%s\t%s\n' "$cid" "$rc" >> "$EXITS_FILE"
  echo "canary-run: $cid detector_exit=$rc"
done < <(printf '%s\n' "$PLAN")

# ── Артефакты прогона ───────────────────────────────────────────────────────
python3 - "$RUN_DIR" "$RUN_ID" "$EXITS_FILE" "$DIR" <<'PYART'
import json, os, subprocess, sys
run_dir, run_id, exits_file, d = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
items = []
with open(exits_file, encoding="utf-8") as fh:
    for line in fh:
        cid, _, rc = line.rstrip("\n").partition("\t")
        if cid:
            items.append((cid, int(rc or 0)))
clean = subprocess.run(["python3", f"{d}/_path1_project.py", "--root", os.getcwd(),
                        "--get", "canaries.clean_units", "--json"],
                       capture_output=True, text=True).stdout
try:
    clean_units = json.loads(clean or "[]") or []
except Exception:
    clean_units = []
canary = {"run_id": run_id,
          "canaries": [{"id": cid, "seed": f"canary:{cid}"} for cid, _ in items],
          "clean_units": clean_units}
findings = {"findings": [{"id": cid, "canary_id": cid, "unit_id": f"canary:{cid}", "detector_exit": rc}
                         for cid, rc in items]}
for name, doc in (("canary.json", canary), ("findings.json", findings)):
    with open(os.path.join(run_dir, name), "w", encoding="utf-8") as fh:
        json.dump(doc, fh, ensure_ascii=False, indent=2)
        fh.write("\n")
print(f"wrote {run_dir}/canary.json + findings.json ({len(items)} канареек)")
PYART

# ── proof-execute.json: реальный прогон каталога-оракулов ────────────────────
EXEC_EXIT=0
# Feature-scoped verdicts: na-классы не должны исполняться/валиться в proof
# (иначе proof.ok=false на чужом UI-детекторе у backend-only фичи — F199 s24).
_VERDICTS=""
if [ -n "${ORC_FEATURE_DIR:-}" ] && [ -s "$ORC_FEATURE_DIR/fault-verdicts.json" ]; then
  _VERDICTS="$ORC_FEATURE_DIR/fault-verdicts.json"
elif [ -f "$DIR/_feature_dir.py" ]; then
  _VERDICTS="$(python3 "$DIR/_feature_dir.py" --root "$REPO_ROOT" --name fault-verdicts.json 2>/dev/null || true)"
fi
RUN_ID="$RUN_ID" python3 "$DIR/fault-catalog-check.py" --mode execute \
  --catalog "$CATALOG" --run-id "$RUN_ID" \
  ${_VERDICTS:+--verdicts "$_VERDICTS"} \
  --proof-out "$RUN_DIR/proof-execute.json" >"$RUN_DIR/proof-execute.log" 2>&1 || EXEC_EXIT=$?

# ── Итог ────────────────────────────────────────────────────────────────────
NOT_DETECTED=""
while IFS=$'\t' read -r cid rc; do
  [ -n "$cid" ] || continue
  [ "$rc" -ne 0 ] || NOT_DETECTED="${NOT_DETECTED} ${cid}"
done < "$EXITS_FILE"

if [ -n "$NOT_DETECTED" ]; then
  echo "canary-run: FAIL — детектор НЕ упал на подложенном дефекте (канарейка не найдена):$NOT_DETECTED" >&2
  exit 1
fi
echo "canary-run($RUN_ID): OK — канарейки найдены (детекторы упали на seed-дефектах); fault_catalog_execute_exit=$EXEC_EXIT"
