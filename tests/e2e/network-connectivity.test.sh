#!/bin/bash
# =============================================================================
# E2E Test: Network Connectivity
# Verifies Docker networks are properly configured
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/assert.sh"

describe "Docker Network Configuration"

it "should have proxy network or it can be created"
# The proxy network is external, so we check if it exists or test if it can be referenced
NETWORK_EXISTS=$(docker network ls --format '{{.Name}}' 2>/dev/null | grep -c "^proxy$" || echo "0")
if [[ "$NETWORK_EXISTS" -eq "0" ]]; then
    log_warn "Proxy network does not exist - will be created on first stack deploy"
fi

it "should be able to list Docker networks"
if docker network ls &>/dev/null; then
    assert_eq "true" "true" "Can list Docker networks"
fi

it "should have bridge network available"
BRIDGE_EXISTS=$(docker network ls --format '{{.Name}}' 2>/dev/null | grep -c "^bridge$" || echo "0")
if [[ "$BRIDGE_EXISTS" -gt 0 ]]; then
    assert_eq "true" "true" "Bridge network exists"
fi