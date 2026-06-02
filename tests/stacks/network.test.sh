#!/usr/bin/env bash
# =============================================================================
# Network Stack Tests
# =============================================================================

test_unbound_running() {
  assert_container_running "unbound"
}

test_unbound_healthy() {
  assert_container_healthy "unbound" 60
}

test_adguard_running() {
  assert_container_running "adguardhome"
}

test_adguard_healthy() {
  assert_container_healthy "adguardhome" 60
}

test_adguard_http() {
  assert_http_200 "http://localhost:3000" 10
}

test_wireguard_running() {
  assert_container_running "wg-easy"
}

test_wireguard_port() {
  assert_port_open "localhost" "${WG_PORT:-51820}"
}

test_wireguard_ui() {
  assert_http_200 "http://localhost:51821" 10
}

test_cloudflare_ddns_running() {
  assert_container_running "cloudflare-ddns"
}

test_dns_port_bound() {
  assert_port_open "localhost" "53"
}

# Run all network tests
run_test_with_timing "network" test_unbound_running "Unbound running"
run_test_with_timing "network" test_unbound_healthy "Unbound healthy"
run_test_with_timing "network" test_adguard_running "AdGuard Home running"
run_test_with_timing "network" test_adguard_healthy "AdGuard Home healthy"
run_test_with_timing "network" test_adguard_http "AdGuard Home HTTP 200"
run_test_with_timing "network" test_wireguard_running "WireGuard Easy running"
run_test_with_timing "network" test_wireguard_ui "WireGuard Web UI HTTP 200"
run_test_with_timing "network" test_cloudflare_ddns_running "Cloudflare DDNS running"
run_test_with_timing "network" test_dns_port_bound "DNS port 53 open"
