#!/usr/bin/env bash
# =============================================================================
# HomeLab — Base Infrastructure Tests
# =============================================================================
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib"; pwd)"
source "$_LIB_DIR/assert.sh"

test_base_traefik_running() {
  assert_container_running "traefik" "Traefik container should be running"
}

test_base_traefik_healthy() {
  assert_container_healthy "traefik" 60 "Traefik should be healthy"
}

test_base_traefik_http() {
  assert_port_open "localhost" 80 "Traefik HTTP port 80 should be open"
}

test_base_traefik_https() {
  assert_port_open "localhost" 443 "Traefik HTTPS port 443 should be open"
}

test_base_traefik_dashboard() {
  assert_http_200 "http://localhost:8080/api/overview" 15 "Traefik dashboard API should respond"
}

test_base_portainer_running() {
  assert_container_running "portainer" "Portainer container should be running"
}

test_base_portainer_http() {
  assert_http_200 "http://localhost:9000" 15 "Portainer should respond on :9000"
}

test_base_watchtower_running() {
  assert_container_running "watchtower" "Watchtower container should be running"
}

test_base_no_latest_tags() {
  assert_no_latest_images "$BASE_DIR/stacks/base" "Base stack should pin image versions"
}
