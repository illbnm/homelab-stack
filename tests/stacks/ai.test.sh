#!/usr/bin/env bash
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib"; pwd)"
source "$_LIB_DIR/assert.sh"

test_ai_ollama_running() { assert_container_running "ollama" "Ollama should be running"; }
test_ai_ollama_health() { assert_http_200 "http://localhost:11434/api/version" 15 "Ollama API should respond"; }
test_ai_webui_running() { assert_container_running "open-webui" "Open WebUI should be running"; }
test_ai_no_latest_tags() { assert_no_latest_images "$BASE_DIR/stacks/ai" "AI stack should pin image versions"; }
