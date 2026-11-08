#!/usr/bin/env bash
# F198 · allowlist approval gate (ADR-KIT-094 D10).
#
# Проверяет подписанный Nexus assertion для subject=allowlist и одноразово
# потребляет его. tree_digest считается локально из git (тот же алгоритм, что
# у прежнего trust signer'а), payload — точные байты allowlist-файла.
#
# Запуск из command-гейта процесса/CI:
#   EXECUTION_ID=E1234 BASE_SHA=<base> APPROVAL_REF=... tools/check-tools-approval.sh
#
# Обязательные переменные:
#   APPROVAL_REF   — путь к assertion-envelope (JSON)
#   PROJECT_ID     — UUID проекта Nexus
#   BRANCH         — ветка, на которой действует подтверждение
#   BASE_SHA       — база ревью (напр. origin/main)
#   NEXUS_APPROVAL_TOKEN — project token для consume
# Необязательные:
#   SOURCE_SHA (default HEAD), TRUST_BUNDLE (.nexus/trust/approval.pub),
#   ALLOWLIST (.orc-trust/tools-allowlist.yaml), REPO (.), NEXUS_REST_URL,
#   APPROVALCTL (команда CLI; default `go run ./tools/approvalctl`)
#
# Fail-closed: любая отсутствующая переменная/несовпадение — exit 1.
set -euo pipefail

fail() { echo "approval-gate: DENY: $*" >&2; exit 1; }

: "${APPROVAL_REF:?approval-gate: APPROVAL_REF is required}"
: "${PROJECT_ID:?approval-gate: PROJECT_ID is required}"
: "${BRANCH:?approval-gate: BRANCH is required}"
: "${BASE_SHA:?approval-gate: BASE_SHA is required}"

SOURCE_SHA="${SOURCE_SHA:-HEAD}"
TRUST_BUNDLE="${TRUST_BUNDLE:-.nexus/trust/approval.pub}"
ALLOWLIST="${ALLOWLIST:-.orc-trust/tools-allowlist.yaml}"
REPO="${REPO:-.}"
CONSUMER="${CONSUMER:-orc:${EXECUTION_ID:-manual}/allowlist}"
APPROVALCTL="${APPROVALCTL:-go run ./tools/approvalctl}"

[ -f "$APPROVAL_REF" ] || fail "assertion not found: $APPROVAL_REF"
[ -f "$TRUST_BUNDLE" ] || fail "trust bundle not found: $TRUST_BUNDLE"
[ -f "$ALLOWLIST" ] || fail "allowlist not found: $ALLOWLIST"
[ -n "${NEXUS_APPROVAL_TOKEN:-}" ] || fail "NEXUS_APPROVAL_TOKEN is required (consume is fail-closed)"

# shellcheck disable=SC2086
exec $APPROVALCTL consume \
  -assertion "$APPROVAL_REF" \
  -bundle "$TRUST_BUNDLE" \
  -project "$PROJECT_ID" \
  -subject allowlist \
  -branch "$BRANCH" \
  -repo "$REPO" \
  -base "$BASE_SHA" \
  -source "$SOURCE_SHA" \
  -allowlist "$ALLOWLIST" \
  -consumer "$CONSUMER"
