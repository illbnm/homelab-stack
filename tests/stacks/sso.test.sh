#!/usr/bin/env bash
# sso.test.sh — SSO Stack Tests (Authentik)
set -euo pipefail

COMPOSE_FILE="${COMPOSE_FILE:-stacks/sso/docker-compose.yml}"

test_authentik_server_running() { test_start "Authentik server running"; assert_container_running "authentik-server"; test_end; }
test_authentik_server_healthy() { test_start "Authentik server healthy"; assert_container_healthy "authentik-server" 60; test_end; }
test_authentik_worker_running() { test_start "Authentik worker running"; assert_container_running "authentik-worker"; test_end; }
test_authentik_postgresql_running() { test_start "Authentik PostgreSQL running"; assert_container_running "authentik-postgresql"; test_end; }
test_authentik_postgresql_healthy() { test_start "Authentik PostgreSQL healthy"; assert_container_healthy "authentik-postgresql" 60; test_end; }
test_authentik_redis_running() { test_start "Authentik Redis running"; assert_container_running "authentik-redis"; test_end; }
test_authentik_redis_healthy() { test_start "Authentik Redis healthy"; assert_container_healthy "authentik-redis" 60; test_end; }
test_authentik_api() { test_start "Authentik API"; assert_http_status "http://localhost:9000/api/v3/core/users/?page_size=1" 200 30; test_end; }
test_compose_syntax() { test_start "SSO compose syntax valid"; assert_exit_code 0 docker compose -f "$COMPOSE_FILE" config --quiet; test_end; }
