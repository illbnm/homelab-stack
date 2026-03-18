#!/usr/bin/env bash
# =============================================================================
# SSO Stack Tests
# Tests for Authentik (server, worker, postgresql, redis)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
source "$SCRIPT_DIR/../lib/assert.sh"
source "$SCRIPT_DIR/../lib/docker.sh"
source "$SCRIPT_DIR/../lib/report.sh"

print_section "SSO (Authentik)"

# Test containers
container_check authentik-server
container_check authentik-worker
container_check authentik-postgresql
container_check authentik-redis

# Test HTTP endpoints
http_check Authentik "http://localhost:9000/if/flow/default-authentication-flow/"