#!/usr/bin/env bash
# home-automation.test.sh — Home Automation Stack Tests (Home Assistant, Node-RED)
set -euo pipefail

COMPOSE_FILE="${COMPOSE_FILE:-stacks/home-automation/docker-compose.yml}"

test_ha_running() { test_start "Home Assistant running"; assert_container_running "homeassistant"; test_end; }
test_ha_healthy() { test_start "Home Assistant healthy"; assert_container_healthy "homeassistant" 120; test_end; }
test_ha_http() { test_start "Home Assistant HTTP"; assert_http_200 "http://localhost:8123" 15; test_end; }

test_nodered_running() { test_start "Node-RED running"; assert_container_running "node-red"; test_end; }
test_nodered_healthy() { test_start "Node-RED healthy"; assert_container_healthy "node-red" 60; test_end; }
test_nodered_http() { test_start "Node-RED HTTP"; assert_http_200 "http://localhost:1880" 15; test_end; }

test_compose_syntax() { test_start "Home Automation compose syntax valid"; assert_exit_code 0 docker compose -f "$COMPOSE_FILE" config --quiet; test_end; }
