#!/usr/bin/env bash
# =============================================================================
# Network Stack Tests
# Tests for AdGuard Home, Nginx Proxy Manager, WireGuard
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
source "$SCRIPT_DIR/../lib/assert.sh"
source "$SCRIPT_DIR/../lib/docker.sh"
source "$SCRIPT_DIR/../lib/report.sh"

print_section "Network Stack"

# Test containers
container_check adguardhome
container_check nginx-proxy-manager
container_check wg-easy

# Test ports
port_check WireGuard localhost 51820