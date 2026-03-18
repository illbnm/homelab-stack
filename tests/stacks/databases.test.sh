#!/usr/bin/env bash
# databases.test.sh — Database Stack Tests (PostgreSQL, Redis, MariaDB)
set -euo pipefail

COMPOSE_FILE="${COMPOSE_FILE:-stacks/databases/docker-compose.yml}"

test_postgres_running() { test_start "PostgreSQL running"; assert_container_running "homelab-postgres"; test_end; }
test_postgres_healthy() { test_start "PostgreSQL healthy"; assert_container_healthy "homelab-postgres" 60; test_end; }
test_postgres_port() { test_start "PostgreSQL port 5432"; assert_port_open localhost 5432; test_end; }

test_redis_running() { test_start "Redis running"; assert_container_running "homelab-redis"; test_end; }
test_redis_healthy() { test_start "Redis healthy"; assert_container_healthy "homelab-redis" 30; test_end; }
test_redis_port() { test_start "Redis port 6379"; assert_port_open localhost 6379; test_end; }

test_mariadb_running() { test_start "MariaDB running"; assert_container_running "homelab-mariadb"; test_end; }
test_mariadb_healthy() { test_start "MariaDB healthy"; assert_container_healthy "homelab-mariadb" 60; test_end; }
test_mariadb_port() { test_start "MariaDB port 3306"; assert_port_open localhost 3306; test_end; }

test_compose_syntax() { test_start "Databases compose syntax valid"; assert_exit_code 0 docker compose -f "$COMPOSE_FILE" config --quiet; test_end; }
