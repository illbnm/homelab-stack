#!/usr/bin/env bash
# dashboard.test.sh — Dashboard Stack Tests (Homepage)
set -euo pipefail

COMPOSE_FILE="${COMPOSE_FILE:-stacks/dashboard/docker-compose.yml}"

test_homepage_running() { test_start "Homepage running"; assert_container_running "homepage"; test_end; }
test_homepage_healthy() { test_start "Homepage healthy"; assert_container_healthy "homepage" 30; test_end; }
test_homepage_http() { test_start "Homepage HTTP"; assert_http_200 "http://localhost:3010" 15; test_end; }

test_compose_syntax() { test_start "Dashboard compose syntax valid"; assert_exit_code 0 docker compose -f "$COMPOSE_FILE" config --quiet; test_end; }
