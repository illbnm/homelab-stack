#!/usr/bin/env bash
# ai.test.sh — Tests for the AI stack (Ollama, Open WebUI)

STACK_DIR="${REPO_ROOT}/stacks/ai"
COMPOSE_FILE="${STACK_DIR}/docker-compose.yml"

OLLAMA_HOST="${OLLAMA_HOST:-localhost}"
OPENWEBUI_HOST="${OPENWEBUI_HOST:-localhost}"

# ── Level 1: Configuration Integrity ──────────────────────────────────────────

if docker compose -f "$COMPOSE_FILE" config --quiet 2>/dev/null; then
  assert_pass "ai: compose syntax valid"
else
  assert_fail "ai: compose syntax valid" "docker compose config failed"
fi

assert_no_latest_images "ai: no :latest image tags" "$COMPOSE_FILE"

# ── Level 1: Container Health ──────────────────────────────────────────────────

for container in ollama open-webui; do
  if docker_container_exists "$container"; then
    assert_container_running "ai: ${container} is running" "$container"
  else
    assert_skip "ai: ${container} is running" "container not deployed"
  fi
done

# ── Level 2: HTTP Endpoints ────────────────────────────────────────────────────

if docker_container_exists "ollama"; then
  ollama_resp=$(curl -s --max-time 10 \
    "http://${OLLAMA_HOST}:11434/api/tags" 2>/dev/null || echo '{}')
  assert_json_key_exists "ai: Ollama API responds" "$ollama_resp" '.models'
else
  assert_skip "ai: Ollama API responds" "container not deployed"
fi

if docker_container_exists "open-webui"; then
  assert_http_200 "ai: Open WebUI responds" \
    "http://${OPENWEBUI_HOST}:8080/"
else
  assert_skip "ai: Open WebUI responds" "container not deployed"
fi
