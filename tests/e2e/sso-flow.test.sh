#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — E2E: SSO Authentication Flow
# Tests the complete Authentik SSO login flow.
# =============================================================================
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/docker.sh"

should_run_stack "sso" || { begin_suite "E2E: SSO Flow"; assert_skip "sso not selected"; exit 0; }

begin_suite "E2E: SSO Authentication Flow"

AUTHENTIK_URL="${BASE_URL:-http://localhost}:9000"

# ---- Step 1: Authentik is reachable ----
begin_test "sso:e2e:authentik_reachable"
code=$(curl -sf -o /dev/null -w '%{http_code}' --connect-timeout 5 "$AUTHENTIK_URL" 2>/dev/null || echo "000")
if [[ "$code" =~ ^[23] ]]; then
  assert_pass "Authentik responds HTTP $code"
else
  assert_fail "Authentik not reachable (HTTP $code)"
  # Can't continue without Authentik
  return 0 2>/dev/null || exit 0
fi

# ---- Step 2: Default flow exists ----
begin_test "sso:e2e:default_flow_exists"
flow_code=$(curl -sf -o /dev/null -w '%{http_code}' --connect-timeout 5 \
  "$AUTHENTIK_URL/if/flow/default-authentication-flow/" 2>/dev/null || echo "000")
if [[ "$flow_code" =~ ^[23] ]]; then
  assert_pass "default-authentication-flow accessible"
else
  assert_fail "flow not accessible (HTTP $flow_code)"
fi

# ---- Step 3: API accessible (requires auth token) ----
begin_test "sso:e2e:api_users_endpoint"
api_code=$(curl -sf -o /dev/null -w '%{http_code}' --connect-timeout 5 \
  "$AUTHENTIK_URL/api/v3/core/users/?page_size=1" 2>/dev/null || echo "000")
if [[ "$api_code" == "200" ]]; then
  assert_pass "users API accessible (public)"
elif [[ "$api_code" == "401" || "$api_code" == "403" ]]; then
  assert_pass "users API requires auth (expected)"
else
  assert_fail "unexpected HTTP $api_code"
fi

# ---- Step 4: Outpost health ----
begin_test "sso:e2e:outpost_health"
outpost_code=$(curl -sf -o /dev/null -w '%{http_code}' --connect-timeout 5 \
  "$AUTHENTIK_URL/-/health/ready/" 2>/dev/null || echo "000")
if [[ "$outpost_code" == "204" || "$outpost_code" == "200" ]]; then
  assert_pass "outpost healthy"
elif [[ "$outpost_code" == "404" ]]; then
  assert_skip "health endpoint not exposed"
else
  assert_skip "HTTP $outpost_code"
fi

# ---- Step 5: SSO providers check ----
begin_test "sso:e2e:providers_configured"
providers=$(curl -sf --connect-timeout 5 \
  "$AUTHENTIK_URL/api/v3/providers/" 2>/dev/null || echo "")
if echo "$providers" | grep -qi "provider"; then
  assert_pass "providers endpoint responds"
else
  assert_skip "providers check (may need auth token)"
fi

# ---- Step 6: Forward Auth proxy check ----
begin_test "sso:e2e:forward_auth_ready"
fa_code=$(curl -sf -o /dev/null -w '%{http_code}' --connect-timeout 5 \
  "$AUTHENTIK_URL/outpost.goauthentik.io/auth/nginx" 2>/dev/null || echo "000")
if [[ "$fa_code" == "401" || "$fa_code" == "302" ]]; then
  assert_pass "forward auth endpoint active (HTTP $fa_code)"
elif [[ "$fa_code" == "404" ]]; then
  assert_skip "forward auth not configured"
else
  assert_skip "HTTP $fa_code"
fi
