#!/usr/bin/env bash
# =============================================================================
# Notifications Stack Tests
# =============================================================================

test_ntfy_running() {
  assert_container_running "ntfy"
}

test_ntfy_http() {
  assert_http_200 "http://localhost:2586" 10
}

run_test_with_timing "notifications" test_ntfy_running "ntfy running"
run_test_with_timing "notifications" test_ntfy_http "ntfy HTTP 200"
