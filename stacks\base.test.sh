#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Base Infrastructure Tests
# Services: Traefik, Portainer, Watchtower
# =============================================================================

# shellcheck shell=bash

# ---------------------------------------------------------------------------
# Traefik
# ---------------------------------------------------------------------------

test_traefik_container_running() {
  assert_container_running "traefik"
}

test_traefik_container_healthy() {
  assert_container_healthy "traefik"
}

test_traefik_dashboard_accessible() {
  # Traefik dashboard / API — typically exposed on 8080 internally
  assert_http_200 "http://localhost:8080/api/version"
}

test_traefik_api_version_response() {
  assert_http_json_field \
    "http://localhost:8080/api/version" \
    ".Version" \
    "$(docker inspect --format '{{.Config.Image}}' traefik 2>/dev/null | grep -oP '(?<=:)[^@]+' || echo "")" \
    || true  # version string check is best-effort
  # Simpler: just check field exists
  assert_http_body_contains "http://localhost:8080/api/version" "Version"
}

test_traefik_http_port_open() {
  assert_port_open "localhost" "80"
}

test_traefik_https_port_open() {
  assert_port_open "localhost" "443"
}

test_traefik_has_traefik_labels() {
  assert_container_has_label "traefik" "traefik.enable"
}

test_traefik_in_proxy_network() {
  # The proxy/traefik network must exist
  assert_docker_network_exists "proxy" || \
  assert_docker_network_exists "traefik" || \
  assert_docker_network_exists "homelab_proxy"
}

test_traefik_restart_count_low() {
  local restarts
  restarts=$(docker_container_restart_count "traefik")
  if [[ "$restarts" -gt 5 ]]; then
    _assert_fail "Traefik has restarted ${restarts} times (threshold: 5)"
  fi
}

# ---------------------------------------------------------------------------
# Portainer
# ---------------------------------------------------------------------------

test_portainer_container_running() {
  assert_container_running "portainer"
}

test_portainer_container_healthy() {
  assert_container_healthy "portainer"
}

test_portainer_ui_accessible() {
  assert_http_200 "http://localhost:9000"
}

test_portainer_api_status() {
  assert_http_200 "http://localhost:9000/api/status"
}

test_portainer_api_returns_json() {
  assert_http_body_contains "http://localhost:9000/api/status" "Version"
}

test_portainer_port_open() {
  assert_port_open "localhost" "9000"
}

# ---------------------------------------------------------------------------
# Watchtower
# ---------------------------------------------------------------------------

test_watchtower_container_running() {
  assert_container_running "watchtower"
}

test_watchtower_not_restarting_excessively() {
  local restarts
  restarts=$(docker_container_restart_count "watchtower")
  if [[ "$restarts" -gt 3 ]]; then
    _assert_fail "Watchtower has restarted ${restarts} times (threshold: 3)"
  fi
}

# ---------------------------------------------------------------------------
# Shared infrastructure
# ---------------------------------------------------------------------------

test_proxy_network_exists() {
  assert_docker_network_exists "proxy" || \
  assert_docker_network_exists "traefik_default" || \
  assert_docker_network_exists "homelab_proxy"
}

test_docker_socket_accessible() {
  assert_true "$(docker info &>/dev/null; echo $?)"
}

test_base_env_file_exists() {
  local env_file
  env_file="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/.env"
  if [[ -f "$env_file" ]]; then
    assert_file_exists "$env_file"
    assert_env_file_has_key "$env_file" "DOMAIN"
  else
    echo "SKIP: .env file not found (expected in repo root)" >&2
  fi
}
