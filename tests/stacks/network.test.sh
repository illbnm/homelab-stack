#!/usr/bin/env bash
# =============================================================================
# Network Stack Tests — AdGuard Home + WireGuard + Unbound + Cloudflare DDNS
# =============================================================================

# --- Level 1: Container Health ---

test_network_adguard_running() {
  assert_container_running "homelab-adguard"
}

test_network_wireguard_running() {
  assert_container_running "homelab-wireguard"
}

test_network_unbound_running() {
  assert_container_running "homelab-unbound"
}

test_network_ddns_running() {
  assert_container_running "homelab-ddns"
}

# --- Level 1: Configuration ---

test_network_compose_syntax() {
  local output
  output=$(compose_config_valid "stacks/network/docker-compose.yml" 2>&1)
  _LAST_EXIT_CODE=$?
  assert_exit_code 0 "network compose syntax invalid: ${output}"
}

test_network_no_latest_tags() {
  assert_no_latest_images "stacks/network/"
}

# --- Level 2: HTTP Endpoints ---

test_network_adguard_control_status() {
  local ip
  ip=$(get_container_ip homelab-adguard)
  assert_http_200 "http://${ip}:3000/control/status" 30
}
