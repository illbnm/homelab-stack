#!/usr/bin/env bash
# Network Stack Tests — AdGuard Home, WireGuard VPN, Nginx Proxy Manager
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
source "$SCRIPT_DIR/../lib/assert.sh"
source "$SCRIPT_DIR/../lib/docker.sh"

reset_counters
log_test_start "Network Stack"

section "AdGuard Home"
assert_container_running "AdGuard container" "homelab-adguard"
assert_http_2xx "AdGuard HTTP accessible" "http://localhost:3053/health" \
  || assert_http_2xx "AdGuard HTTP" "http://localhost:3053/" || true

section "WireGuard"
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^homelab-wireguard$"; then
  assert_container_running "WireGuard running" "homelab-wireguard"
  assert_port_open "WireGuard UDP port 51820" "localhost" "51820" || skip "UDP check skipped"
else
  skip "WireGuard not deployed"
fi

section "Nginx Proxy Manager"
assert_container_running "NPM container" "homelab-nginx-proxy-manager"
assert_http_2xx "NPM HTTP accessible" "http://localhost:3081/" || true

section "Network config"
[[ -f "$ROOT_DIR/stacks/network/docker-compose.yml" ]] \
  && pass "network docker-compose.yml exists" \
  || fail "network docker-compose.yml missing"

assert_summary