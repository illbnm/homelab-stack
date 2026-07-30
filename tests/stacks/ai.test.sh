#!/usr/bin/env bash
# AI Stack Tests — Ollama + Open WebUI + Stable Diffusion + Perplexica
test_ollama_running() { assert_eq "$(container_status ollama)" "running" "Ollama should be running"; }
test_ollama_api() { assert_http_200 "http://localhost:11434/api/version" "Ollama API version endpoint"; }
test_open_webui_running() { assert_eq "$(container_status open-webui)" "running" "Open WebUI should be running"; }
test_open_webui_health() { assert_http_status "http://localhost:3000/health" "200" "Open WebUI health endpoint"; }
test_ollama_models() {
  local result; result=$(curl -s "http://localhost:11434/api/tags" 2>/dev/null || echo "{}")
  assert_json_key_exists "$result" ".models" "Ollama should list models"
}
test_open_webui_ollama_connection() {
  local result; result=$(curl -s "http://localhost:3000/api/config" 2>/dev/null || echo "")
  assert_not_empty "$result" "Open WebUI config should be non-empty"
}