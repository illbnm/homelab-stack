#!/usr/bin/env bash
# Database Stack Tests — PostgreSQL, Redis, MariaDB
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
source "$SCRIPT_DIR/../lib/assert.sh"
source "$SCRIPT_DIR/../lib/docker.sh"

reset_counters
log_test_start "Database Stack"

section "PostgreSQL"
assert_container_running "Postgres running" "homelab-postgres"
assert_container_healthy "Postgres healthy" "homelab-postgres"

section "Redis"
assert_container_running "Redis running" "homelab-redis"
assert_container_healthy "Redis healthy" "homelab-redis"
# Verify Redis auth works
local rpwd
rpwd=$(grep "^REDIS_PASSWORD=" "$ROOT_DIR/stacks/databases/.env.example" 2>/dev/null | cut -d= -f2 || echo "test")
TESTS_RUN=$((TESTS_RUN+1))
if docker exec homelab-redis redis-cli -a "$rpwd" ping 2>/dev/null | grep -q PONG; then
  pass "Redis AUTH works"
else
  fail "Redis AUTH failed"
fi

section "MariaDB"
assert_container_running "MariaDB running" "homelab-mariadb"
assert_container_healthy "MariaDB healthy" "homelab-mariadb"

assert_summary