#!/usr/bin/env bash
# =============================================================================
# SSO Stack Tests — Authentik Server + Authentik Worker
# =============================================================================

# --- Level 1: Container Health ---

test_sso_authentik_server_running() {
  assert_container_running "homelab-authentik"
}

test_sso_authentik_worker_running() {
  assert_container_running "homelab-authentik-worker"
}

# --- Level 1: Configuration ---

test_sso_compose_syntax() {
  local output
  output=$(compose_config_valid "stacks/sso/docker-compose.yml" 2>&1)
  _LAST_EXIT_CODE=$?
  assert_exit_code 0 "sso compose syntax invalid: ${output}"
}

test_sso_no_latest_tags() {
  assert_no_latest_images "stacks/sso/"
}

# --- Level 2: HTTP Endpoints ---

test_sso_authentik_api() {
  local ip
  ip=$(get_container_ip homelab-authentik)
  assert_http_200 "http://${ip}:9000/-/health/live/" 30
}
