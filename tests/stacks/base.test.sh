#!/usr/bin/env bash
# =============================================================================
# Base Infrastructure Tests
# Tests for Traefik, Portainer, Watchtower
# =============================================================================

# Source library functions (relative to this script)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
source "$SCRIPT_DIR/../lib/assert.sh"
source "$SCRIPT_DIR/../lib/docker.sh"
source "$SCRIPT_DIR/../lib/report.sh"

# Print section header
print_section "Base Infrastructure"

# Test Traefik
container_check traefik
container_check portainer
container_check watchtower

# Test ports
port_check Traefik localhost 80
port_check Traefik-HTTPS localhost 443

# Test HTTP endpoints
http_check Traefik-Health "http://localhost:80/ping"
http_check Portainer "http://localhost:9000/api/status"