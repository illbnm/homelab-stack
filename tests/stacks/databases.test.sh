#!/usr/bin/env bash
# =============================================================================
# Databases Stack Tests
# Tests for PostgreSQL, Redis, MariaDB
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
source "$SCRIPT_DIR/../lib/assert.sh"
source "$SCRIPT_DIR/../lib/docker.sh"
source "$SCRIPT_DIR/../lib/report.sh"

print_section "Databases"

# Test containers
container_check homelab-postgres
container_check homelab-redis
container_check homelab-mariadb

# Test ports
port_check PostgreSQL localhost 5432
port_check Redis localhost 6379
port_check MariaDB localhost 3306