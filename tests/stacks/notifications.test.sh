#!/usr/bin/env bash
# notifications.test.sh — Notifications Stack Tests (ntfy)
set -euo pipefail

COMPOSE_FILE="${COMPOSE_FILE:-stacks/notifications/docker-compose.yml}"

test_ntfy_running() { test_start "ntfy running"; assert_container_running "ntfy"; test_end; }
test_ntfy_healthy() { test_start "ntfy healthy"; assert_container_healthy "ntfy" 30; test_end; }
test_ntfy_http() { test_start "ntfy HTTP"; assert_http_200 "http://localhost:2586" 10; test_end; }

test_compose_syntax() { test_start "Notifications compose syntax valid"; assert_exit_code 0 docker compose -f "$COMPOSE_FILE" config --quiet; test_end; }
