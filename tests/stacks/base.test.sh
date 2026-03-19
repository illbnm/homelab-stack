#!/usr/bin/env bash
# =============================================================================
# base.test.sh — Base infrastructure tests (traefik, portainer, watchtower)
# =============================================================================

# ---------------------------------------------------------------------------
# Level 1: Container health
# ---------------------------------------------------------------------------
test_suite "Base Infrastructure — Containers"

test_traefik_running() {
  assert_container_running "traefik"
  assert_container_healthy "traefik"
}

test_portainer_running() {
  assert_container_running "portainer"
  assert_container_healthy "portainer"
}

test_watchtower_running() {
  assert_container_running "watchtower"
  assert_container_healthy "watchtower"
}

test_traefik_running
test_portainer_running
test_watchtower_running

# ---------------------------------------------------------------------------
# Level 2: HTTP endpoints
# ---------------------------------------------------------------------------
if [[ ${TEST_LEVEL:-99} -ge 2 ]]; then
  test_suite "Base Infrastructure — HTTP Endpoints"

  test_traefik_api() {
    assert_http_200 "http://localhost:8080/api/version" "Traefik API /api/version"
  }

  test_portainer_api() {
    assert_http_200 "http://localhost:9000/api/status" "Portainer API /api/status"
  }

  test_traefik_api
  test_portainer_api
fi

# ---------------------------------------------------------------------------
# Level 3: Configuration integrity
# ---------------------------------------------------------------------------
if [[ ${TEST_LEVEL:-99} -ge 3 ]]; then
  test_suite "Base Infrastructure — Configuration"

  test_traefik_ports() {
    assert_port_open "localhost" 80 "Traefik HTTP port 80"
    assert_port_open "localhost" 443 "Traefik HTTPS port 443"
  }

  test_proxy_network() {
    if docker_network_exists "proxy"; then
      test_pass "Docker network 'proxy' exists"
    else
      test_fail "Docker network 'proxy' exists" "network not found"
    fi
  }

  test_traefik_config() {
    assert_file_exists "$BASE_DIR/config/traefik/traefik.yml" "Traefik config exists"
  }

  test_traefik_ports
  test_proxy_network
  test_traefik_config
fi
