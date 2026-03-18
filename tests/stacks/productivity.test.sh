#!/usr/bin/env bash
# =============================================================================
# Productivity Stack Tests
# Tests for Gitea, Vaultwarden, Outline, BookStack
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
source "$SCRIPT_DIR/../lib/assert.sh"
source "$SCRIPT_DIR/../lib/docker.sh"
source "$SCRIPT_DIR/../lib/report.sh"

print_section "Productivity Stack"

# Test containers
container_check gitea
container_check vaultwarden

# Test HTTP endpoints
http_check Gitea "http://localhost:3001"
http_check Vaultwarden "http://localhost:8080"