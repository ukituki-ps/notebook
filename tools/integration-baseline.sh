#!/usr/bin/env bash
# Integration test-baseline: ровно 5 known red (T-18,T-20,T-25,T-26,T-27).
# Любой новый red → fail-close; go test не отключается.
set -uo pipefail
# Baseline — свойство ОЦЕНИВАЕМОГО коммита, а не рабочего дерева клона.
# Раньше читался PROJECT_ROOT (git-common-dir → authoring-клона): грязный
# baseline в клоне (5 строк) отменял 24 строки в коммите — приёмка зависела от
# чужого незакоммиченного состояния. Теперь приоритет:
#   1) ORC_EVAL_ROOT (check-integration-on-stand.sh передаёт eval-worktree);
#   2) текущий cwd (гейт исполняется в eval-worktree);
#   3) PROJECT_ROOT — только fallback для legacy-вызовов.
# Выбранный путь и число строк печатаются: иначе причину «19 new red» не видно.
EVAL_ROOT="${ORC_EVAL_ROOT:-$PWD}"
BASELINE=""
for root in "$EVAL_ROOT" "${ORC_PROJECT_ROOT:-}" "$PWD"; do
  [ -n "$root" ] || continue
  for rel in tools/conformance-baseline.txt backend/tools/conformance-baseline.txt; do
    if [ -f "$root/$rel" ]; then BASELINE="$root/$rel"; break 2; fi
  done
done
if [ -z "$BASELINE" ]; then
  echo "integration-baseline: FAIL — baseline не найден (eval_root=${EVAL_ROOT}, cwd=$PWD)" >&2
  exit 1
fi
ALLOWED="$(cat "$BASELINE")"
echo "integration-baseline: root=${BASELINE} lines=$(printf '%s\n' "$ALLOWED" | grep -c .)"
out="$(mktemp)"; trap 'rm -f "$out"' EXIT
bash -c "$1" >"$out" 2>&1; rc=$?
if [ "$rc" -eq 0 ]; then echo "integration-baseline: PASS (all green)"; exit 0; fi
fails="$(grep -oE '^--- FAIL: [A-Za-z0-9_/]+' "$out" | awk '{print $3}' | sort -u)"
if [ -z "$fails" ]; then
  echo "integration-baseline: FAIL (no identifiable test failures; package/build error)"; tail -20 "$out"; exit 1
fi
extra="$(comm -23 <(printf '%s\n' "$fails") <(printf '%s\n' "$ALLOWED" | sort -u))"
if [ -n "$extra" ]; then
  echo "integration-baseline: FAIL new red tests: $(printf '%s' "$extra" | tr '\n' ' ')"; exit 1
fi
echo "integration-baseline: PASS (baseline reds only: $(printf '%s' "$fails" | tr '\n' ' '))"
for t in $fails; do echo "FAILED: $t"; done
