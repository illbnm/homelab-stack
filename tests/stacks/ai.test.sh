#!/bin/bash
# ai.test.sh - AI Stack 集成测试
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$SCRIPT_DIR/../lib/assert.sh"

test_ollama_running() {
    echo "[ai] Testing Ollama running..."
    assert_container_running "ollama"
}

test_ollama_http() {
    echo "[ai] Testing Ollama API..."
    local response=$(curl -s --max-time 30 "http://localhost:11434/api/version" 2>/dev/null)
    if echo "$response" | grep -q "version"; then
        echo -e "${GREEN}✅ PASS${NC} Ollama API responding"
        return 0
    else
        echo -e "${RED}❌ FAIL${NC} Ollama API not responding"
        return 1
    fi
}

test_openwebui_running() {
    echo "[ai] Testing Open WebUI running..."
    assert_container_running "openwebui"
}

test_openwebui_http() {
    echo "[ai] Testing Open WebUI HTTP..."
    assert_http_200 "http://localhost:3000" 30
}

test_localai_running() {
    echo "[ai] Testing LocalAI running..."
    assert_container_running "localai" || return 0  # Optional
}

test_localai_http() {
    echo "[ai] Testing LocalAI HTTP..."
    assert_http_200 "http://localhost:8080/v1/models" 30 || return 0
}

test_compose_exists() {
    echo "[ai] Testing docker-compose.yml exists..."
    assert_file_exists "$ROOT_DIR/stacks/ai/docker-compose.yml"
}

run_ai_tests() {
    print_header "HomeLab Stack — AI Tests"
    
    test_compose_exists || true
    test_ollama_running || true
    test_ollama_http || true
    test_openwebui_running || true
    test_openwebui_http || true
    test_localai_running || true
    test_localai_http || true
    
    print_summary $ASSERTIONS_PASSED $ASSERTIONS_FAILED $ASSERTIONS_SKIPPED
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_ai_tests
fi
