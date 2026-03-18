#!/usr/bin/env bash
# =============================================================================
# ai.test.sh — AI stack tests
# Services: Ollama, Open WebUI, Stable Diffusion
# =============================================================================

# --- Ollama ---

test_ollama_running() {
  assert_container_running "ollama"
}

test_ollama_healthy() {
  assert_container_healthy "ollama"
}

test_ollama_api() {
  assert_http_200 "http://localhost:11434/api/version" 15
}

test_ollama_api_json() {
  assert_http_body_contains "http://localhost:11434/api/version" '"version"' 10
}

test_ollama_no_crash_loop() {
  assert_no_crash_loop "ollama" 3
}

test_ollama_in_proxy_network() {
  assert_container_in_network "ollama" "proxy"
}

# --- Open WebUI ---

test_openwebui_running() {
  assert_container_running "open-webui"
}

test_openwebui_healthy() {
  assert_container_healthy "open-webui"
}

test_openwebui_ui() {
  assert_http_200 "http://localhost:8080" 15
}

test_openwebui_no_crash_loop() {
  assert_no_crash_loop "open-webui" 3
}

test_openwebui_in_proxy_network() {
  assert_container_in_network "open-webui" "proxy"
}

# --- Stable Diffusion (optional — may not be deployed without GPU) ---

test_stablediffusion_running() {
  # Stable Diffusion is optional (requires GPU)
  local state
  state=$(docker inspect --format='{{.State.Status}}' "stable-diffusion" 2>/dev/null) || {
    _assert_skip "Stable Diffusion running" "Not deployed (requires GPU)"
    return 0
  }
  assert_container_running "stable-diffusion"
}

test_stablediffusion_healthy() {
  local state
  state=$(docker inspect --format='{{.State.Status}}' "stable-diffusion" 2>/dev/null) || {
    _assert_skip "Stable Diffusion healthy" "Not deployed"
    return 0
  }
  assert_container_healthy "stable-diffusion"
}

test_stablediffusion_api() {
  local state
  state=$(docker inspect --format='{{.State.Status}}' "stable-diffusion" 2>/dev/null) || {
    _assert_skip "Stable Diffusion API" "Not deployed"
    return 0
  }
  assert_http_200 "http://localhost:7860" 15
}
