#!/usr/bin/env bash
# sso.test.sh — Tests for the SSO stack (Authentik)

STACK_DIR="${REPO_ROOT}/stacks/sso"
COMPOSE_FILE="${STACK_DIR}/docker-compose.yml"

AUTHENTIK_HOST="${AUTHENTIK_HOST:-localhost}"

# ── Level 1: Configuration Integrity ──────────────────────────────────────────

if docker compose -f "$COMPOSE_FILE" config --quiet 2>/dev/null; then
  assert_pass "sso: compose syntax valid"
else
  assert_fail "sso: compose syntax valid" "docker compose config failed"
fi

assert_no_latest_images "sso: no :latest image tags" "$COMPOSE_FILE"

# ── Level 1: Container Health ──────────────────────────────────────────────────

for container in authentik-server authentik-worker; do
  if docker_container_exists "$container"; then
    assert_container_running "sso: ${container} is running" "$container"
    assert_container_healthy "sso: ${container} is healthy" "$container" 90
  else
    assert_skip "sso: ${container} is running" "container not deployed"
    assert_skip "sso: ${container} is healthy" "container not deployed"
  fi
done

# ── Level 2: HTTP Endpoints ────────────────────────────────────────────────────

if docker_container_exists "authentik-server"; then
  assert_http_200 "sso: Authentik health endpoint" \
    "http://${AUTHENTIK_HOST}:9000/-/health/ready/"
  assert_http_200 "sso: Authentik login page" \
    "http://${AUTHENTIK_HOST}:9000/if/flow/default-authentication-flow/"
else
  assert_skip "sso: Authentik health endpoint" "container not deployed"
  assert_skip "sso: Authentik login page" "container not deployed"
fi
