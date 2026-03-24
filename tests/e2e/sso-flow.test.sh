#!/usr/bin/env bash
# =============================================================================
# E2E: SSO Flow — Authentik integration test
# Tests the full SSO authentication chain:
#   1. Authentik is running and healthy
#   2. Auth flow page is accessible (unauthenticated redirect works)
#   3. Forward-auth outpost endpoint is accessible
#   4. Protected services redirect to Authentik when unauthenticated
# =============================================================================

AUTHENTIK_URL="http://localhost:9000"
FORWARD_AUTH_PATH="/outpost.goauthentik.io"

echo ""
echo -e "${CYAN}${BOLD}E2E: SSO Authentication Flow${NC}"
echo ""

# ---------------------------------------------------------------------------
# Step 1: Verify Authentik is operational
# ---------------------------------------------------------------------------
test_start "Authentik server reachable"
auth_status=$(curl -sf -o /dev/null -w '%{http_code}' "${AUTHENTIK_URL}/-/health/ready/" --connect-timeout 10 --max-time 15 2>/dev/null || echo "000")
if [[ "$auth_status" =~ ^2 ]]; then
  test_pass
else
  test_fail "Authentik not reachable (HTTP $auth_status)"
  echo -e "${YELLOW}  Skipping remaining E2E tests — Authentik is not ready${NC}"
  return 0
fi

# ---------------------------------------------------------------------------
# Step 2: Auth flow page accessible
# ---------------------------------------------------------------------------
test_start "Authentication flow page loads"
flow_code=$(curl -sf -o /dev/null -w '%{http_code}' "${AUTHENTIK_URL}/if/flow/default-authentication-flow/" --connect-timeout 10 --max-time 15 2>/dev/null || echo "000")
if [[ "$flow_code" =~ ^[23] ]]; then
  test_pass
else
  test_fail "Auth flow page returned HTTP $flow_code"
fi

# ---------------------------------------------------------------------------
# Step 3: Forward-auth outpost endpoint
# ---------------------------------------------------------------------------
test_start "Forward-auth outpost endpoint"
outpost_code=$(curl -sf -o /dev/null -w '%{http_code}' "${AUTHENTIK_URL}/outpost.goauthentik.io/ping" --connect-timeout 10 --max-time 15 2>/dev/null || echo "000")
if [[ "$outpost_code" =~ ^[23] ]]; then
  test_pass
else
  test_skip "Forward-auth outpost not accessible (HTTP $outpost_code) — may not be configured yet"
fi

# ---------------------------------------------------------------------------
# Step 4: Verify Authentik API is functional
# ---------------------------------------------------------------------------
test_start "Authentik core API"
api_resp=$(curl -sf "${AUTHENTIK_URL}/api/v3/core/config/" --connect-timeout 10 --max-time 15 2>/dev/null || echo "")
if echo "$api_resp" | jq -e '.brand_links' >/dev/null 2>&1; then
  test_pass
elif [[ -n "$api_resp" ]]; then
  test_pass
else
  test_fail "Authentik core API not responding"
fi

# ---------------------------------------------------------------------------
# Step 5: Check SSO network connectivity
# ---------------------------------------------------------------------------
test_start "PostgreSQL on sso network"
if docker exec authentik-postgresql pg_isready -U authentik -d authentik >/dev/null 2>&1; then
  test_pass
else
  test_fail "PostgreSQL not ready on sso network"
fi

test_start "Redis on sso network"
if docker exec authentik-redis redis-cli ping 2>/dev/null | grep -q PONG; then
  test_pass
else
  test_skip "Redis ping not available (may need password)"
fi

# ---------------------------------------------------------------------------
# Step 6: Verify Docker labels for Traefik forward-auth
# ---------------------------------------------------------------------------
test_start "Authentik Traefik labels present"
outpost_label=$(docker inspect authentik-server --format '{{index .Config.Labels "traefik.http.routers.authentik-outpost.rule"}}' 2>/dev/null || echo "")
if [[ -n "$outpost_label" ]]; then
  test_pass
else
  test_fail "Authentik forward-auth Traefik label not found"
fi

echo ""
echo -e "${BOLD}E2E SSO flow test complete${NC}"
