#!/usr/bin/env bash
set -euo pipefail

test_traefik_running() {
  assert_container_healthy traefik
}

test_portainer_running() {
  assert_container_healthy portainer
}

test_watchtower_running() {
  assert_container_running watchtower
}

test_traefik_http() {
  assert_http_response "http://localhost:8080/api/version" '"Version"'
}

test_portainer_http() {
  assert_http_200 "http://localhost:9000/api/status"
}
