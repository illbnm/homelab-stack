#!/usr/bin/env bash
# =============================================================================
# databases.test.sh — Database stack tests (postgres, redis, mariadb)
# =============================================================================

# ---------------------------------------------------------------------------
# Level 1: Container health
# ---------------------------------------------------------------------------
test_suite "Databases — Containers"

test_postgres_running() {
  assert_container_running "homelab-postgres"
  assert_container_healthy "homelab-postgres"
}

test_redis_running() {
  assert_container_running "homelab-redis"
  assert_container_healthy "homelab-redis"
}

test_mariadb_running() {
  assert_container_running "homelab-mariadb"
  assert_container_healthy "homelab-mariadb"
}

test_postgres_running
test_redis_running
test_mariadb_running

# ---------------------------------------------------------------------------
# Level 2: Port reachability
# ---------------------------------------------------------------------------
if [[ ${TEST_LEVEL:-99} -ge 2 ]]; then
  test_suite "Databases — Connectivity"

  test_postgres_port() {
    assert_port_open "localhost" 5432 "PostgreSQL port 5432"
  }

  test_redis_port() {
    assert_port_open "localhost" 6379 "Redis port 6379"
  }

  test_mariadb_port() {
    assert_port_open "localhost" 3306 "MariaDB port 3306"
  }

  test_postgres_port
  test_redis_port
  test_mariadb_port
fi

# ---------------------------------------------------------------------------
# Level 3: Database operations
# ---------------------------------------------------------------------------
if [[ ${TEST_LEVEL:-99} -ge 3 ]]; then
  test_suite "Databases — Operations"

  test_postgres_query() {
    local result
    result=$(docker_run_in "homelab-postgres" \
      psql -U "${POSTGRES_ROOT_USER:-postgres}" -d postgres -tAc "SELECT 1;" 2>/dev/null || echo "")
    assert_eq "$result" "1" "PostgreSQL SELECT 1 query"
  }

  test_redis_ping() {
    local result
    result=$(docker_run_in "homelab-redis" redis-cli ping 2>/dev/null || echo "")
    assert_eq "$result" "PONG" "Redis PING response"
  }

  test_mariadb_query() {
    local result
    result=$(docker_run_in "homelab-mariadb" \
      mariadb -u root -p"${MARIADB_ROOT_PASSWORD:-}" -e "SELECT 1;" --skip-column-names 2>/dev/null || echo "")
    assert_contains "$result" "1" "MariaDB SELECT 1 query"
  }

  test_postgres_query
  test_redis_ping
  test_mariadb_query
fi
