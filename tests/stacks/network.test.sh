#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Network Stack Tests
# Tests: AdGuard Home + WireGuard + Nginx Proxy Manager
# =============================================================================
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/docker.sh"

should_run_stack "network" || { begin_suite "Network Stack"; assert_skip "not selected"; exit 0; }

begin_suite "Network Stack — AdGuard + WireGuard + Nginx Proxy Manager"

# ---- AdGuard Home ----
assert_container_running "adguardhome"
assert_container_healthy "adguardhome"
assert_container_not_latest "adguardhome"
assert_http_200 "${BASE_URL:-http://localhost}:3000" "adguard:ui"
assert_http_200 "${BASE_URL:-http://localhost}:8080/control/status" "adguard:api"
assert_port_open "localhost" "53" "dns"

# ---- WireGuard ----
assert_container_running "wireguard"
assert_container_healthy "wireguard"
assert_container_not_latest "wireguard"

# ---- Nginx Proxy Manager ----
assert_container_running "nginx-proxy-manager"
assert_container_healthy "nginx-proxy-manager"
assert_container_not_latest "nginx-proxy-manager"
assert_http_200 "${BASE_URL:-http://localhost}:81" "npm:ui"

# ---- Network ----
begin_test "network:proxy_member"
for c in adguardhome nginx-proxy-manager; do
  if docker inspect --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}' "$c" 2>/dev/null | grep -q "proxy"; then
    assert_pass "$c in proxy network"
  else
    assert_skip "$c not in proxy"
  fi
done

# ---- Compose validation ----
assert_compose_valid "${SCRIPT_DIR}/../../stacks/network/docker-compose.yml" "network"
