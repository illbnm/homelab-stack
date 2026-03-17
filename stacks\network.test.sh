#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Network Stack Tests
# Services: AdGuard Home, WireGuard Easy, Cloudflare DDNS, Nginx Proxy Manager
# =============================================================================

# shellcheck shell=bash

# ---------------------------------------------------------------------------
# AdGuard Home
# ---------------------------------------------------------------------------

test_adguard_container_running() {
  assert_container_running "adguardhome"
}

test_adguard_container_healthy() {
  assert_container_healthy "adguardhome"
}

test_adguard_control_status() {
  assert_http_200 "http://localhost:3000/control/status"
}

test_adguard_web_ui_accessible() {
  local status
  status=$(curl --silent --max-time 10 --output /dev/null --write-out "%{http_code}" \
    "http://localhost:3000" 2>/dev/null || echo "000")
  if [[ "$status" == "200" || "$status" == "302" ]]; then
    return 0
  fi
  _assert_fail "AdGuard Home UI returned HTTP ${status}"
}

test_adguard_dns_port_open() {
  assert_port_open "localhost" "53"
}

test_adguard_web_port_open() {
  assert_port_open "localhost" "3000"
}

# ---------------------------------------------------------------------------
# WireGuard Easy
# ---------------------------------------------------------------------------

test_wgeasy_container_running() {
  assert_container_running "wg-easy"
}

test_wgeasy_container_healthy() {
  assert_container_healthy "wg-easy"
}

test_wgeasy_ui_accessible() {
  assert_http_200 "http://localhost:51821"
}

test_wgeasy_port_open() {
  assert_port_open "localhost" "51821"
}

# ---------------------------------------------------------------------------
# Cloudflare DDNS
# ---------------------------------------------------------------------------

test_cloudflare_ddns_container_running() {
  assert_container_running "cloudflare-ddns"
}

test_cloudflare_ddns_not_crashing() {
  local restarts
  restarts=$(docker_container_restart_count "cloudflare-ddns")
  if [[ "$restarts" -gt 5 ]]; then
    _assert_fail "cloudflare-ddns has restarted ${restarts} times — check credentials"
  fi
}

# ---------------------------------------------------------------------------
# Nginx Proxy Manager
# ---------------------------------------------------------------------------

test_npm_container_running() {
  assert_container_running "nginx-proxy-manager"
}

test_npm_container_healthy() {
  assert_container_healthy "nginx-proxy-manager"
}

test_npm_admin_ui_accessible() {
  local status
  status=$(curl --silent --max-time 10 --output /dev/null --write-out "%{http_code}" \
    "http://localhost:81" 2>/dev/null || echo "000")
  if [[ "$status" == "200" || "$status" == "301" || "$status" == "302" ]]; then
    return 0
  fi
  _assert_fail "Nginx Proxy Manager admin returned HTTP ${status}"
}

test_npm_http_port_open() {
  assert_port_open "localhost" "80"
}

test_npm_https_port_open() {
  assert_port_open "localhost" "443"
}

test_npm_admin_port_open() {
  assert_port_open "localhost" "81"
}

# ---------------------------------------------------------------------------
# DNS resolution check (AdGuard as resolver)
# ---------------------------------------------------------------------------

test_adguard_dns_resolves_external() {
  if ! command -v dig &>/dev/null && ! command -v nslookup &>/dev/null; then
    echo "SKIP: neither dig nor nslookup available" >&2
    return 0
  fi

  if command -v dig &>/dev/null; then
    dig +short +time=5 @127.0.0.1 google.com A &>/dev/null && return 0
  else
    nslookup -timeout=5 google.com 127.0.0.1 &>/dev/null && return 0
  fi

  _assert_fail "AdGuard DNS (127.0.0.1:53) failed to resolve google.com"
}
