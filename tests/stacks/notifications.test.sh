#!/usr/bin/env bash
# =============================================================================
# notifications.test.sh — Notifications stack tests (ntfy, apprise)
# =============================================================================

# ---------------------------------------------------------------------------
# Level 1: Container health
# ---------------------------------------------------------------------------
test_suite "Notifications — Containers"

test_ntfy_running() {
  assert_container_running "ntfy"
  assert_container_healthy "ntfy"
}

test_apprise_running() {
  assert_container_running "apprise"
  assert_container_healthy "apprise"
}

test_ntfy_running
test_apprise_running

# ---------------------------------------------------------------------------
# Level 2: HTTP endpoints
# ---------------------------------------------------------------------------
if [[ ${TEST_LEVEL:-99} -ge 2 ]]; then
  test_suite "Notifications — HTTP Endpoints"

  test_ntfy_health() {
    assert_http_200 "http://localhost:80/v1/health" "ntfy /v1/health"
  }

  test_apprise_ui() {
    assert_http_200 "http://localhost:8000" "Apprise UI"
  }

  test_ntfy_health
  test_apprise_ui
fi

# ---------------------------------------------------------------------------
# Level 3: Functionality
# ---------------------------------------------------------------------------
if [[ ${TEST_LEVEL:-99} -ge 3 ]]; then
  test_suite "Notifications — Functionality"

  test_ntfy_publish_subscribe() {
    # Publish a test message and verify ntfy accepts it
    local code
    code=$(curl -sf -o /dev/null -w '%{http_code}' \
      --connect-timeout 5 --max-time 10 \
      -X POST \
      -d "integration test message" \
      "http://localhost:80/homelab-test" 2>/dev/null || echo "000")
    if [[ "$code" == "200" ]]; then
      test_pass "ntfy accepts published messages"
    else
      test_fail "ntfy publish test" "expected HTTP 200, got $code"
    fi
  }

  test_ntfy_publish_subscribe
fi
