#!/usr/bin/env bash
# =============================================================================
# Notifications Stack Tests
# =============================================================================

# ntfy
assert_container_running ntfy
assert_container_healthy ntfy 30
assert_http_200 "http://localhost:2586/v1/health" 10

# Verify ntfy health response
test_start "ntfy health JSON"
ntfy_health=$(curl -sf "http://localhost:2586/v1/health" 2>/dev/null || echo "")
if echo "$ntfy_health" | grep -qi "healthy"; then
  test_pass
else
  test_fail "ntfy health endpoint did not return healthy"
fi

# Apprise
assert_container_running apprise
assert_container_healthy apprise 30
assert_http_200 "http://localhost:8000/" 10

# Verify apprise API is accessible
test_start "Apprise API root"
apprise_resp=$(curl -sf -o /dev/null -w '%{http_code}' "http://localhost:8000/" 2>/dev/null || echo "000")
if [[ "$apprise_resp" =~ ^2 ]]; then
  test_pass
else
  test_fail "Apprise API returned HTTP $apprise_resp"
fi
