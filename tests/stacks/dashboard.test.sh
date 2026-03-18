#!/usr/bin/env bash
# =============================================================================
# Dashboard Stack Tests
# Tests for Homepage
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
source "$SCRIPT_DIR/../lib/assert.sh"
source "$SCRIPT_DIR/../lib/docker.sh"
source "$SCRIPT_DIR/../lib/report.sh"

print_section "Dashboard"

# Test containers
container_check homepage

# Test HTTP endpoints
http_check Homepage "http://localhost:3010"