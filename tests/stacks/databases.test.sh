#!/usr/bin/env bash
# =============================================================================
# HomeLab — Database Tests
# =============================================================================
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib"; pwd)"
source "$_LIB_DIR/assert.sh"

test_databases_postgres_running() {
  assert_container_running "homelab-postgres" "PostgreSQL should be running"
}

test_databases_postgres_port() {
  assert_port_open "localhost" 5432 "PostgreSQL port 5432 should be open"
}

test_databases_redis_running() {
  assert_container_running "homelab-redis" "Redis should be running"
}

test_databases_redis_port() {
  assert_port_open "localhost" 6379 "Redis port 6379 should be open"
}

test_databases_redis_ping() {
  local redis_pass="${REDIS_PASSWORD:-}"
  local result
  if [[ -n "$redis_pass" ]]; then
    result=$(docker exec homelab-redis redis-cli -a "$redis_pass" ping 2>/dev/null || echo "")
  else
    result=$(docker exec homelab-redis redis-cli ping 2>/dev/null || echo "")
  fi
  assert_eq "$result" "PONG" "Redis should respond to PING"
}

test_databases_mariadb_running() {
  assert_container_running "homelab-mariadb" "MariaDB should be running"
}

test_databases_mariadb_port() {
  assert_port_open "localhost" 3306 "MariaDB port 3306 should be open"
}

test_databases_no_latest_tags() {
  assert_no_latest_images "$BASE_DIR/stacks/databases" "Databases stack should pin image versions"
}
