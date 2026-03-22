#!/usr/bin/env bash
# databases.test.sh — Tests for the databases stack

STACK_DIR="${REPO_ROOT}/stacks/databases"
COMPOSE_FILE="${STACK_DIR}/docker-compose.yml"

# ── Level 1: Configuration Integrity ──────────────────────────────────────────

if docker compose -f "$COMPOSE_FILE" config --quiet 2>/dev/null; then
  assert_pass "databases: compose syntax valid"
else
  assert_fail "databases: compose syntax valid" "docker compose config failed"
fi

assert_no_latest_images "databases: no :latest image tags" "$COMPOSE_FILE"

# ── Level 1: Container Health ──────────────────────────────────────────────────

for container in postgres redis mariadb; do
  if docker_container_exists "$container"; then
    assert_container_running "databases: ${container} is running" "$container"
    assert_container_healthy "databases: ${container} is healthy" "$container" 60
  else
    assert_skip "databases: ${container} is running" "container not deployed"
    assert_skip "databases: ${container} is healthy" "container not deployed"
  fi
done

# ── Level 2: Port Connectivity ────────────────────────────────────────────────

POSTGRES_HOST="${POSTGRES_HOST:-localhost}"
REDIS_HOST="${REDIS_HOST:-localhost}"
MARIADB_HOST="${MARIADB_HOST:-localhost}"

if docker_container_exists "postgres"; then
  if bash -c "echo > /dev/tcp/${POSTGRES_HOST}/5432" 2>/dev/null; then
    assert_pass "databases: PostgreSQL port 5432 reachable"
  else
    assert_fail "databases: PostgreSQL port 5432 reachable" "port not open"
  fi
else
  assert_skip "databases: PostgreSQL port reachable" "container not deployed"
fi

if docker_container_exists "redis"; then
  if bash -c "echo > /dev/tcp/${REDIS_HOST}/6379" 2>/dev/null; then
    assert_pass "databases: Redis port 6379 reachable"
  else
    assert_fail "databases: Redis port 6379 reachable" "port not open"
  fi
else
  assert_skip "databases: Redis port reachable" "container not deployed"
fi

if docker_container_exists "mariadb"; then
  if bash -c "echo > /dev/tcp/${MARIADB_HOST}/3306" 2>/dev/null; then
    assert_pass "databases: MariaDB port 3306 reachable"
  else
    assert_fail "databases: MariaDB port 3306 reachable" "port not open"
  fi
else
  assert_skip "databases: MariaDB port reachable" "container not deployed"
fi
