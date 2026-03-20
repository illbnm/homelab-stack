#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Network Tests
# Services: AdGuard Home, Nginx Proxy Manager
# =============================================================================

COMPOSE_FILE="$BASE_DIR/stacks/network/docker-compose.yml"

# ===========================================================================
# Level 1 — Configuration Integrity
# ===========================================================================
if [[ "${TEST_LEVEL:-0}" -eq 0 || "${TEST_LEVEL:-0}" -le 1 ]]; then
  test_group "Network — Configuration"

  assert_compose_valid "$COMPOSE_FILE"
fi

# ===========================================================================
# Level 1 — Container Health
# ===========================================================================
if [[ "${TEST_LEVEL:-0}" -eq 0 || "${TEST_LEVEL:-0}" -le 1 ]]; then
  test_group "Network — Container Health"

  assert_container_running "adguardhome"
  assert_container_healthy "adguardhome"
  assert_container_not_restarting "adguardhome"

  assert_container_running "nginx-proxy-manager"
  assert_container_healthy "nginx-proxy-manager"
  assert_container_not_restarting "nginx-proxy-manager"
fi

# ===========================================================================
# Level 2 — HTTP & Port Endpoints
# ===========================================================================
if [[ "${TEST_LEVEL:-0}" -eq 0 || "${TEST_LEVEL:-0}" -ge 2 ]]; then
  test_group "Network — Endpoints"

  # AdGuard Home web UI (runs on 3000 internally)
  assert_http_ok "http://localhost:3000" \
    "AdGuard Home web UI"

  # AdGuard Home DNS control API
  assert_http_ok "http://localhost:3000/control/status" \
    "AdGuard Home /control/status"

  # DNS port
  assert_port_open "localhost" 53 "DNS port 53"

  # Nginx Proxy Manager admin UI
  assert_http_ok "http://localhost:8181" \
    "Nginx Proxy Manager admin UI"
fi

# ===========================================================================
# Level 3 — Interconnection
# ===========================================================================
if [[ "${TEST_LEVEL:-0}" -eq 0 || "${TEST_LEVEL:-0}" -ge 3 ]]; then
  test_group "Network — Interconnection"

  assert_container_in_network "adguardhome" "proxy"
  assert_container_in_network "nginx-proxy-manager" "proxy"

  # AdGuard DNS resolution test
  if is_container_running "adguardhome"; then
    dns_result=$(dig @localhost +short +time=3 google.com 2>/dev/null)
    if [[ -n "$dns_result" ]]; then
      _record_pass "AdGuard DNS resolves google.com"
    else
      _record_fail "AdGuard DNS resolves google.com" "no result returned"
    fi
  else
    skip_test "AdGuard DNS resolves google.com" "adguardhome not running"
  fi
fi
