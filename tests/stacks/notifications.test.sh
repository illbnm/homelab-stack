#!/usr/bin/env bash
# =============================================================================
# Notifications Stack Tests
# Tests for ntfy, Gotify
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
source "$SCRIPT_DIR/../lib/assert.sh"
source "$SCRIPT_DIR/../lib/docker.sh"
source "$SCRIPT_DIR/../lib/report.sh"

print_section "Notifications"

# Test containers
container_check ntfy

# Test HTTP endpoints
http_check ntfy "http://localhost:2586"