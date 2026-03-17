#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Notifications Stack Tests
# =============================================================================
# Tests: Gotify, Ntfy, Apprise
# =============================================================================

# ---------------------------------------------------------------------------
# Level 1 — Container Health
# ---------------------------------------------------------------------------

test_gotify_running() {
  assert_container_running "gotify"
}

test_gotify_healthy() {
  assert_container_healthy "gotify" 60
}

test_ntfy_running() {
  assert_container_running "ntfy"
}

test_ntfy_healthy() {
  assert_container_healthy "ntfy" 60
}

test_apprise_running() {
  assert_container_running "apprise"
}

test_apprise_healthy() {
  assert_container_healthy "apprise" 60
}

# ---------------------------------------------------------------------------
# Level 2 — HTTP Endpoints
# ---------------------------------------------------------------------------

test_gotify_api_version() {
  assert_http_200 "http://localhost:8080/version" 30
}

test_gotify_health() {
  assert_http_200 "http://localhost:8080/health" 30
}

test_ntfy_health() {
  assert_http_200 "http://localhost:8081/v1/health" 30
}

test_ntfy_publish_test() {
  # Test publishing a message to ntfy
  local code
  code=$(curl -s -o /dev/null -w '%{http_code}' \
    -X POST "http://localhost:8081/homelab-test" \
    -H "Title: Integration Test" \
    -d "Test message from integration tests" \
    2>/dev/null || echo "000")

  if [[ "${code}" == "200" ]]; then
    _assert_pass "ntfy publish endpoint responds with 200"
  else
    _assert_fail "ntfy publish returned HTTP ${code}, expected 200"
  fi
}

test_apprise_health() {
  assert_http_200 "http://localhost:8000/status" 30
}

# ---------------------------------------------------------------------------
# Level 3 — Inter-Service Communication
# ---------------------------------------------------------------------------

test_gotify_can_create_message() {
  if [[ -z "${GOTIFY_TOKEN:-}" ]]; then
    _assert_skip "GOTIFY_TOKEN not set"
    return 0
  fi

  local result
  result=$(curl -s -X POST \
    "http://localhost:8080/message?token=${GOTIFY_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{"title":"Test","message":"Integration test","priority":1}' \
    2>/dev/null || echo '{}')

  assert_json_key_exists "${result}" ".id"
}

# ---------------------------------------------------------------------------
# Level 1 — Configuration
# ---------------------------------------------------------------------------

test_notifications_compose_valid() {
  local compose_file="${PROJECT_ROOT}/stacks/notifications/docker-compose.yml"

  if [[ ! -f "${compose_file}" ]]; then
    _assert_skip "Notifications compose file not found"
    return 0
  fi

  assert_compose_valid "${compose_file}"
}
