#!/usr/bin/env bash
# =============================================================================
# network.test.sh — Network stack tests
# Services: AdGuard Home, Nginx Proxy Manager
# =============================================================================

# --- AdGuard Home ---

test_adguard_running() {
  assert_container_running "adguardhome"
}

test_adguard_healthy() {
  assert_container_healthy "adguardhome"
}

test_adguard_api() {
  assert_http_200 "http://localhost:3000/control/status" 10
}

test_adguard_dns_port() {
  assert_port_listening 53
}

test_adguard_no_crash_loop() {
  assert_no_crash_loop "adguardhome" 3
}

test_adguard_work_volume() {
  assert_volume_exists "adguard-work"
}

test_adguard_conf_volume() {
  assert_volume_exists "adguard-conf"
}

# --- Nginx Proxy Manager ---

test_npm_running() {
  assert_container_running "nginx-proxy-manager"
}

test_npm_healthy() {
  assert_container_healthy "nginx-proxy-manager"
}

test_npm_admin_ui() {
  assert_http_status "http://localhost:81" 200 10
}

test_npm_proxy_port_80() {
  assert_port_listening 80
}

test_npm_proxy_port_443() {
  assert_port_listening 443
}

test_npm_no_crash_loop() {
  assert_no_crash_loop "nginx-proxy-manager" 3
}

test_npm_data_volume() {
  assert_volume_exists "npm-data"
}

test_npm_in_proxy_network() {
  assert_container_in_network "nginx-proxy-manager" "proxy"
}
