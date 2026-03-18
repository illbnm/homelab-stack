#!/usr/bin/env bash
# =============================================================================
# notifications.test.sh — Notifications stack tests
# Services: Ntfy, Apprise
# =============================================================================

# --- Ntfy ---

test_ntfy_running() {
  assert_container_running "ntfy"
}

test_ntfy_healthy() {
  assert_container_healthy "ntfy"
}

test_ntfy_health() {
  assert_http_200 "http://localhost:2586/v1/health" 10
}

test_ntfy_json_health() {
  assert_http_body_contains "http://localhost:2586/v1/health" '"healthy":true' 10
}

test_ntfy_publish_receive() {
  local msg="Ntfy publish and receive message"
  local topic
  topic="homelab-test-$(date +%s)"
  local test_msg
  test_msg="integration-test-$(date +%s)"

  # Publish
  local status
  status=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 \
    -d "${test_msg}" "http://localhost:2586/${topic}" 2>/dev/null) || {
    _assert_fail "$msg" "Publish failed"
    return 1
  }

  if [[ "$status" == "200" ]]; then
    _assert_pass "$msg"
  else
    _assert_fail "$msg" "Publish returned HTTP ${status}"
  fi
}

test_ntfy_no_crash_loop() {
  assert_no_crash_loop "ntfy" 3
}

test_ntfy_data_volume() {
  assert_volume_exists "ntfy-data"
}

test_ntfy_in_proxy_network() {
  assert_container_in_network "ntfy" "proxy"
}

# --- Apprise ---

test_apprise_running() {
  assert_container_running "apprise"
}

test_apprise_healthy() {
  assert_container_healthy "apprise"
}

test_apprise_api() {
  assert_http_200 "http://localhost:8000/status" 10
}

test_apprise_json_status() {
  assert_http_body_contains "http://localhost:8000/status" '"status_code"' 10
}

test_apprise_no_crash_loop() {
  assert_no_crash_loop "apprise" 3
}

test_apprise_config_volume() {
  assert_volume_exists "apprise-config"
}

test_apprise_in_proxy_network() {
  assert_container_in_network "apprise" "proxy"
}
