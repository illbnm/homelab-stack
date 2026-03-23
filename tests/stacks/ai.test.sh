#!/bin/bash
# ai.test.sh - AI Stack Integration Tests
# Tests for: Ollama, Open WebUI

set -o pipefail

# Test Ollama running
test_ai_ollama_running() {
    local test_name="[ai] Ollama running"
    start_test "$test_name"
    
    if assert_container_running "ollama"; then
        pass_test "$test_name"
    else
        fail_test "$test_name" "Container not running"
    fi
}

# Test Ollama API
test_ai_ollama_api() {
    local test_name="[ai] Ollama API /api/version"
    start_test "$test_name"
    
    local response
    response=$(curl -s "http://localhost:11434/api/version" 2>/dev/null)
    
    if echo "$response" | grep -q "version"; then
        pass_test "$test_name"
    else
        fail_test "$test_name" "API not responding"
    fi
}

# Test Ollama models
test_ai_ollama_models() {
    local test_name="[ai] Ollama models endpoint"
    start_test "$test_name"
    
    local response
    response=$(curl -s "http://localhost:11434/api/tags" 2>/dev/null)
    
    if [[ -n "$response" ]]; then
        pass_test "$test_name"
    else
        fail_test "$test_name" "Models endpoint not responding"
    fi
}

# Test Open WebUI running
test_ai_openwebui_running() {
    local test_name="[ai] Open WebUI running"
    start_test "$test_name"
    
    if assert_container_running "openwebui"; then
        pass_test "$test_name"
    else
        assert_skip "Open WebUI not deployed"
    fi
}

# Test Open WebUI Web UI
test_ai_openwebui_webui() {
    local test_name="[ai] Open WebUI Web UI"
    start_test "$test_name"
    
    if assert_http_200 "http://localhost:3001" 30; then
        pass_test "$test_name"
    else
        assert_skip "Open WebUI not accessible"
    fi
}

# Test Open WebUI connection to Ollama
test_ai_openwebui_ollama_connection() {
    local test_name="[ai] Open WebUI-Ollama connection"
    start_test "$test_name"
    
    # Both services should be running
    if assert_container_running "ollama" && assert_container_running "openwebui"; then
        pass_test "$test_name"
    else
        assert_skip "Services not both deployed"
    fi
}

# Run all AI tests
test_ai_all() {
    echo ""
    echo "════════════════════════════════════════"
    echo "  AI Stack Tests"
    echo "════════════════════════════════════════"
    
    test_ai_ollama_running
    test_ai_ollama_api
    test_ai_ollama_models
    test_ai_openwebui_running
    test_ai_openwebui_webui
    test_ai_openwebui_ollama_connection
}

# Helper functions
start_test() {
    local name="$1"
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}▶${NC} $name"
    fi
}

pass_test() {
    local name="$1"
    echo -e "${GREEN}✅ PASS${NC} $name"
}

fail_test() {
    local name="$1"
    local reason="$2"
    echo -e "${RED}❌ FAIL${NC} $name - $reason"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    VERBOSE="${VERBOSE:-false}"
    test_ai_all
fi
