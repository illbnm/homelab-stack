#!/usr/bin/env bash
# Network stack tests
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/assert.sh"

test_adguard_running() {
  assert_container_running "adguard"
  assert_http_200 "http://localhost:3000/control/status"
}

test_wireguard_running() {
  assert_container_running "wireguard"
}

test_unbound_running() {
  assert_container_running "unbound"
}

test_cloudflare_ddns_running() {
  assert_container_running "cloudflare-ddns"
}

run_test test_adguard_running
run_test test_wireguard_running
run_test test_unbound_running
run_test test_cloudflare_ddns_running
