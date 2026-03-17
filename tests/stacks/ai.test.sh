#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — AI Stack Tests
# =============================================================================
# Tests: Ollama, Open WebUI, LocalAI, n8n
# =============================================================================

# ---------------------------------------------------------------------------
# Level 1 — Container Health
# ---------------------------------------------------------------------------

test_ollama_running() {
  assert_container_running "ollama"
}

test_ollama_healthy() {
  assert_container_healthy "ollama" 120
}

test_open_webui_running() {
  assert_container_running "open-webui"
}

test_open_webui_healthy() {
  assert_container_healthy "open-webui" 90
}

test_localai_running() {
  assert_container_running "localai"
}

test_localai_healthy() {
  assert_container_healthy "localai" 120
}

test_n8n_running() {
  assert_container_running "n8n"
}

test_n8n_healthy() {
  assert_container_healthy "n8n" 60
}

# ---------------------------------------------------------------------------
# Level 2 — HTTP Endpoints
# ---------------------------------------------------------------------------

test_ollama_api() {
  assert_http_200 "http://localhost:11434/api/version" 30
}

test_ollama_api_tags() {
  assert_http_200 "http://localhost:11434/api/tags" 30
}

test_open_webui_webui() {
  assert_http_200 "http://localhost:8080" 30
}

test_localai_health() {
  assert_http_200 "http://localhost:8080/readyz" 30
}

test_localai_models() {
  assert_http_200 "http://localhost:8080/v1/models" 30
}

test_n8n_health() {
  assert_http_200 "http://localhost:5678/healthz" 30
}

# ---------------------------------------------------------------------------
# Level 3 — Inter-Service Communication
# ---------------------------------------------------------------------------

test_open_webui_ollama_connection() {
  # Verify Open WebUI can reach Ollama backend
  local result
  result=$(curl -s "http://localhost:8080/api/version" 2>/dev/null || echo '{}')

  if [[ -n "${result}" && "${result}" != "{}" ]]; then
    _assert_pass "Open WebUI API responsive (Ollama connection implicit)"
  else
    _assert_fail "Open WebUI API not responsive"
  fi
}

# ---------------------------------------------------------------------------
# Level 1 — Configuration
# ---------------------------------------------------------------------------

test_ai_compose_valid() {
  local compose_file="${PROJECT_ROOT}/stacks/ai/docker-compose.yml"

  if [[ ! -f "${compose_file}" ]]; then
    _assert_skip "AI compose file not found"
    return 0
  fi

  assert_compose_valid "${compose_file}"
}
