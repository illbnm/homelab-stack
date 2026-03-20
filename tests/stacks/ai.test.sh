#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — AI Tests
# Services: Ollama, Open WebUI, Stable Diffusion
# =============================================================================

COMPOSE_FILE="$BASE_DIR/stacks/ai/docker-compose.yml"

# ===========================================================================
# Level 1 — Configuration Integrity
# ===========================================================================
if [[ "${TEST_LEVEL:-0}" -eq 0 || "${TEST_LEVEL:-0}" -le 1 ]]; then
  test_group "AI — Configuration"

  assert_compose_valid "$COMPOSE_FILE"
fi

# ===========================================================================
# Level 1 — Container Health
# ===========================================================================
if [[ "${TEST_LEVEL:-0}" -eq 0 || "${TEST_LEVEL:-0}" -le 1 ]]; then
  test_group "AI — Container Health"

  assert_container_running "ollama"
  assert_container_healthy "ollama"
  assert_container_not_restarting "ollama"

  assert_container_running "open-webui"
  assert_container_healthy "open-webui"
  assert_container_not_restarting "open-webui"

  assert_container_running "stable-diffusion"
  assert_container_healthy "stable-diffusion"
  assert_container_not_restarting "stable-diffusion"
fi

# ===========================================================================
# Level 2 — HTTP Endpoints
# ===========================================================================
if [[ "${TEST_LEVEL:-0}" -eq 0 || "${TEST_LEVEL:-0}" -ge 2 ]]; then
  test_group "AI — HTTP Endpoints"

  # Ollama API
  assert_http_ok "http://localhost:11434/api/version" \
    "Ollama /api/version"

  assert_http_ok "http://localhost:11434/api/tags" \
    "Ollama /api/tags"

  # Open WebUI health
  assert_http_ok "http://localhost:8080/health" \
    "Open WebUI /health"

  # Stable Diffusion (may take longer to start)
  assert_http_ok "http://localhost:7860" \
    "Stable Diffusion web UI"
fi

# ===========================================================================
# Level 3 — Interconnection
# ===========================================================================
if [[ "${TEST_LEVEL:-0}" -eq 0 || "${TEST_LEVEL:-0}" -ge 3 ]]; then
  test_group "AI — Interconnection"

  assert_container_in_network "ollama" "proxy"
  assert_container_in_network "open-webui" "proxy"

  # Open WebUI → Ollama connectivity
  if is_container_running "open-webui" && is_container_running "ollama"; then
    assert_docker_exec "open-webui" \
      "Open WebUI can reach Ollama" \
      curl -sf --connect-timeout 5 "http://ollama:11434/api/tags"
  else
    skip_test "Open WebUI can reach Ollama" "open-webui or ollama not running"
  fi
fi
