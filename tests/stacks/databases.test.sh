#!/usr/bin/env bash
# =============================================================================
# Databases Stack Tests — PostgreSQL, Redis, MariaDB
# =============================================================================

log_group "Databases"

# --- Level 1: Container health ---

test_postgres_running() {
  assert_container_running "homelab-postgres"
  assert_container_healthy "homelab-postgres"
  assert_container_not_restarting "homelab-postgres"
}

test_redis_running() {
  assert_container_running "homelab-redis"
  assert_container_healthy "homelab-redis"
  assert_container_not_restarting "homelab-redis"
}

test_mariadb_running() {
  assert_container_running "homelab-mariadb"
  assert_container_healthy "homelab-mariadb"
  assert_container_not_restarting "homelab-mariadb"
}

test_postgres_running
test_redis_running
test_mariadb_running

# --- Level 1: Network ---
test_databases_network() {
  assert_network_exists "databases"
  for c in homelab-postgres homelab-redis homelab-mariadb; do
    if is_container_running "$c"; then
      assert_container_on_network "$c" "databases"
    fi
  done
}

test_databases_network

# --- Level 2: Port accessibility ---
if [[ "${TEST_LEVEL:-99}" -ge 2 ]]; then
  test_database_ports() {
    if is_container_running "homelab-postgres"; then
      assert_port_open "localhost" 5432 "PostgreSQL port 5432"
    else
      skip_test "PostgreSQL port check" "container not running"
    fi

    if is_container_running "homelab-redis"; then
      assert_port_open "localhost" 6379 "Redis port 6379"
    else
      skip_test "Redis port check" "container not running"
    fi

    if is_container_running "homelab-mariadb"; then
      assert_port_open "localhost" 3306 "MariaDB port 3306"
    else
      skip_test "MariaDB port check" "container not running"
    fi
  }

  test_database_ports
fi

# --- Level 3: Service interconnection ---
if [[ "${TEST_LEVEL:-99}" -ge 3 ]]; then

  test_postgres_accepts_connections() {
    require_container "homelab-postgres" || return
    local result
    result=$(docker_exec "homelab-postgres" pg_isready -U "${POSTGRES_ROOT_USER:-postgres}" 2>/dev/null)
    assert_contains "$result" "accepting connections" "PostgreSQL accepting connections"
  }

  test_redis_responds_to_ping() {
    require_container "homelab-redis" || return
    local result
    result=$(docker_exec "homelab-redis" redis-cli -a "${REDIS_PASSWORD:-changeme}" ping 2>/dev/null)
    assert_eq "$result" "PONG" "Redis PING → PONG"
  }

  test_mariadb_accepts_connections() {
    require_container "homelab-mariadb" || return
    local result
    result=$(docker_exec "homelab-mariadb" healthcheck.sh --connect 2>/dev/null; echo $?)
    assert_eq "$result" "0" "MariaDB accepts connections"
  }

  # Verify init databases were created
  test_postgres_databases_exist() {
    require_container "homelab-postgres" || return
    local dbs
    dbs=$(docker_exec "homelab-postgres" psql -U "${POSTGRES_ROOT_USER:-postgres}" -lqt 2>/dev/null | awk -F'|' '{print $1}' | tr -d ' ')
    for db in gitea nextcloud outline vaultwarden; do
      if echo "$dbs" | grep -q "^${db}$"; then
        _record_result pass "PostgreSQL database '$db' exists"
      else
        _record_result fail "PostgreSQL database '$db' exists" "not found"
      fi
    done
  }

  test_postgres_accepts_connections
  test_redis_responds_to_ping
  test_mariadb_accepts_connections
  test_postgres_databases_exist
fi

# --- Image tags ---
for c in homelab-postgres homelab-redis homelab-mariadb; do
  if is_container_running "$c"; then
    assert_container_image_not_latest "$c"
  fi
done
