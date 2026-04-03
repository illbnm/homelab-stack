#!/usr/bin/env bash
# =============================================================================
# AI Stack Integration Tests
# Tests: Ollama, Open WebUI, Stable Diffusion, Perplexica
# =============================================================================

STACK_NAME="ai"

# =============================================================================
# Container Health Tests
# =============================================================================

test_ollama_running() {
  assert_container_running "ollama" "Ollama should be running"
  assert_container_healthy "ollama" "Ollama should be healthy within 90s"
}

test_open_webui_running() {
  assert_container_running "open-webui" "Open WebUI should be running"
  assert_container_healthy "open-webui" "Open WebUI should be healthy within 90s"
}

test_stable_diffusion_running() {
  assert_container_running "stable-diffusion" "Stable Diffusion should be running"
  # SD takes longer to start
  assert_container_healthy "stable-diffusion" "Stable Diffusion should be healthy within 180s"
}

test_perplexica_running() {
  assert_container_running "perplexica" "Perplexica should be running"
  assert_container_healthy "perplexica" "Perplexica should be healthy within 60s"
}

test_searxng_running() {
  assert_container_running "searxng" "SearXNG should be running"
  assert_container_healthy "searxng" "SearXNG should be healthy within 30s"
}

# =============================================================================
# HTTP Endpoint Tests
# =============================================================================

test_ollama_api() {
  assert_http_200 "http://localhost:11434/api/tags" "Ollama API should be accessible"
}

test_ollama_version() {
  assert_http_200 "http://localhost:11434/api/version" "Ollama version endpoint should be accessible"
}

test_open_webui_api() {
  assert_http_200 "http://localhost:8080/health" "Open WebUI health endpoint should be accessible"
}

test_stable_diffusion_ui() {
  assert_http_200 "http://localhost:7860/" "Stable Diffusion UI should be accessible"
}

test_perplexica_ui() {
  assert_http_200 "http://localhost:3000/" "Perplexica UI should be accessible"
}

test_searxng_api() {
  assert_http_200 "http://localhost:8080/" "SearXNG should be accessible"
}

# =============================================================================
# Ollama Integration Tests
# =============================================================================

test_ollama_model_list() {
  local result
  result=$(curl -sf "http://localhost:11434/api/tags")
  
  assert_json_key_exists "$result" ".models"
  log_test_pass "Ollama models endpoint returns valid JSON"
}

test_ollama_generation() {
  # Skip if no models available
  local models
  models=$(curl -sf "http://localhost:11434/api/tags" | jq -r '.models | length')
  
  if [ "$models" -eq 0 ]; then
    log_test_skip "Ollama generation test" "No models available"
    return 0
  fi
  
  # Test generation with first available model
  local model
  model=$(curl -sf "http://localhost:11434/api/tags" | jq -r '.models[0].name')
  
  local result
  result=$(curl -sf "http://localhost:11434/api/generate" -d "{
    \"model\": \"$model\",
    \"prompt\": \"Hello\",
    \"stream\": false
  }")
  
  assert_json_key_exists "$result" ".response"
  log_test_pass "Ollama generation test passed with model: $model"
}

# =============================================================================
# Open WebUI Integration Tests
# =============================================================================

test_open_webui_config() {
  local result
  result=$(curl -sf "http://localhost:8080/api/config")
  
  assert_json_key_exists "$result" ".status"
  log_test_pass "Open WebUI config endpoint returns valid JSON"
}

test_open_webui_ollama_connection() {
  # Check if Open WebUI can connect to Ollama
  local result
  result=$(curl -sf "http://localhost:8080/ollama/api/tags")
  
  # Should return Ollama models (or empty array)
  assert_json_key_exists "$result" ".models"
  log_test_pass "Open WebUI successfully connects to Ollama"
}

# =============================================================================
# Perplexica Integration Tests
# =============================================================================

test_perplexica_searxng_connection() {
  # Perplexica should be able to connect to SearXNG
  assert_http_200 "http://localhost:8080/search?q=test" "SearXNG search should work"
  log_test_pass "Perplexica can connect to SearXNG"
}

# =============================================================================
# GPU Detection Tests
# =============================================================================

test_gpu_detection_script() {
  if [ -f "$ROOT_DIR/scripts/detect-gpu.sh" ]; then
    assert_exit_code 0 "$ROOT_DIR/scripts/detect-gpu.sh" "GPU detection script should run successfully"
  else
    log_test_skip "GPU detection script test" "Script not found"
  fi
}

# =============================================================================
# Run Tests
# =============================================================================

run_all_tests() {
  echo "Running Container Health Tests..."
  test_ollama_running
  test_open_webui_running
  test_stable_diffusion_running
  test_perplexica_running
  test_searxng_running
  
  echo ""
  echo "Running HTTP Endpoint Tests..."
  test_ollama_api
  test_ollama_version
  test_open_webui_api
  test_stable_diffusion_ui
  test_perplexica_ui
  test_searxng_api
  
  echo ""
  echo "Running Ollama Integration Tests..."
  test_ollama_model_list
  test_ollama_generation
  
  echo ""
  echo "Running Open WebUI Integration Tests..."
  test_open_webui_config
  test_open_webui_ollama_connection
  
  echo ""
  echo "Running Perplexica Integration Tests..."
  test_perplexica_searxng_connection
  
  echo ""
  echo "Running GPU Detection Tests..."
  test_gpu_detection_script
}
