#!/usr/bin/env bash
# F198 · deploy approval gate (ADR-KIT-094 D11).
#
# Проверяет подписанный Nexus assertion для subject=deploy и потребляет его
# ПЕРЕД необратимым шагом. Манифест релиза — JSON, который owner видел в
# карточке (tag/commit/env/image_digest); digest пересчитывается локально из
# файла и сверяется с assertion.
#
#   APPROVAL_REF=... PROJECT_ID=... BRANCH=release/1.2 \
#   MANIFEST=deploy/release-manifest.json tools/check-deploy-approval.sh
#
# Обязательные: APPROVAL_REF, PROJECT_ID, BRANCH, MANIFEST, NEXUS_APPROVAL_TOKEN.
# Необязательные: TRUST_BUNDLE, CONSUMER, NEXUS_REST_URL, APPROVALCTL.
# Для risk=high манифест обязан содержать image_digest.
set -euo pipefail

fail() { echo "deploy-approval: DENY: $*" >&2; exit 1; }

: "${APPROVAL_REF:?deploy-approval: APPROVAL_REF is required}"
: "${PROJECT_ID:?deploy-approval: PROJECT_ID is required}"
: "${BRANCH:?deploy-approval: BRANCH is required}"
: "${MANIFEST:?deploy-approval: MANIFEST is required}"

TRUST_BUNDLE="${TRUST_BUNDLE:-.nexus/trust/approval.pub}"
CONSUMER="${CONSUMER:-deploy:${EXECUTION_ID:-manual}}"
APPROVALCTL="${APPROVALCTL:-go run ./tools/approvalctl}"

[ -f "$APPROVAL_REF" ] || fail "assertion not found: $APPROVAL_REF"
[ -f "$TRUST_BUNDLE" ] || fail "trust bundle not found: $TRUST_BUNDLE"
[ -f "$MANIFEST" ] || fail "manifest not found: $MANIFEST"
[ -n "${NEXUS_APPROVAL_TOKEN:-}" ] || fail "NEXUS_APPROVAL_TOKEN is required (consume is fail-closed)"

if ! command -v python3 >/dev/null 2>&1; then
  fail "python3 is required to inspect the release manifest"
fi

# High-risk releases must pin the image digest (D11). A tag alone is mutable.
if grep -q '"risk"[[:space:]]*:[[:space:]]*"high"' "$MANIFEST"; then
  python3 - "$MANIFEST" <<'PY' || fail "high-risk manifest must contain image_digest"
import json, sys
m = json.load(open(sys.argv[1]))
if not m.get("image_digest"):
    raise SystemExit(1)
PY
fi

# shellcheck disable=SC2086
exec $APPROVALCTL consume \
  -assertion "$APPROVAL_REF" \
  -bundle "$TRUST_BUNDLE" \
  -project "$PROJECT_ID" \
  -subject deploy \
  -branch "$BRANCH" \
  -payload "$MANIFEST" \
  -consumer "$CONSUMER"
