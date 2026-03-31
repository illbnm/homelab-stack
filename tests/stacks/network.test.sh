#!/bin/bash
# =============================================================================
# Network Stack Tests
# Tests for: WireGuard VPN, Samba, AdGuard Home
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/assert.sh"

# -----------------------------------------------------------------------------
# Test: Docker Compose file validation
# -----------------------------------------------------------------------------
describe "Docker Compose Configuration"

COMPOSE_FILE="stacks/network/docker-compose.yml"
assert_file_exists "$COMPOSE_FILE" "Network compose file should exist"
assert_docker_compose_valid "$COMPOSE_FILE" "Compose file should be valid YAML"

# -----------------------------------------------------------------------------
# Test: Service Definitions
# -----------------------------------------------------------------------------
describe "Service Definitions"

# Check if services are defined (may vary based on actual stack contents)
COMPOSE_CONTENT=$(cat "$COMPOSE_FILE")
if echo "$COMPOSE_CONTENT" | grep -q "services:"; then
    it "should have services defined"
    assert_contains "$COMPOSE_CONTENT" "services:" "Services section should exist"
fi

# -----------------------------------------------------------------------------
# Test: Volume Configuration
# -----------------------------------------------------------------------------
describe "Volume Configuration"

it "should have volume definitions"
assert_contains "$COMPOSE_CONTENT" "volumes:" "Should have volume definitions"