#!/usr/bin/env bash
# network.test.sh — Tests for the network stack

STACK_DIR="${REPO_ROOT}/stacks/network"
COMPOSE_FILE="${STACK_DIR}/docker-compose.yml"

ADGUARD_HOST="${ADGUARD_HOST:-localhost}"
NPM_HOST="${NPM_HOST:-localhost}"

# ── Level 1: Configuration Integrity ──────────────────────────────────────────

if docker compose -f "$COMPOSE_FILE" config --quiet 2>/dev/null; then
  assert_pass "network: compose syntax valid"
else
  assert_fail "network: compose syntax valid" "docker compose config failed"
fi

assert_no_latest_images "network: no :latest image tags" "$COMPOSE_FILE"

# ── Level 1: Container Health ──────────────────────────────────────────────────

for container in adguardhome nginx-proxy-manager wireguard; do
  if docker_container_exists "$container"; then
    assert_container_running "network: ${container} is running" "$container"
  else
    assert_skip "network: ${container} is running" "container not deployed"
  fi
done

# ── Level 2: HTTP Endpoints ────────────────────────────────────────────────────

if docker_container_exists "adguardhome"; then
  assert_http_200 "network: AdGuard web UI" \
    "http://${ADGUARD_HOST}:3000/"
else
  assert_skip "network: AdGuard web UI" "container not deployed"
fi

if docker_container_exists "nginx-proxy-manager"; then
  assert_http_200 "network: Nginx Proxy Manager web UI" \
    "http://${NPM_HOST}:81/"
else
  assert_skip "network: Nginx Proxy Manager web UI" "container not deployed"
fi
