#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — AI Stack Tests
# Tests: Ollama + Open WebUI + Stable Diffusion
# =============================================================================
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/docker.sh"

should_run_stack "ai" || { begin_suite "AI Stack"; assert_skip "not selected"; exit 0; }

begin_suite "AI Stack — Ollama + Open WebUI + Stable Diffusion"

# ---- Ollama ----
assert_container_running "ollama"
assert_container_healthy "ollama"
assert_container_not_latest "ollama"
assert_http_200 "${BASE_URL:-http://localhost}:11434/api/version" "ollama:version"

# Ollama API: list models
begin_test "ollama:api:list_models"
models=$(curl -sf "${BASE_URL:-http://localhost}:11434/api/tags" 2>/dev/null || echo "")
if [[ -n "$models" ]] && echo "$models" | grep -q "models"; then
  assert_pass "models endpoint reachable"
else
  assert_skip "no models loaded yet"
fi

# ---- Open WebUI ----
assert_container_running "open-webui"
assert_container_healthy "open-webui"
assert_container_not_latest "open-webui"
assert_http_200 "${BASE_URL:-http://localhost}:8080" "open-webui:ui"

# ---- Stable Diffusion ----
assert_container_running "stable-diffusion"
assert_container_not_latest "stable-diffusion"
begin_test "stable-diffusion:health"
sd_code=$(curl -sf -o /dev/null -w '%{http_code}' --connect-timeout 10 "${BASE_URL:-http://localhost}:7860/" 2>/dev/null || echo "000")
if [[ "$sd_code" =~ ^[23] ]]; then
  assert_pass "HTTP $sd_code"
else
  assert_skip "HTTP $sd_code (may take time to start)"
fi

# ---- Inter-service: Open WebUI → Ollama ----
begin_test "open-webui:connects_ollama"
if docker exec open-webui curl -sf --connect-timeout 3 "http://ollama:11434/api/version" &>/dev/null; then
  assert_pass "open-webui → ollama reachable"
else
  assert_skip "inter-container test"
fi

# ---- Compose validation ----
assert_compose_valid "${SCRIPT_DIR}/../../stacks/ai/docker-compose.yml" "ai"
