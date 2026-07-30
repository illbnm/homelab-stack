#!/usr/bin/env bash
# Databases Stack Tests — PostgreSQL + Redis + MariaDB
test_postgres_running() { assert_eq "$(container_status postgres)" "running" "PostgreSQL should be running"; }
test_postgres_healthy() {
  if container_healthy postgres; then return 0; fi
  return 1
}
test_redis_running() { assert_eq "$(container_status redis)" "running" "Redis should be running"; }
test_redis_healthy() {
  if container_healthy redis; then return 0; fi
  return 1
}
test_mariadb_running() { assert_eq "$(container_status mariadb)" "running" "MariaDB should be running"; }
test_mariadb_healthy() {
  if container_healthy mariadb; then return 0; fi
  return 1
}
test_postgres_connection() {
  local result; result=$(docker exec postgres pg_isready -U postgres 2>/dev/null || echo "")
  assert_contains "$result" "accepting" "PostgreSQL should accept connections"
}
test_redis_ping() {
  local result; result=$(docker exec redis redis-cli ping 2>/dev/null || echo "")
  assert_eq "$result" "PONG" "Redis should respond to ping"
}