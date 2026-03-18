#!/usr/bin/env bash
# base.test.sh — Base Infrastructure Tests (Traefik, Portainer, Watchtower)
set -euo pipefail

COMPOSE_FILE="${COMPOSE_FILE:-stacks/base/docker-compose.yml}"

test_traefik_running() {
  test_start "Traefik running"
  assert_container_running "traefik"
  test_end
}

test_traefik_healthy() {
  test_start "Traefik healthy"
  assert_container_healthy "traefik" 60
  test_end
}

test_traefik_version_api() {
  test_start "Traefik /api/version"
  assert_http_200 "http://localhost:80/api/version" 10
  test_end
}

test_portainer_running() {
  test_start "Portainer running"
  assert_container_running "portainer"
  test_end
}

test_portainer_healthy() {
  test_start "Portainer healthy"
  assert_container_healthy "portainer" 60
  test_end
}

test_portainer_http() {
  test_start "Portainer HTTP 200"
  assert_http_200 "http://localhost:9000" 15
  test_end
}

test_watchtower_running() {
  test_start "Watchtower running"
  assert_container_running "watchtower"
  test_end
}

test_proxy_network_exists() {
  test_start "Proxy network exists"
  assert_network_exists "proxy"
  test_end
}

test_compose_syntax() {
  test_start "Base compose syntax valid"
  assert_exit_code 0 docker compose -f "$COMPOSE_FILE" config --quiet
  test_end
}
