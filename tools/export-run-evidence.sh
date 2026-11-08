#!/usr/bin/env bash
# export-run-evidence — делает доказательства прогона durable (audit F003/E5438, P-3).
#
# Проблема: canary/findings/proofs писались в data/audit/runs/<E>/ внутри ворктри прогона,
# а preview-deploy.json/preview-verdict.json — в корень ворктри. После уборки ворктри (или
# при аудите по ветке) доказательств нет: нельзя постфактум подтвердить, что проба относится
# к выкаченному билду (у F003 e2e_ref вёл на пустой host-каталог вне репо).
#
# Решение: копия прогонных доказательств ВНУТРЬ артефактов фичи (<feature>/evidence/run-<E>/)
# + MANIFEST.json с sha256. Артефакты коммитятся вместе с фичей.
#
# Использование: bash tools/export-run-evidence.sh <execution_id> [--root DIR] [--feature-dir DIR]
# Идемпотентно (перезапись). Отсутствие части источников — не ошибка (warn); отсутствие ВСЕХ —
# ошибка (экспортировать нечего).
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DIR/.." && pwd)"
exec_id=""; FEATURE_DIR=""
while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    --feature-dir) FEATURE_DIR="$2"; shift 2 ;;
    *) exec_id="${1:-}"; shift ;;
  esac
done
[ -n "$exec_id" ] || { echo "export-run-evidence: FAIL — не задан execution_id" >&2; exit 1; }

# Каталог фичи: явный → _feature_dir.py (по report.md/plan.md) → единственная фича в дереве.
if [ -z "$FEATURE_DIR" ]; then
  for probe in report.md plan.md scenarios.json mobile-evidence.json; do
    p="$(python3 "$DIR/_feature_dir.py" --root "$ROOT" --name "$probe" 2>/dev/null || true)"
    [ -n "$p" ] && { FEATURE_DIR="$(dirname "$p")"; break; }
  done
fi
if [ -z "$FEATURE_DIR" ] || [ ! -d "$FEATURE_DIR" ]; then
  cands=( "$ROOT"/doc/идеи/*/ )
  n=0; for c in "${cands[@]}"; do [ -d "$c" ] && n=$((n+1)); done
  if [ "$n" -eq 1 ] && [ -d "${cands[0]}" ]; then FEATURE_DIR="${cands[0]%/}"
  else echo "export-run-evidence: FAIL — не определён каталог фичи (задай --feature-dir)" >&2; exit 1; fi
fi

dest="$FEATURE_DIR/evidence/run-$exec_id"
mkdir -p "$dest"
copied=0
copy_one() { # copy_one <src> <rel_dest_name>
  local src="$1" name="$2"
  [ -e "$src" ] || return 1
  mkdir -p "$dest/$(dirname "$name")"
  cp -f "$src" "$dest/$name" && { echo "  ← $name"; copied=$((copied+1)); }
}
# run-артефакты детекторов/канареек
run_dir=""
[ -d "$ROOT/data/audit/runs/$exec_id" ] && run_dir="$ROOT/data/audit/runs/$exec_id"
if [ -n "$run_dir" ]; then
  for f in "$run_dir"/*; do
    [ -e "$f" ] || continue
    copy_one "$f" "audit/$(basename "$f")"
  done
else
  echo "export-run-evidence: warn — нет data/audit/runs/$exec_id (детекторы/канарейки не писались?)" >&2
fi
# стендовые доказательства прогона
for f in preview-deploy.json preview-verdict.json; do
  copy_one "$ROOT/$f" "$f"
done

if [ "$copied" -eq 0 ]; then
  echo "export-run-evidence: FAIL — нечего экспортировать для $exec_id" >&2
  exit 1
fi
# MANIFEST.json: rel-путь + sha256 + размер (проверяется gate-evidence-durable)
python3 - "$dest" "$exec_id" <<'PY'
import hashlib, json, os, sys, datetime
dest, exec_id = sys.argv[1], sys.argv[2]
files = []
for dirpath, _d, names in os.walk(dest):
    for n in sorted(names):
        if n == "MANIFEST.json":
            continue
        fp = os.path.join(dirpath, n)
        h = hashlib.sha256()
        with open(fp, "rb") as fh:
            for chunk in iter(lambda: fh.read(1 << 16), b""):
                h.update(chunk)
        files.append({"path": os.path.relpath(fp, dest), "sha256": h.hexdigest(),
                      "size": os.path.getsize(fp)})
man = {"execution_id": exec_id, "generated_at": datetime.datetime.now(datetime.timezone.utc)
       .strftime("%Y-%m-%dT%H:%M:%SZ"), "files": files}
with open(os.path.join(dest, "MANIFEST.json"), "w", encoding="utf-8") as fh:
    json.dump(man, fh, ensure_ascii=False, indent=1)
print(f"export-run-evidence: {len(files)} файл(ов) → evidence/run-{exec_id}/MANIFEST.json")
PY
echo "export-run-evidence: OK ($dest)"
