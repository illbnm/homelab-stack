#!/bin/bash
# =============================================================================
# Productivity Stack Tests
# Tests for: Gitea, Woodpecker, Renovate
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/assert.sh"

COMPOSE_FILE="stacks/productivity/docker-compose.yml"
describe "Docker Compose Configuration"
assert_file_exists "$COMPOSE_FILE" "Productivity compose file should exist"
assert_docker_compose_valid "$COMPOSE_FILE" "Compose file should be valid YAML"

COMPOSE_CONTENT=$(cat "$COMPOSE_FILE")
describe "Service Definitions"
assert_contains "$COMPOSE_CONTENT" "services:" "Services should be defined"