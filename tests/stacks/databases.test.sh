#!/usr/bin/env bash
# =============================================================================
# Database Stack Tests
# =============================================================================

test_postgres_running() {
  assert_container_running "homelab-postgres"
}

test_postgres_healthy() {
  assert_container_healthy "homelab-postgres" 60
}

test_postgres_port() {
  assert_port_open "localhost" "5432"
}

test_redis_running() {
  assert_container_running "homelab-redis"
}

test_redis_healthy() {
  assert_container_healthy "homelab-redis" 30
}

test_redis_port() {
  assert_port_open "localhost" "6379"
}

test_mariadb_running() {
  assert_container_running "homelab-mariadb"
}

test_mariadb_port() {
  assert_port_open "localhost" "3306"
}

run_test_with_timing "databases" test_postgres_running "PostgreSQL running"
run_test_with_timing "databases" test_postgres_healthy "PostgreSQL healthy"
run_test_with_timing "databases" test_postgres_port "PostgreSQL port 5432"
run_test_with_timing "databases" test_redis_running "Redis running"
run_test_with_timing "databases" test_redis_healthy "Redis healthy"
run_test_with_timing "databases" test_redis_port "Redis port 6379"
run_test_with_timing "databases" test_mariadb_running "MariaDB running"
run_test_with_timing "databases" test_mariadb_port "MariaDB port 3306"
