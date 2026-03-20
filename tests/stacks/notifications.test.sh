#!/usr/bin/env bash
# =============================================================================
# Notifications Stack Tests — ntfy, Apprise
# =============================================================================

log_group "Notifications"

# --- Level 1: Container health ---

NOTIF_CONTAINERS=(ntfy apprise)

for c in "${NOTIF_CONTAINERS[@]}"; do
  if is_container_running "$c"; then
    assert_container_running "$c"
    assert_container_healthy "$c"
    assert_container_not_restarting "$c"
  else
    skip_test "Container '$c'" "not running"
  fi
done

# --- Level 2: HTTP endpoints ---
if [[ "${TEST_LEVEL:-99}" -ge 2 ]]; then

  test_ntfy_http() {
    require_container "ntfy" || return
    assert_http_200 "http://localhost:80/v1/health" "ntfy /v1/health"
  }

  test_apprise_http() {
    require_container "apprise" || return
    assert_http_ok "http://localhost:8000" "Apprise Web UI"
  }

  test_ntfy_http
  test_apprise_http
fi

# --- Level 3: Service interconnection ---
if [[ "${TEST_LEVEL:-99}" -ge 3 ]]; then

  # Test ntfy can receive a notification
  test_ntfy_publish() {
    require_container "ntfy" || return
    local result
    result=$(curl -sf -o /dev/null -w '%{http_code}' \
      -d "Integration test message" \
      "http://localhost:80/homelab-test" 2>/dev/null || echo "000")
    assert_eq "$result" "200" "ntfy accepts published message"
  }

  test_ntfy_publish
fi

# --- Image tags ---
for c in "${NOTIF_CONTAINERS[@]}"; do
  if is_container_running "$c"; then
    assert_container_image_not_latest "$c"
  fi
done
