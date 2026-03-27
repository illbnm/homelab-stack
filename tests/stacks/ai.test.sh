#!/bin/bash
# =============================================================================
# AI Stack Tests — HomeLab Stack
# =============================================================================
# Tests: Ollama, Open WebUI
# Level: 1 + 2 + 5
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$TESTS_DIR/.." && pwd)"

source "$TESTS_DIR/lib/assert.sh"
source "$TESTS_DIR/lib/docker.sh"

load_env() {
    [[ -f "$ROOT_DIR/.env" ]] && set -a && source "$ROOT_DIR/.env" && set +a
}
load_env

suite_start "AI Stack"

test_ollama_running()       { assert_container_running "ollama"; }
test_open_webui_running()   { assert_container_running "open-webui"; }
test_stable_diffusion_running() { assert_container_running "stable-diffusion" || true; }

test_ollama_http()          { assert_http_200 "http://ollama:11434/api/version" 20; }
test_open_webui_http()      { assert_http_200 "http://open-webui:8080/api/version" 20 || true; }

test_compose_syntax() {
    local failed=0
    for f in $(find "$ROOT_DIR/stacks/ai" -name 'docker-compose*.yml'); do
        docker compose -f "$f" config --quiet 2>/dev/null || { echo "Invalid: $f"; failed=1; }
    done
    [[ $failed -eq 0 ]]
}
test_no_latest_tags()       { assert_no_latest_images "stacks/ai"; }

tests=(test_ollama_running test_open_webui_running test_stable_diffusion_running
       test_ollama_http test_open_webui_http
       test_compose_syntax test_no_latest_tags)

for t in "${tests[@]}"; do $t; done
summary
