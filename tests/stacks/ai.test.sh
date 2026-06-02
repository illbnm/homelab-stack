#!/usr/bin/env bash
# =============================================================================
# AI Stack Tests
# =============================================================================

test_ollama_running() {
  assert_container_running "ollama"
}

test_ollama_api() {
  assert_http_200 "http://localhost:11434/api/tags" 10
}

test_open_webui_running() {
  assert_container_running "open-webui"
}

test_open_webui_http() {
  assert_http_200 "http://localhost:8080/health" 10
}

run_test_with_timing "ai" test_ollama_running "Ollama running"
run_test_with_timing "ai" test_ollama_api "Ollama API HTTP 200"
run_test_with_timing "ai" test_open_webui_running "Open WebUI running"
run_test_with_timing "ai" test_open_webui_http "Open WebUI /health 200"
