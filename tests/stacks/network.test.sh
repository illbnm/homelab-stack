#!/usr/bin/env bash
# =============================================================================
# Network Stack Tests — AdGuard Home, Nginx Proxy Manager
# =============================================================================

log_group "Network"

# --- Level 1: Container health ---

NETWORK_CONTAINERS=(adguardhome nginx-proxy-manager)

for c in "${NETWORK_CONTAINERS[@]}"; do
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

  test_adguard_http() {
    require_container "adguardhome" || return
    assert_http_ok "http://localhost:3000" "AdGuard Home Web UI"
    assert_http_ok "http://localhost:3000/control/status" "AdGuard /control/status"
  }

  test_adguard_dns() {
    require_container "adguardhome" || return
    assert_port_open "localhost" 53 "AdGuard DNS port 53"
  }

  test_npm_http() {
    require_container "nginx-proxy-manager" || return
    assert_http_ok "http://localhost:8181" "Nginx Proxy Manager Web UI"
  }

  test_adguard_http
  test_adguard_dns
  test_npm_http
fi

# --- Level 3: Service interconnection ---
if [[ "${TEST_LEVEL:-99}" -ge 3 ]]; then

  # AdGuard must resolve DNS queries
  test_adguard_dns_resolve() {
    require_container "adguardhome" || return
    if command -v dig &>/dev/null; then
      local result
      result=$(dig @localhost example.com +short +time=3 2>/dev/null)
      if [[ -n "$result" ]]; then
        _record_result pass "AdGuard DNS resolves example.com" "$result"
      else
        _record_result fail "AdGuard DNS resolves example.com" "no result"
      fi
    elif command -v nslookup &>/dev/null; then
      local result
      result=$(nslookup example.com localhost 2>/dev/null)
      if echo "$result" | grep -q "Address:"; then
        _record_result pass "AdGuard DNS resolves example.com"
      else
        _record_result fail "AdGuard DNS resolves example.com" "resolution failed"
      fi
    else
      skip_test "AdGuard DNS resolution" "dig/nslookup not available"
    fi
  }

  test_adguard_dns_resolve
fi

# --- Image tags ---
for c in "${NETWORK_CONTAINERS[@]}"; do
  if is_container_running "$c"; then
    assert_container_image_not_latest "$c"
  fi
done
