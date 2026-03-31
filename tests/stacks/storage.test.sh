#!/bin/bash
# =============================================================================
# Storage Stack Tests
# Tests for: Nextcloud, MinIO, Syncthing
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/assert.sh"

# -----------------------------------------------------------------------------
# Test: Docker Compose file validation
# -----------------------------------------------------------------------------
describe "Docker Compose Configuration"

COMPOSE_FILE="stacks/storage/docker-compose.yml"
assert_file_exists "$COMPOSE_FILE" "Storage compose file should exist"
assert_docker_compose_valid "$COMPOSE_FILE" "Compose file should be valid YAML"

# -----------------------------------------------------------------------------
# Test: Configuration
# -----------------------------------------------------------------------------
describe "Configuration"

COMPOSE_CONTENT=$(cat "$COMPOSE_FILE")
it "should have services defined"
assert_contains "$COMPOSE_CONTENT" "services:" "Services section should exist"

it "should have volumes defined"
assert_contains "$COMPOSE_CONTENT" "volumes:" "Volumes should be defined"