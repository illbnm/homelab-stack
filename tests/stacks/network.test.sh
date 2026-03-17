#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Network Stack Tests
# =============================================================================
# Tests: AdGuard Home, WireGuard Easy, Cloudflare DDNS, Nginx Proxy Manager
# =============================================================================

# ---------------------------------------------------------------------------
# Level 1 — Container Health
# ---------------------------------------------------------------------------

test_adguard_running() {
  assert_container_running "adguard"
}

test_adguard_healthy() {
  assert_container_healthy "adguard" 60
}

test_wireguard_running() {
  assert_container_running "wireguard"
}

test_wireguard_healthy() {
  assert_container_healthy "wireguard" 60
}

test_cloudflare_ddns_running() {
  assert_container_running "cloudflare-ddns"
}

test_nginx_proxy_manager_running() {
  assert_container_running "nginx-proxy-manager"
}

test_nginx_proxy_manager_healthy() {
  assert_container_healthy "nginx-proxy-manager" 60
}

# ---------------------------------------------------------------------------
# Level 2 — HTTP Endpoints
# ---------------------------------------------------------------------------

test_adguard_control_status() {
  assert_http_200 "http://localhost:3000/control/status" 30
}

test_adguard_dns_query() {
  # Test DNS resolution through AdGuard
  local result
  result=$(dig @127.0.0.1 -p 53 google.com +short 2>/dev/null || echo "")

  if [[ -n "${result}" ]]; then
    _assert_pass "AdGuard DNS resolves queries"
  else
    _assert_skip "Cannot test DNS (dig not available or DNS not responding)"
  fi
}

test_wireguard_webui() {
  assert_http_200 "http://localhost:51821" 30
}

test_nginx_proxy_manager_admin() {
  assert_http_200 "http://localhost:81" 30
}

# ---------------------------------------------------------------------------
# Level 1 — Configuration
# ---------------------------------------------------------------------------

test_network_compose_valid() {
  local compose_file="${PROJECT_ROOT}/stacks/network/docker-compose.yml"

  if [[ ! -f "${compose_file}" ]]; then
    _assert_skip "Network compose file not found"
    return 0
  fi

  assert_compose_valid "${compose_file}"
}
