#!/usr/bin/env bash
# =============================================================================
# Base Infrastructure Tests — Traefik, Portainer, Watchtower
# =============================================================================

log_group "Base Infrastructure"

# --- Level 1: Container health ---

test_traefik_running() {
  assert_container_running "traefik"
  assert_container_healthy "traefik"
  assert_container_not_restarting "traefik"
}

test_portainer_running() {
  assert_container_running "portainer"
  assert_container_healthy "portainer"
  assert_container_not_restarting "portainer"
}

test_watchtower_running() {
  assert_container_running "watchtower"
  assert_container_healthy "watchtower"
}

test_traefik_running
test_portainer_running
test_watchtower_running

# --- Level 1: Network ---

test_proxy_network() {
  assert_network_exists "proxy"
  if is_container_running "traefik"; then
    assert_container_on_network "traefik" "proxy"
  fi
  if is_container_running "portainer"; then
    assert_container_on_network "portainer" "proxy"
  fi
}

test_proxy_network

# --- Level 2: HTTP endpoints ---
if [[ "${TEST_LEVEL:-99}" -ge 2 ]]; then

  test_traefik_http() {
    assert_port_open "localhost" 80 "Traefik HTTP port 80"
    assert_port_open "localhost" 443 "Traefik HTTPS port 443"
    # Traefik API/ping endpoint
    assert_http_ok "http://localhost:8080/ping" "Traefik ping endpoint"
  }

  test_portainer_http() {
    assert_http_ok "http://localhost:9000" "Portainer Web UI"
    assert_http_ok "http://localhost:9000/api/status" "Portainer API status"
  }

  if is_container_running "traefik"; then
    test_traefik_http
  else
    skip_test "Traefik HTTP tests" "container not running"
  fi

  if is_container_running "portainer"; then
    test_portainer_http
  else
    skip_test "Portainer HTTP tests" "container not running"
  fi
fi

# --- Level 1: Image tag pinning ---
test_base_image_tags() {
  for c in traefik portainer watchtower; do
    if is_container_running "$c"; then
      assert_container_image_not_latest "$c"
    fi
  done
}

test_base_image_tags
