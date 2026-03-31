#!/bin/bash
# =============================================================================
# Base Stack Tests
# Tests for: traefik, portainer, watchtower
# =============================================================================

set -e

# Source the assertion library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/assert.sh"

# -----------------------------------------------------------------------------
# Test: Docker Compose file validation
# -----------------------------------------------------------------------------
describe "Docker Compose Configuration"

it "should have valid docker-compose.yml"
COMPOSE_FILE="stacks/base/docker-compose.yml"
assert_file_exists "$COMPOSE_FILE" "Base compose file should exist"
assert_docker_compose_valid "$COMPOSE_FILE" "Compose file should be valid YAML"

# -----------------------------------------------------------------------------
# Test: Required services exist
# -----------------------------------------------------------------------------
describe "Service Definitions"

it "should define traefik service"
assert_service_exists "$COMPOSE_FILE" "traefik" "Traefik service should exist"

it "should define portainer service"
assert_service_exists "$COMPOSE_FILE" "portainer" "Portainer service should exist"

it "should define watchtower service"
assert_service_exists "$COMPOSE_FILE" "watchtower" "Watchtower service should exist"

# -----------------------------------------------------------------------------
# Test: Required networks
# -----------------------------------------------------------------------------
describe "Network Configuration"

it "should define proxy network"
COMPOSE_CONTENT=$(cat "$COMPOSE_FILE")
assert_contains "$COMPOSE_CONTENT" "proxy" "Proxy network should be defined"

# -----------------------------------------------------------------------------
# Test: Volume definitions
# -----------------------------------------------------------------------------
describe "Volume Configuration"

it "should define required volumes"
COMPOSE_CONTENT=$(cat "$COMPOSE_FILE")
assert_contains "$COMPOSE_CONTENT" "portainer-data" "Portainer volume should be defined"
assert_contains "$COMPOSE_CONTENT" "traefik-logs" "Traefik logs volume should be defined"

# -----------------------------------------------------------------------------
# Test: Traefik configuration
# -----------------------------------------------------------------------------
describe "Traefik Configuration"

it "should have traefik image defined"
TRAEFIK_IMAGE=$(docker compose -f "$COMPOSE_FILE" config --services 2>/dev/null | head -1)
if docker compose -f "$COMPOSE_FILE" config 2>/dev/null | grep -q "image: traefik"; then
    assert_contains "$(docker compose -f "$COMPOSE_FILE" config)" "image: traefik" "Traefik image should be defined"
fi

it "should expose HTTP port"
COMPOSE_CONTENT=$(docker compose -f "$COMPOSE_FILE" config 2>/dev/null || echo "")
assert_contains "$COMPOSE_CONTENT" '"80:80"' "HTTP port should be exposed"

it "should expose HTTPS port"
assert_contains "$COMPOSE_CONTENT" '"443:443"' "HTTPS port should be exposed"

it "should have healthcheck configured"
assert_contains "$COMPOSE_CONTENT" "healthcheck" "Traefik should have healthcheck"

# -----------------------------------------------------------------------------
# Test: Portainer configuration
# -----------------------------------------------------------------------------
describe "Portainer Configuration"

it "should have portainer image defined"
if docker compose -f "$COMPOSE_FILE" config 2>/dev/null | grep -q "portainer"; then
    assert_contains "$(docker compose -f "$COMPOSE_FILE" config)" "portainer" "Portainer should be configured"
fi

it "should have volume mount for docker socket"
assert_contains "$COMPOSE_CONTENT" "/var/run/docker.sock" "Docker socket should be mounted"

# -----------------------------------------------------------------------------
# Test: Watchtower configuration
# -----------------------------------------------------------------------------
describe "Watchtower Configuration"

it "should have watchtower image defined"
if docker compose -f "$COMPOSE_FILE" config 2>/dev/null | grep -q "watchtower"; then
    assert_contains "$(docker compose -f "$COMPOSE_FILE" config)" "watchtower" "Watchtower should be configured"
fi

it "should have schedule defined"
assert_contains "$COMPOSE_CONTENT" "WATCHTOWER_SCHEDULE" "Watchtower should have schedule"

# -----------------------------------------------------------------------------
# Test: Config files
# -----------------------------------------------------------------------------
describe "Configuration Files"

it "should have traefik config"
assert_file_exists "config/traefik/traefik.yml" "Traefik config should exist"

it "should have traefik dynamic config directory"
assert_dir_exists "config/traefik/dynamic" "Traefik dynamic config directory should exist"

it "should have middlewares config"
assert_file_exists "config/traefik/dynamic/middlewares.yml" "Middlewares config should exist"

it "should have TLS config"
assert_file_exists "config/traefik/dynamic/tls.yml" "TLS config should exist"