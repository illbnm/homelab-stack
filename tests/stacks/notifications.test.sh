#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Notifications Tests
# Services: ntfy, Apprise
# =============================================================================

COMPOSE_FILE="$BASE_DIR/stacks/notifications/docker-compose.yml"

# ===========================================================================
# Level 1 — Configuration Integrity
# ===========================================================================
if [[ "${TEST_LEVEL:-0}" -eq 0 || "${TEST_LEVEL:-0}" -le 1 ]]; then
  test_group "Notifications — Configuration"

  assert_compose_valid "$COMPOSE_FILE"
fi

# ===========================================================================
# Level 1 — Container Health
# ===========================================================================
if [[ "${TEST_LEVEL:-0}" -eq 0 || "${TEST_LEVEL:-0}" -le 1 ]]; then
  test_group "Notifications — Container Health"

  assert_container_running "ntfy"
  assert_container_healthy "ntfy"
  assert_container_not_restarting "ntfy"

  assert_container_running "apprise"
  assert_container_healthy "apprise"
  assert_container_not_restarting "apprise"
fi

# ===========================================================================
# Level 2 — HTTP Endpoints
# ===========================================================================
if [[ "${TEST_LEVEL:-0}" -eq 0 || "${TEST_LEVEL:-0}" -ge 2 ]]; then
  test_group "Notifications — HTTP Endpoints"

  # ntfy health endpoint
  assert_http_200 "http://localhost:2586/v1/health" \
    "ntfy /v1/health"

  # Apprise status
  assert_http_ok "http://localhost:8000" \
    "Apprise web UI"
fi

# ===========================================================================
# Level 3 — Interconnection
# ===========================================================================
if [[ "${TEST_LEVEL:-0}" -eq 0 || "${TEST_LEVEL:-0}" -ge 3 ]]; then
  test_group "Notifications — Interconnection"

  assert_container_in_network "ntfy" "proxy"
  assert_container_in_network "apprise" "proxy"

  # Test ntfy can receive a message (publish to a test topic)
  if is_container_running "ntfy"; then
    ntfy_response=$(curl -sf -o /dev/null -w '%{http_code}' \
      -X POST "http://localhost:2586/homelab-test" \
      -d "Integration test ping" 2>/dev/null || echo "000")
    if [[ "$ntfy_response" =~ ^[23] ]]; then
      _record_pass "ntfy accepts publish to test topic"
    else
      _record_fail "ntfy accepts publish to test topic" "HTTP ${ntfy_response}"
    fi
  else
    skip_test "ntfy accepts publish to test topic" "ntfy not running"
  fi
fi
