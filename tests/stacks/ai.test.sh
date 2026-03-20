#!/usr/bin/env bash
# =============================================================================
# AI Stack Tests — Ollama, Open WebUI, Stable Diffusion
# =============================================================================

log_group "AI Stack"

# --- Level 1: Container health ---

AI_CONTAINERS=(ollama open-webui stable-diffusion)

for c in "${AI_CONTAINERS[@]}"; do
  if is_container_running "$c"; then
    assert_container_running "$c"
    assert_container_healthy "$c"
    assert_container_not_restarting "$c"
  else
    skip_test "Container '$c'" "not running"
  fi
done

# --- Level 2: HTTP endpoints ---
if [[ "${TEST_LEVEL:-99}" -ge 2 ]]; then

  test_ollama_http() {
    require_container "ollama" || return
    assert_http_200 "http://localhost:11434/api/version" "Ollama /api/version"
    assert_http_200 "http://localhost:11434/api/tags" "Ollama /api/tags"
  }

  test_open_webui_http() {
    require_container "open-webui" || return
    assert_http_200 "http://localhost:8080/health" "Open WebUI /health"
  }

  test_stable_diffusion_http() {
    require_container "stable-diffusion" || return
    assert_http_ok "http://localhost:7860" "Stable Diffusion Web UI"
  }

  test_ollama_http
  test_open_webui_http
  test_stable_diffusion_http
fi

# --- Level 3: Service interconnection ---
if [[ "${TEST_LEVEL:-99}" -ge 3 ]]; then

  # Open WebUI must be able to reach Ollama
  test_openwebui_ollama_connection() {
    require_container "open-webui" || return
    require_container "ollama" || return
    # Open WebUI connects to Ollama via OLLAMA_BASE_URL=http://ollama:11434
    # Verify by checking Open WebUI can list Ollama models
    local result
    result=$(curl -sf "http://localhost:8080/api/models" 2>/dev/null || echo "")
    if [[ -n "$result" ]]; then
      _record_result pass "Open WebUI can reach Ollama API"
    else
      # Even if models endpoint needs auth, connectivity test via Ollama directly
      local ollama_result
      ollama_result=$(docker_exec "open-webui" \
        curl -sf "http://ollama:11434/api/tags" 2>/dev/null || echo "")
      if [[ -n "$ollama_result" ]]; then
        _record_result pass "Open WebUI → Ollama network connectivity"
      else
        _record_result fail "Open WebUI → Ollama network connectivity" "cannot reach ollama:11434"
      fi
    fi
  }

  test_openwebui_ollama_connection
fi

# --- Image tags ---
for c in "${AI_CONTAINERS[@]}"; do
  if is_container_running "$c"; then
    assert_container_image_not_latest "$c"
  fi
done
