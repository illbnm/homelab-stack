#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Databases Tests
# Services: PostgreSQL, Redis, MariaDB (shared)
# =============================================================================

COMPOSE_FILE="$BASE_DIR/stacks/databases/docker-compose.yml"

# ===========================================================================
# Level 1 — Configuration Integrity
# ===========================================================================
if [[ "${TEST_LEVEL:-0}" -eq 0 || "${TEST_LEVEL:-0}" -le 1 ]]; then
  test_group "Databases — Configuration"

  assert_compose_valid "$COMPOSE_FILE"
fi

# ===========================================================================
# Level 1 — Container Health
# ===========================================================================
if [[ "${TEST_LEVEL:-0}" -eq 0 || "${TEST_LEVEL:-0}" -le 1 ]]; then
  test_group "Databases — Container Health"

  assert_container_running "homelab-postgres"
  assert_container_healthy "homelab-postgres"
  assert_container_not_restarting "homelab-postgres"

  assert_container_running "homelab-redis"
  assert_container_healthy "homelab-redis"
  assert_container_not_restarting "homelab-redis"

  assert_container_running "homelab-mariadb"
  assert_container_healthy "homelab-mariadb"
  assert_container_not_restarting "homelab-mariadb"
fi

# ===========================================================================
# Level 2 — Port Availability
# ===========================================================================
if [[ "${TEST_LEVEL:-0}" -eq 0 || "${TEST_LEVEL:-0}" -ge 2 ]]; then
  test_group "Databases — Port Checks"

  assert_port_open "localhost" 5432 "PostgreSQL port 5432"
  assert_port_open "localhost" 6379 "Redis port 6379"
  assert_port_open "localhost" 3306 "MariaDB port 3306"
fi

# ===========================================================================
# Level 3 — Connectivity Tests
# ===========================================================================
if [[ "${TEST_LEVEL:-0}" -eq 0 || "${TEST_LEVEL:-0}" -ge 3 ]]; then
  test_group "Databases — Connectivity"

  assert_docker_network_exists "databases"

  # PostgreSQL: verify we can run a query
  assert_docker_exec "homelab-postgres" \
    "PostgreSQL accepts connections" \
    pg_isready -U "${POSTGRES_ROOT_USER:-postgres}"

  # Redis: verify PING
  if is_container_running "homelab-redis"; then
    redis_reply=$(docker exec homelab-redis redis-cli -a "${REDIS_PASSWORD:-changeme}" ping 2>/dev/null)
    assert_eq "$redis_reply" "PONG" "Redis responds to PING"
  else
    skip_test "Redis responds to PING" "container not running"
  fi

  # MariaDB: verify connection
  assert_docker_exec "homelab-mariadb" \
    "MariaDB accepts connections" \
    healthcheck.sh --connect --innodb_initialized
fi
