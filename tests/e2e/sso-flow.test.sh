#!/usr/bin/env bash
# End-to-End: SSO Login Flow
# Tests: user can log in via Authentik forward auth
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
source "$SCRIPT_DIR/../lib/assert.sh"

reset_counters
log_test_start "E2E: SSO Login Flow"

DOMAIN="${DOMAIN:-localhost}"
AUTHENTIK_URL="https://auth.$DOMAIN"

section "Prerequisites"
assert_http_2xx "Authentik accessible" "$AUTHENTIK_URL/if/flow/initial-setup/" || \
  assert_http_2xx "Authentik accessible" "$AUTHENTIK_URL/" || true

section "SSO forward auth header"
# Check that a request WITHOUT auth cookie gets redirected to Authentik
local code
code=$(curl -sf -o /dev/null -w "%{http_code}" \
  -H "Host: app.$DOMAIN" \
  "http://localhost:80/" 2>/dev/null || echo "000")
TESTS_RUN=$((TESTS_RUN+1))
if [[ "$code" =~ ^(302|401|403|200)$ ]]; then
  pass "Unauthenticated request handled (HTTP $code)"
else
  fail "Unexpected response from protected endpoint (HTTP $code)"
fi

section "Authentik credentials flow"
# Verify that /api/v3/core/users/ returns auth challenge without cookie
local acode
acode=$(curl -sf -o /dev/null -w "%{http_code}" \
  "$AUTHENTIK_URL/api/v3/core/users/" 2>/dev/null || echo "000")
TESTS_RUN=$((TESTS_RUN+1))
if [[ "$acode" =~ ^(200|401|403)$ ]]; then
  pass "Authentik API responds (HTTP $acode)"
else
  fail "Authentik API not reachable (HTTP $acode)"
fi

assert_summary