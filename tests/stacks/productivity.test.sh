#!/usr/bin/env bash
# productivity.test.sh — Tests for the productivity stack

STACK_DIR="${REPO_ROOT}/stacks/productivity"
COMPOSE_FILE="${STACK_DIR}/docker-compose.yml"

GITEA_HOST="${GITEA_HOST:-localhost}"
VAULTWARDEN_HOST="${VAULTWARDEN_HOST:-localhost}"

# ── Level 1: Configuration Integrity ──────────────────────────────────────────

if docker compose -f "$COMPOSE_FILE" config --quiet 2>/dev/null; then
  assert_pass "productivity: compose syntax valid"
else
  assert_fail "productivity: compose syntax valid" "docker compose config failed"
fi

assert_no_latest_images "productivity: no :latest image tags" "$COMPOSE_FILE"

# ── Level 1: Container Health ──────────────────────────────────────────────────

for container in gitea vaultwarden; do
  if docker_container_exists "$container"; then
    assert_container_running "productivity: ${container} is running" "$container"
  else
    assert_skip "productivity: ${container} is running" "container not deployed"
  fi
done

# ── Level 2: HTTP Endpoints ────────────────────────────────────────────────────

if docker_container_exists "gitea"; then
  assert_http_200 "productivity: Gitea web UI" \
    "http://${GITEA_HOST}:3000/"
  health_json=$(curl -s --max-time 10 \
    "http://${GITEA_HOST}:3000/api/healthz" 2>/dev/null || echo '{}')
  assert_json_value "productivity: Gitea API healthy" \
    "$health_json" '.status' "pass"
else
  assert_skip "productivity: Gitea web UI" "container not deployed"
  assert_skip "productivity: Gitea API healthy" "container not deployed"
fi

if docker_container_exists "vaultwarden"; then
  assert_http_200 "productivity: Vaultwarden web UI" \
    "http://${VAULTWARDEN_HOST}:80/"
else
  assert_skip "productivity: Vaultwarden web UI" "container not deployed"
fi
