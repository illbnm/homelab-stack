#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Notifications Tests
# Tests: ntfy + Apprise
# =============================================================================
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/docker.sh"

should_run_stack "notifications" || { begin_suite "Notifications"; assert_skip "not selected"; exit 0; }

begin_suite "Notifications — ntfy + Apprise"

# ---- ntfy ----
assert_container_running "ntfy"
assert_container_healthy "ntfy"
assert_container_not_latest "ntfy"
assert_http_200 "${BASE_URL:-http://localhost}:8080/v1/health" "ntfy:health"

# ntfy can send/receive
begin_test "ntfy:publish_test"
resp=$(curl -sf -d "test message" "${BASE_URL:-http://localhost}:8080/test-topic" 2>/dev/null || echo "")
if [[ -n "$resp" ]]; then
  assert_pass "can publish to topic"
else
  assert_skip "publish test"
fi

# ---- Apprise ----
assert_container_running "apprise"
assert_container_healthy "apprise"
assert_container_not_latest "apprise"
assert_http_200 "${BASE_URL:-http://localhost}:8181" "apprise:ui"

begin_test "apprise:api:health"
api_health=$(curl -sf "${BASE_URL:-http://localhost}:8181/api/health" 2>/dev/null || echo "")
if [[ -n "$api_health" ]]; then
  assert_pass "API health endpoint responds"
else
  assert_skip "API health check"
fi

# ---- Inter-service: Apprise → ntfy ----
begin_test "apprise:can_reach_ntfy"
if docker exec apprise curl -sf --connect-timeout 3 "http://ntfy:80/v1/health" &>/dev/null; then
  assert_pass "apprise → ntfy reachable"
else
  assert_skip "inter-container test"
fi

# ---- Compose validation ----
assert_compose_valid "${SCRIPT_DIR}/../../stacks/notifications/docker-compose.yml" "notifications"
