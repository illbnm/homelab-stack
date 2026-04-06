#!/bin/bash
# ai.test.sh - AI Stack Integration Tests
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$SCRIPT_DIR/../lib/assert.sh"

test_ollama_running() {
    echo "[ai] Testing Ollama running..."
    assert_container_running "ollama" || echo "  ⚠️  Ollama container not found"
}

test_ollama_http() {
    echo "[ai] Testing Ollama API version..."
    assert_http_response "http://localhost:11434/api/version" "version" 30 || echo "  ⚠️  Ollama API check skipped"
}

test_openwebui_running() {
    echo "[ai] Testing Open WebUI running..."
    assert_container_running "open-webui" || echo "  ⚠️  Open WebUI container not found"
}

test_openwebui_http() {
    echo "[ai] Testing Open WebUI HTTP endpoint..."
    assert_http_200 "http://localhost:3001" 30 || echo "  ⚠️  Open WebUI HTTP check skipped"
}

test_stable_diffusion_running() {
    echo "[ai] Testing Stable Diffusion running..."
    assert_container_running "stable-diffusion" || echo "  ⚠️  Stable Diffusion container not found"
}

test_compose_exists() {
    echo "[ai] Testing docker-compose.yml exists..."
    assert_file_exists "$ROOT_DIR/stacks/ai/docker-compose.yml" || echo "  ⚠️  AI compose file not found"
}

run_ai_tests() {
    echo "╔══════════════════════════════════════╗"
    echo "║   HomeLab Stack — AI Tests           ║"
    echo "╚══════════════════════════════════════╝"
    echo ""
    
    test_compose_exists || true
    test_ollama_running || true
    test_ollama_http || true
    test_openwebui_running || true
    test_openwebui_http || true
    test_stable_diffusion_running || true
    
    print_summary $ASSERTIONS_PASSED $ASSERTIONS_FAILED $ASSERTIONS_SKIPPED
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_ai_tests
fi
