#!/usr/bin/env bash
# network.test.sh — Network Stack Tests (AdGuard Home, Nginx Proxy Manager, WireGuard)
set -euo pipefail

COMPOSE_FILE="${COMPOSE_FILE:-stacks/network/docker-compose.yml}"

test_adguard_running() { test_start "AdGuard Home running"; assert_container_running "adguardhome"; test_end; }
test_adguard_healthy() { test_start "AdGuard Home healthy"; assert_container_healthy "adguardhome" 60; test_end; }
test_adguard_http() { test_start "AdGuard Home /control/status"; assert_http_200 "http://localhost/control/status" 15; test_end; }

test_npm_running() { test_start "Nginx Proxy Manager running"; assert_container_running "nginx-proxy-manager"; test_end; }
test_npm_healthy() { test_start "Nginx Proxy Manager healthy"; assert_container_healthy "nginx-proxy-manager" 60; test_end; }
test_npm_http() { test_start "Nginx Proxy Manager HTTP"; assert_http_200 "http://localhost:81" 15; test_end; }

test_wireguard_running() { test_start "WireGuard running"; assert_container_running "wg-easy"; test_end; }
test_wireguard_port() { test_start "WireGuard port 51820"; assert_port_open localhost 51820; test_end; }

test_compose_syntax() { test_start "Network compose syntax valid"; assert_exit_code 0 docker compose -f "$COMPOSE_FILE" config --quiet; test_end; }
