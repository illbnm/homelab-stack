#!/usr/bin/env bash
# =============================================================================
# Notifications Stack Tests — ntfy + Gotify
# =============================================================================

# --- Level 1: Container Health ---

test_notifications_ntfy_running() {
  assert_container_running "homelab-ntfy"
}

test_notifications_gotify_running() {
  assert_container_running "homelab-gotify"
}

# --- Level 1: Configuration ---

test_notifications_compose_syntax() {
  local output
  output=$(compose_config_valid "stacks/notifications/docker-compose.yml" 2>&1)
  _LAST_EXIT_CODE=$?
  assert_exit_code 0 "notifications compose syntax invalid: ${output}"
}

test_notifications_no_latest_tags() {
  assert_no_latest_images "stacks/notifications/"
}

# --- Level 2: HTTP Endpoints ---

test_notifications_ntfy_http() {
  local ip
  ip=$(get_container_ip homelab-ntfy)
  assert_http_200 "http://${ip}:80" 30
}

test_notifications_gotify_http() {
  local ip
  ip=$(get_container_ip homelab-gotify)
  assert_http_200 "http://${ip}:80" 30
}
