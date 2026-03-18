#!/usr/bin/env bash
# =============================================================================
# base.test.sh — Base infrastructure stack tests
# Services: Traefik, Portainer, Watchtower
# =============================================================================

# --- Traefik ---

test_traefik_running() {
  assert_container_running "traefik"
}

test_traefik_healthy() {
  assert_container_healthy "traefik"
}

test_traefik_no_crash_loop() {
  assert_no_crash_loop "traefik" 3
}

test_traefik_api() {
  assert_http_200 "http://localhost:8080/api/version" 10
}

test_traefik_dashboard() {
  assert_http_status "http://localhost:8080/dashboard/" 200 10
}

test_traefik_port_80() {
  assert_port_listening 80
}

test_traefik_port_443() {
  assert_port_listening 443
}

test_traefik_no_critical_errors() {
  assert_log_no_errors "traefik" "FATAL\|panic" "1h"
}

test_traefik_in_proxy_network() {
  assert_container_in_network "traefik" "proxy"
}

# --- Portainer ---

test_portainer_running() {
  assert_container_running "portainer"
}

test_portainer_healthy() {
  assert_container_healthy "portainer"
}

test_portainer_api() {
  assert_http_200 "http://localhost:9000/api/status" 10
}

test_portainer_no_crash_loop() {
  assert_no_crash_loop "portainer" 3
}

test_portainer_data_volume() {
  assert_volume_exists "portainer-data"
}

# --- Watchtower ---

test_watchtower_running() {
  assert_container_running "watchtower"
}

test_watchtower_healthy() {
  assert_container_healthy "watchtower"
}

test_watchtower_no_crash_loop() {
  assert_no_crash_loop "watchtower" 3
}

# --- Infrastructure ---

test_proxy_network_exists() {
  assert_network_exists "proxy"
}
