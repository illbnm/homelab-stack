#!/usr/bin/env bash
# notifications.test.sh — Tests for the notifications stack

STACK_DIR="${REPO_ROOT}/stacks/notifications"
COMPOSE_FILE="${STACK_DIR}/docker-compose.yml"

NTFY_HOST="${NTFY_HOST:-localhost}"

# ── Level 1: Configuration Integrity ──────────────────────────────────────────

if docker compose -f "$COMPOSE_FILE" config --quiet 2>/dev/null; then
  assert_pass "notifications: compose syntax valid"
else
  assert_fail "notifications: compose syntax valid" "docker compose config failed"
fi

assert_no_latest_images "notifications: no :latest image tags" "$COMPOSE_FILE"

# ── Level 1: Container Health ──────────────────────────────────────────────────

if docker_container_exists "ntfy"; then
  assert_container_running "notifications: ntfy is running" "ntfy"
else
  assert_skip "notifications: ntfy is running" "container not deployed"
fi

# ── Level 2: HTTP Endpoints ────────────────────────────────────────────────────

if docker_container_exists "ntfy"; then
  assert_http_200 "notifications: ntfy health" \
    "http://${NTFY_HOST}:80/v1/health"
else
  assert_skip "notifications: ntfy health" "container not deployed"
fi
