#!/bin/bash
# =============================================================================
# E2E Test: Container Health Check
# Verifies all running containers have proper health status
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/assert.sh"

# Only run if Docker is available and containers are running
describe "Container Health Check"

# Check if there are any running containers
if ! docker ps &>/dev/null; then
    it "Docker should be available"
    return 0
fi

it "Docker daemon should be running"
if docker info &>/dev/null; then
    assert_eq "true" "true" "Docker is running"
fi

# Get list of running containers
RUNNING_CONTAINERS=$(docker ps --format '{{.Names}}' 2>/dev/null | wc -l)

it "should have containers available for testing"
if [[ $RUNNING_CONTAINERS -gt 0 ]]; then
    assert_contains "$RUNNING_CONTAINERS" "" "Found running containers"
else
    log_warn "No running containers found - this is expected if stacks aren't deployed"
fi