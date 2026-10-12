#!/usr/bin/env bash

# Base Stack Integration Tests
#
# Tests for core infrastructure services: Traefik, Portainer, Watchtower.
#
# Dependencies:
#   assert.sh, docker.sh (sourced by run-tests.sh)
#   .env file with necessary variables (e.g., PUID, PGID)

# Load environment variables from .env if not already loaded (for local runs)
if [[ -f ".env" ]]; then
  # shellcheck source=../../.env
  source ".env"
fi

# --- Level 1: Container Health Tests ---

test_traefik_running() {
  assert_container_running "traefik"
  assert_container_healthy "traefik"
}

test_portainer_running() {
  assert_container_running "portainer"
  assert_container_healthy "portainer"
}

test_watchtower_running() {
  assert_container_running "watchtower"
}

# --- Level 2: HTTP Endpoint Tests ---

test_traefik_api_version_200() {
  # Traefik API is usually exposed on a separate port, or via a specific entrypoint.
  # Assuming it's accessible directly on localhost:8080 for testing purposes in CI.
  # If not, this needs to be adjusted based on actual Traefik configuration.
  assert_http_200 "http://localhost:8080/api/version"
}

test_portainer_api_status_200() {
  # Portainer is typically on port 9000
  assert_http_200 "http://localhost:9000/api/status"
}

# --- Level 5: Configuration Integrity Tests ---

test_base_compose_syntax() {
  docker compose -f stacks/base/docker-compose.yml config --quiet 2>&1
  assert_exit_code 0 "Base stack compose config failed"
}

test_base_no_latest_tags() {
  assert_no_latest_images "stacks/base" "Found :latest image tags in base stack"
}

test_base_all_services_have_healthcheck() {
  assert_all_services_have_healthcheck "stacks/base/docker-compose.yml" "Base stack services missing healthcheck"
}
