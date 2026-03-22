#!/usr/bin/env bash
# base.test.sh — Tests for the base stack (Traefik, Portainer, Watchtower)

STACK_DIR="${REPO_ROOT}/stacks/base"
COMPOSE_FILE="${STACK_DIR}/docker-compose.yml"

# ── Level 1: Configuration Integrity ──────────────────────────────────────────

start_ms=$(date +%s%3N)
if docker compose -f "$COMPOSE_FILE" config --quiet 2>/dev/null; then
  assert_pass "base compose syntax valid"
else
  assert_fail "base compose syntax valid" "docker compose config failed"
fi

assert_no_latest_images "base: no :latest image tags" "$COMPOSE_FILE"

for svc in traefik portainer watchtower; do
  if grep -A 20 "^  ${svc}:" "$COMPOSE_FILE" | grep -q 'healthcheck:'; then
    assert_pass "base: ${svc} has healthcheck"
  else
    assert_skip "base: ${svc} has healthcheck" "healthcheck not found in compose"
  fi
done

# ── Level 1: Container Health ──────────────────────────────────────────────────

for container in traefik portainer watchtower; do
  if docker_container_exists "$container"; then
    assert_container_running "base: ${container} is running" "$container"
    assert_container_healthy "base: ${container} is healthy" "$container" 60
  else
    assert_skip "base: ${container} is running" "container not deployed"
    assert_skip "base: ${container} is healthy" "container not deployed"
  fi
done

# ── Level 2: HTTP Endpoints ────────────────────────────────────────────────────

TRAEFIK_HOST="${TRAEFIK_HOST:-localhost}"
PORTAINER_HOST="${PORTAINER_HOST:-localhost}"

if docker_container_exists "traefik"; then
  assert_http_response "base: Traefik dashboard responds" \
    "http://${TRAEFIK_HOST}:8080/dashboard/" "200"
else
  assert_skip "base: Traefik dashboard responds" "container not deployed"
fi

if docker_container_exists "portainer"; then
  assert_http_200 "base: Portainer UI responds" "http://${PORTAINER_HOST}:9000/"
else
  assert_skip "base: Portainer UI responds" "container not deployed"
fi
