#!/usr/bin/env bash
# =============================================================================
# network.test.sh — Network stack tests (AdGuard, NPM)
# =============================================================================

# ---------------------------------------------------------------------------
# Level 1: Container health
# ---------------------------------------------------------------------------
test_suite "Network — Containers"

test_adguard_running() {
  assert_container_running "adguardhome"
  assert_container_healthy "adguardhome"
}

test_npm_running() {
  assert_container_running "nginx-proxy-manager"
  assert_container_healthy "nginx-proxy-manager"
}

test_adguard_running
test_npm_running

# ---------------------------------------------------------------------------
# Level 2: HTTP endpoints
# ---------------------------------------------------------------------------
if [[ ${TEST_LEVEL:-99} -ge 2 ]]; then
  test_suite "Network — HTTP Endpoints"

  test_adguard_api() {
    assert_http_200 "http://localhost:3000/control/status" "AdGuard /control/status"
  }

  test_npm_health() {
    assert_http_200 "http://localhost:8181" "Nginx Proxy Manager UI"
  }

  test_adguard_api
  test_npm_health
fi

# ---------------------------------------------------------------------------
# Level 3: DNS resolution
# ---------------------------------------------------------------------------
if [[ ${TEST_LEVEL:-99} -ge 3 ]]; then
  test_suite "Network — DNS"

  test_adguard_dns_port() {
    assert_port_open "localhost" 53 "AdGuard DNS port 53"
  }

  test_adguard_dns_port
fi
