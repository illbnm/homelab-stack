#!/usr/bin/env bash
# productivity.test.sh — Productivity Stack Tests (Gitea, Vaultwarden)
set -euo pipefail

COMPOSE_FILE="${COMPOSE_FILE:-stacks/productivity/docker-compose.yml}"

test_gitea_running() { test_start "Gitea running"; assert_container_running "gitea"; test_end; }
test_gitea_healthy() { test_start "Gitea healthy"; assert_container_healthy "gitea" 60; test_end; }
test_gitea_http() { test_start "Gitea /api/v1/version"; assert_http_200 "http://localhost:3001/api/v1/version" 15; test_end; }

test_vaultwarden_running() { test_start "Vaultwarden running"; assert_container_running "vaultwarden"; test_end; }
test_vaultwarden_healthy() { test_start "Vaultwarden healthy"; assert_container_healthy "vaultwarden" 60; test_end; }
test_vaultwarden_http() { test_start "Vaultwarden HTTP"; assert_http_200 "http://localhost:8080" 15; test_end; }

test_compose_syntax() { test_start "Productivity compose syntax valid"; assert_exit_code 0 docker compose -f "$COMPOSE_FILE" config --quiet; test_end; }
