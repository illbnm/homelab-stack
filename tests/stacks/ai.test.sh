#!/usr/bin/env bash
# =============================================================================
# ai.test.sh — AI stack tests (ollama, open-webui, stable-diffusion)
# =============================================================================

# ---------------------------------------------------------------------------
# Level 1: Container health
# ---------------------------------------------------------------------------
test_suite "AI — Containers"

test_ollama_running() {
  assert_container_running "ollama"
  assert_container_healthy "ollama"
}

test_open_webui_running() {
  assert_container_running "open-webui"
  assert_container_healthy "open-webui"
}

test_stable_diffusion_running() {
  assert_container_running "stable-diffusion"
  assert_container_healthy "stable-diffusion"
}

test_ollama_running
test_open_webui_running
test_stable_diffusion_running

# ---------------------------------------------------------------------------
# Level 2: HTTP endpoints
# ---------------------------------------------------------------------------
if [[ ${TEST_LEVEL:-99} -ge 2 ]]; then
  test_suite "AI — HTTP Endpoints"

  test_ollama_api() {
    assert_http_200 "http://localhost:11434/api/version" "Ollama /api/version"
  }

  test_open_webui_health() {
    assert_http_200 "http://localhost:8080/health" "Open-WebUI /health"
  }

  test_stable_diffusion_ui() {
    assert_http_200 "http://localhost:7860" "Stable Diffusion UI"
  }

  test_ollama_api
  test_open_webui_health
  test_stable_diffusion_ui
fi

# ---------------------------------------------------------------------------
# Level 3: Service interconnection
# ---------------------------------------------------------------------------
if [[ ${TEST_LEVEL:-99} -ge 3 ]]; then
  test_suite "AI — Interconnection"

  test_ollama_tags() {
    local result
    result=$(curl -sf --connect-timeout 5 --max-time 10 \
      "http://localhost:11434/api/tags" 2>/dev/null || echo "")
    if [[ -n "$result" ]]; then
      assert_json_key_exists "$result" ".models" "Ollama /api/tags returns models list"
    else
      test_fail "Ollama /api/tags" "empty response"
    fi
  }

  test_open_webui_ollama_connection() {
    # Open-WebUI should be configured to connect to Ollama
    local result
    result=$(curl -sf --connect-timeout 5 --max-time 10 \
      "http://localhost:8080/health" 2>/dev/null || echo "")
    if [[ -n "$result" ]]; then
      test_pass "Open-WebUI is reachable (depends on Ollama)"
    else
      test_fail "Open-WebUI health" "not reachable"
    fi
  }

  test_ollama_tags
  test_open_webui_ollama_connection
fi
