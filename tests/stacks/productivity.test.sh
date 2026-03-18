#!/usr/bin/env bash
# =============================================================================
# Productivity Stack Tests — Gitea + Vaultwarden + Outline + BookStack
# =============================================================================

# --- Level 1: Container Health ---

test_productivity_gitea_running() {
  assert_container_running "homelab-gitea"
}

test_productivity_vaultwarden_running() {
  assert_container_running "homelab-vaultwarden"
}

test_productivity_vaultwarden_healthy() {
  assert_container_healthy "homelab-vaultwarden" 60
}

test_productivity_outline_running() {
  assert_container_running "homelab-outline"
}

test_productivity_bookstack_running() {
  assert_container_running "homelab-bookstack"
}

# --- Level 1: Configuration ---

test_productivity_compose_syntax() {
  local output
  output=$(compose_config_valid "stacks/productivity/docker-compose.yml" 2>&1)
  _LAST_EXIT_CODE=$?
  assert_exit_code 0 "productivity compose syntax invalid: ${output}"
}

test_productivity_no_latest_tags() {
  assert_no_latest_images "stacks/productivity/"
}

# --- Level 2: HTTP Endpoints ---

test_productivity_gitea_api_version() {
  local ip
  ip=$(get_container_ip homelab-gitea)
  assert_http_response "http://${ip}:3000/api/v1/version" '"version"' 30
}
