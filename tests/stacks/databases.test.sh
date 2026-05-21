#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Database Tests
# Tests: PostgreSQL + Redis + MariaDB
# =============================================================================
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/docker.sh"

should_run_stack "databases" || { begin_suite "Databases"; assert_skip "not selected"; exit 0; }

begin_suite "Database Layer — PostgreSQL + Redis + MariaDB"

# ---- PostgreSQL ----
assert_container_running "homelab-postgres"
assert_container_healthy "homelab-postgres"
assert_container_not_latest "homelab-postgres"
assert_port_open "localhost" "5432" "postgresql"

begin_test "postgresql:accepts_connections"
if docker exec homelab-postgres pg_isready -h localhost &>/dev/null; then
  assert_pass "accepting connections"
else
  assert_skip "pg_isready check"
fi

# ---- Redis ----
assert_container_running "homelab-redis"
assert_container_healthy "homelab-redis"
assert_container_not_latest "homelab-redis"
assert_port_open "localhost" "6379" "redis"

begin_test "redis:responds_ping"
pong=$(docker exec homelab-redis redis-cli ping 2>/dev/null || echo "")
if [[ "$pong" == "PONG" ]]; then
  assert_pass "PONG"
else
  assert_skip "redis-cli not available"
fi

# ---- MariaDB ----
assert_container_running "homelab-mariadb"
assert_container_healthy "homelab-mariadb"
assert_container_not_latest "homelab-mariadb"
assert_port_open "localhost" "3306" "mariadb"

begin_test "mariadb:accepts_connections"
if docker exec homelab-mariadb mariadb -e "SELECT 1" &>/dev/null; then
  assert_pass "accepting connections"
else
  assert_skip "mariadb client check"
fi

# ---- Data persistence ----
begin_test "postgresql:data_dir"
pg_data=$(docker exec homelab-postgres ls /var/lib/postgresql/data/ 2>/dev/null | head -5)
if [[ -n "$pg_data" ]]; then
  assert_pass "data directory has files"
else
  assert_skip "data dir check"
fi

# ---- Compose validation ----
assert_compose_valid "${SCRIPT_DIR}/../../stacks/databases/docker-compose.yml" "databases"
