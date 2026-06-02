#!/usr/bin/env bash
# =============================================================================
# Base Stack Tests
# =============================================================================

test_traefik_running() {
  assert_container_running "traefik"
}

test_traefik_healthy() {
  assert_container_healthy "traefik" 30
}

test_traefik_http() {
  assert_http_200 "http://localhost:8080/api/version" 10
}

test_traefik_port_80() {
  assert_port_open "localhost" "80"
}

test_traefik_port_443() {
  assert_port_open "localhost" "443"
}

test_portainer_running() {
  assert_container_running "portainer"
}

test_portainer_healthy() {
  assert_container_healthy "portainer" 30
}

test_portainer_http() {
  assert_http_200 "http://localhost:9000/api/status" 10
}

test_watchtower_running() {
  assert_container_running "watchtower"
}

run_test_with_timing "base" test_traefik_running "Traefik running"
run_test_with_timing "base" test_traefik_healthy "Traefik healthy"
run_test_with_timing "base" test_traefik_http "Traefik API HTTP 200"
run_test_with_timing "base" test_traefik_port_80 "Traefik port 80 open"
run_test_with_timing "base" test_traefik_port_443 "Traefik port 443 open"
run_test_with_timing "base" test_portainer_running "Portainer running"
run_test_with_timing "base" test_portainer_healthy "Portainer healthy"
run_test_with_timing "base" test_portainer_http "Portainer API HTTP 200"
run_test_with_timing "base" test_watchtower_running "Watchtower running"
