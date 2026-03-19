#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.."; pwd)"
source "$SCRIPT_DIR/tests/lib/assert.sh"
source "$SCRIPT_DIR/tests/lib/docker.sh"

test_ollama_running() {
  assert_container_running "ollama"
}
test_ollama_api() {
  assert_http_200 "http://localhost:11434/api/version" 10
}
test_open_webui_running() {
  assert_container_running "open-webui"
}
test_open_webui_http() {
  assert_http_200 "http://localhost:3080" 10
}
test_ai_compose_valid() {
  assert_compose_valid "$SCRIPT_DIR/stacks/ai/docker-compose.yml"
}
