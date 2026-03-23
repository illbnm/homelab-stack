#!/bin/bash
# productivity.test.sh - Productivity Stack Integration Tests
# Tests for: Gitea, Ollama

set -o pipefail

# Test Gitea running
test_productivity_gitea_running() {
    local test_name="[productivity] Gitea running"
    start_test "$test_name"
    
    if assert_container_running "gitea"; then
        pass_test "$test_name"
    else
        fail_test "$test_name" "Container not running"
    fi
}

# Test Gitea Web UI
test_productivity_gitea_webui() {
    local test_name="[productivity] Gitea Web UI"
    start_test "$test_name"
    
    if assert_http_200 "http://localhost:3000" 30; then
        pass_test "$test_name"
    else
        fail_test "$test_name" "Web UI not accessible"
    fi
}

# Test Gitea API
test_productivity_gitea_api() {
    local test_name="[productivity] Gitea API /api/v1/version"
    start_test "$test_name"
    
    local response
    response=$(curl -s "http://localhost:3000/api/v1/version" 2>/dev/null)
    
    if echo "$response" | grep -q "version"; then
        pass_test "$test_name"
    else
        fail_test "$test_name" "API not responding"
    fi
}

# Test Ollama running
test_productivity_ollama_running() {
    local test_name="[productivity] Ollama running"
    start_test "$test_name"
    
    if assert_container_running "ollama"; then
        pass_test "$test_name"
    else
        fail_test "$test_name" "Container not running"
    fi
}

# Test Ollama API
test_productivity_ollama_api() {
    local test_name="[productivity] Ollama API /api/version"
    start_test "$test_name"
    
    local response
    response=$(curl -s "http://localhost:11434/api/version" 2>/dev/null)
    
    if echo "$response" | grep -q "version"; then
        pass_test "$test_name"
    else
        fail_test "$test_name" "API not responding"
    fi
}

# Test Ollama model list
test_productivity_ollama_models() {
    local test_name="[productivity] Ollama models endpoint"
    start_test "$test_name"
    
    local response
    response=$(curl -s "http://localhost:11434/api/tags" 2>/dev/null)
    
    if [[ -n "$response" ]]; then
        pass_test "$test_name"
    else
        fail_test "$test_name" "Models endpoint not responding"
    fi
}

# Run all productivity tests
test_productivity_all() {
    echo ""
    echo "════════════════════════════════════════"
    echo "  Productivity Stack Tests"
    echo "════════════════════════════════════════"
    
    test_productivity_gitea_running
    test_productivity_gitea_webui
    test_productivity_gitea_api
    test_productivity_ollama_running
    test_productivity_ollama_api
    test_productivity_ollama_models
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
    test_productivity_all
fi
