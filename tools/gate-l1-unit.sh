#!/usr/bin/env bash
# gate-l1-unit: build+vet+unit tests с машинным test-baseline ровно на 5 ID.
# Любой новый red (или build/vet/panic) → fail-close. go test не отключается.
set -uo pipefail

TOP="$(pwd)"
ALLOWED="$(cat "$TOP/tools/conformance-baseline.txt")"

# app-раскладка: backend/go.mod; не наследовать go.work родительского клона
GO_ROOT="."
if [ -f "$TOP/path1.project.json" ]; then
  GO_ROOT="$(python3 - "$TOP/path1.project.json" <<'PYCFG'
import json,sys
try:
    d=json.load(open(sys.argv[1]))
    roots=(d.get("detectors") or {}).get("go_roots") or ["."]
    print(roots[0] if isinstance(roots,list) and roots else ".")
except Exception:
    print(".")
PYCFG
)"
fi
if [ "$GO_ROOT" != "." ] && [ -d "$TOP/$GO_ROOT" ]; then
  cd "$TOP/$GO_ROOT"
fi
export GOWORK=off

# ── Hermetic unit gate (F199-CANARY-4) ──────────────────────────────────────
# Unit-гейт не должен ходить в БД: ORC-env может нести DSN стенда/сервера.
# Снимаем ВСЕ известные DB/DSN-переменные, унаследованные из окружения.
# Явный DSN для integration-тестов передаётся ТОЛЬКО в отдельный гейт
# (tools/check-integration-on-stand.sh, env:VAR аренды) — не здесь.
unset TEST_DATABASE_URL HP_TEST_DATABASE_URL TEST_DELETER_DATABASE_URL \
      HP_TEST_DELETER_DATABASE_URL ORC_DB_URL DATABASE_URL \
      PGDATABASE PGHOST PGPORT PGUSER PGPASSWORD PGSERVICE PGOPTIONS
# ORC runtime toggles меняют поведение кода (reviewer-hook маршрутизирует
# reviewer-spawn и требует author identity). Unit-тесты обязаны видеть
# поведение по умолчанию, а не настройки живого сервера.
unset ORC_REVIEWER_HOOK ORC_REVIEWER_RUNTIME_WAIVER ORC_ACCEPT_PROOF_REF

# Signed host-run evidence (trusted runner key + trusted history).
if [ -d /app/orc-repos ]; then
  ev=doc/идеи/orc32-contract-release/units/s20a-l1-host-run.json
  if [ -f "$ev" ] && python3 tools/verify-host-evidence.py "$ev" tools/conformance-baseline.txt; then
    echo "gate-l1-unit: PASS (signed host-run evidence)"
    exit 0
  fi
fi

go build ./... || { echo "gate-l1-unit: go build failed"; exit 1; }
go vet ./... || { echo "gate-l1-unit: go vet failed"; exit 1; }

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
go test ./... -json >"$tmp" 2>&1
rc=$?
if [ "$rc" -eq 0 ]; then
  echo "gate-l1-unit: PASS (all tests green)"
  exit 0
fi

python3 - "$tmp" "$ALLOWED" <<'PY'
import json,sys
path, allowed_raw = sys.argv[1], sys.argv[2]
allowed = {x.strip() for x in allowed_raw.splitlines() if x.strip()}
failed=set(); pkg_tests={}; pkg_fail=set()
for line in open(path, encoding='utf-8', errors='replace'):
    line=line.strip()
    if not line.startswith('{'): continue
    try: ev=json.loads(line)
    except Exception: continue
    if ev.get('Action')=='fail':
        pkg=ev.get('Package','?')
        if ev.get('Test'):
            failed.add(ev['Test']); pkg_tests.setdefault(pkg,set()).add(ev['Test'])
        else:
            pkg_fail.add(pkg)
extra=sorted(failed-allowed)
if extra:
    print("gate-l1-unit: FAIL new red tests:", ", ".join(extra)); sys.exit(1)
bad_pkgs=[]
for pkg in sorted(pkg_fail):
    tests=pkg_tests.get(pkg,set())
    if not tests or not tests.issubset(allowed):
        bad_pkgs.append(pkg)
if bad_pkgs:
    print("gate-l1-unit: FAIL package-level failures:", ", ".join(bad_pkgs)); sys.exit(1)
print("gate-l1-unit: PASS (baseline reds only: %s)" % ", ".join(sorted(failed)))
for t in sorted(failed): print("FAILED: " + t)
PY
