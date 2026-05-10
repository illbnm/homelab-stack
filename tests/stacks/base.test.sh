#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Base Infrastructure Tests
# Requires: base stack running (Traefik, Portainer, Watchtower)
# =============================================================================
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
TEST_DIR=$(dirname "$SCRIPT_DIR")
source "${TEST_DIR}/lib/assert.sh"

describe "Base Infrastructure"

# Traefik
it "Traefik container running"; assert_container_running "traefik"
it "Traefik healthy"; assert_container_healthy "traefik"
it "Traefik API accessible"; assert_http_200 "http://localhost:8080/api/version"
it "Traefik dashboard ping"; assert_http_200 "http://localhost:8080/ping"

# Portainer
it "Portainer container running"; assert_container_running "portainer"
it "Portainer API accessible"; assert_http_200 "http://localhost:9000/api/status"
it "Portainer API returns version"; 
  local resp
  resp=$(curl -s http://localhost:9000/api/status 2>/dev/null)
  assert_json_value "$resp" ".Version | length > 0" "true" "no version field"

# Watchtower
it "Watchtower container running"; assert_container_running "watchtower"

# Network
it "proxy network exists"; assert_true "docker network inspect proxy &>/dev/null"

# Configuration
it "traefik.yml config valid"; assert_file_exists "${ROOT_DIR:-../../}config/traefik/traefik.yml"
it "dynamic middlewares defined"; assert_file_exists "${ROOT_DIR:-../../}config/traefik/dynamic/middlewares.yml"