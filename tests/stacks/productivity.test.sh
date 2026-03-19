#!/bin/bash
# productivity.test.sh - Productivity Stack 集成测试
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$SCRIPT_DIR/../lib/assert.sh"

test_gitea_running() {
    echo "[productivity] Testing Gitea running..."
    assert_container_running "gitea"
}

test_gitea_http() {
    echo "[productivity] Testing Gitea API..."
    assert_http_200 "http://localhost:3001/api/v1/version" 30
}

test_n8n_running() {
    echo "[productivity] Testing n8n running..."
    assert_container_running "n8n"
}

test_n8n_http() {
    echo "[productivity] Testing n8n HTTP..."
    local http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 30 "http://localhost:5678/healthz" 2>/dev/null)
    if [[ "$http_code" == "200" ]]; then
        echo -e "${GREEN}✅ PASS${NC}"
        return 0
    else
        echo -e "${RED}❌ FAIL${NC} n8n returned $http_code"
        return 1
    fi
}

test_paperless_running() {
    echo "[productivity] Testing Paperless running..."
    assert_container_running "paperless" || return 0  # Optional
}

test_paperless_http() {
    echo "[productivity] Testing Paperless HTTP..."
    assert_http_200 "http://localhost:8083" 30 || return 0
}

test_compose_exists() {
    echo "[productivity] Testing docker-compose.yml exists..."
    assert_file_exists "$ROOT_DIR/stacks/productivity/docker-compose.yml"
}

run_productivity_tests() {
    print_header "HomeLab Stack — Productivity Tests"
    
    test_compose_exists || true
    test_gitea_running || true
    test_gitea_http || true
    test_n8n_running || true
    test_n8n_http || true
    test_paperless_running || true
    test_paperless_http || true
    
    print_summary $ASSERTIONS_PASSED $ASSERTIONS_FAILED $ASSERTIONS_SKIPPED
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_productivity_tests
fi
