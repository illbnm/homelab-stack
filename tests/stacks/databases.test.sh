#!/usr/bin/env bash
# =============================================================================
# databases.test.sh — Databases stack tests
# Services: PostgreSQL, Redis, MariaDB
# =============================================================================

# --- PostgreSQL ---

test_postgres_running() {
  assert_container_running "postgres"
}

test_postgres_healthy() {
  assert_container_healthy "postgres"
}

test_postgres_accepting_connections() {
  local msg="PostgreSQL accepting connections"
  if docker exec postgres pg_isready -U "${POSTGRES_USER:-postgres}" &>/dev/null; then
    _assert_pass "$msg"
  else
    _assert_fail "$msg" "pg_isready failed"
  fi
}

test_postgres_no_crash_loop() {
  assert_no_crash_loop "postgres" 3
}

test_postgres_data_volume() {
  assert_volume_exists "postgres-data"
}

test_postgres_no_fatal_errors() {
  assert_log_no_errors "postgres" "FATAL\|PANIC" "1h"
}

# --- Redis ---

test_redis_running() {
  assert_container_running "redis"
}

test_redis_healthy() {
  assert_container_healthy "redis"
}

test_redis_ping() {
  local msg="Redis responds to PING"
  local result
  result=$(docker exec redis redis-cli ping 2>/dev/null) || {
    _assert_fail "$msg" "redis-cli failed"
    return 1
  }

  if [[ "$result" == "PONG" ]]; then
    _assert_pass "$msg"
  else
    _assert_fail "$msg" "Expected: PONG, Got: ${result}"
  fi
}

test_redis_no_crash_loop() {
  assert_no_crash_loop "redis" 3
}

test_redis_data_volume() {
  assert_volume_exists "redis-data"
}

# --- MariaDB ---

test_mariadb_running() {
  assert_container_running "mariadb"
}

test_mariadb_healthy() {
  assert_container_healthy "mariadb"
}

test_mariadb_accepting_connections() {
  local msg="MariaDB accepting connections"
  if docker exec mariadb mariadb-admin ping -u root -p"${MARIADB_ROOT_PASSWORD:-root}" &>/dev/null; then
    _assert_pass "$msg"
  else
    _assert_fail "$msg" "mariadb-admin ping failed"
  fi
}

test_mariadb_no_crash_loop() {
  assert_no_crash_loop "mariadb" 3
}

test_mariadb_data_volume() {
  assert_volume_exists "mariadb-data"
}
