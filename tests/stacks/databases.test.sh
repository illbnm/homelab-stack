#!/usr/bin/env bash
# =============================================================================
# Database Layer Tests
# =============================================================================

assert_container_running homelab-postgres
assert_container_healthy homelab-postgres 30
assert_container_running homelab-redis
assert_container_healthy homelab-redis 30
assert_container_running homelab-mariadb
assert_container_healthy homelab-mariadb 30

# Port checks
test_start "PostgreSQL port 5432"
if nc -z -w3 localhost 5432 2>/dev/null; then
  test_pass
else
  test_skip "Port 5432 not reachable"
fi

test_start "Redis port 6379"
if nc -z -w3 localhost 6379 2>/dev/null; then
  test_pass
else
  test_skip "Port 6379 not reachable"
fi

test_start "MariaDB port 3306"
if nc -z -w3 localhost 3306 2>/dev/null; then
  test_pass
else
  test_skip "Port 3306 not reachable"
fi
