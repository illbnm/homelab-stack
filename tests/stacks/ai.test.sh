#!/usr/bin/env bash
# =============================================================================
# Local Inference Stack Tests — Ollama + Open WebUI
# =============================================================================

# --- Level 1: Container Health ---

test_ai_ollama_running() {
  assert_container_running "homelab-ollama"
}

test_ai_openwebui_running() {
  assert_container_running "homelab-openwebui"
}

test_ai_openwebui_healthy() {
  assert_container_healthy "homelab-openwebui" 90
}

# --- Level 1: Configuration ---

test_ai_compose_syntax() {
  local output
  output=$(compose_config_valid "stacks/ai/docker-compose.yml" 2>&1)
  _LAST_EXIT_CODE=$?
  assert_exit_code 0 "ai compose syntax invalid: ${output}"
}

test_ai_no_latest_tags() {
  assert_no_latest_images "stacks/ai/"
}

# --- Level 2: HTTP Endpoints ---

test_ai_ollama_api_version() {
  local ip
  ip=$(get_container_ip homelab-ollama)
  assert_http_response "http://${ip}:11434/api/version" '"version"' 30
}
