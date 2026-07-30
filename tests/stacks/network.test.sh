#!/usr/bin/env bash
# Network Stack Tests — AdGuard Home + WireGuard + Cloudflare DDNS + Unbound
test_adguard_running() { assert_eq "$(container_status adguard)" "running" "AdGuard Home should be running"; }
test_adguard_status() { assert_http_status "http://localhost:3000/control/status" "200" "AdGuard control API"; }
test_wireguard_running() { assert_eq "$(container_status wireguard)" "running" "WireGuard should be running"; }
test_unbound_running() { assert_eq "$(container_status unbound)" "running" "Unbound should be running"; }
test_unbound_dns() {
  local result
  result=$(docker exec unbound dig +short @127.0.0.1 google.com A 2>/dev/null || echo "")
  assert_not_empty "$result" "Unbound should resolve DNS queries"
}
test_cloudflare_ddns_running() { assert_eq "$(container_status cloudflare-ddns)" "running" "Cloudflare DDNS should be running"; }
test_adguard_dns_resolution() {
  local result
  result=$(dig +short @127.0.0.1 -p 53 example.com A 2>/dev/null || docker exec adguard dig +short @127.0.0.1 example.com A 2>/dev/null || echo "")
  assert_not_empty "$result" "AdGuard should resolve DNS"
}