#!/bin/bash
# Assertion library for homelab-stack integration tests
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

ASSERT_COUNT=0
PASS_COUNT=0
FAIL_COUNT=0

assert_ok() {
    ASSERT_COUNT=$((ASSERT_COUNT + 1))
    if [ $? -eq 0 ]; then
        PASS_COUNT=$((PASS_COUNT + 1))
        echo -e "  [${GREEN}PASS${NC}] $1"
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        echo -e "  [${RED}FAIL${NC}] $1"
    fi
}

assert_eq() {
    local expected=$1 actual=$2 msg=$3
    if [ "$expected" = "$actual" ]; then
        echo -e "  [${GREEN}PASS${NC}] $msg (expected: $expected)"
    else
        echo -e "  [${RED}FAIL${NC}] $msg (expected: $expected, got: $actual)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

assert_http() {
    local url=$1 expected_code=$2 msg=$3
    local code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$url" 2>/dev/null || echo "000")
    if [ "$code" = "$expected_code" ]; then
        echo -e "  [${GREEN}PASS${NC}] $msg ($url => $code)"
    else
        echo -e "  [${RED}FAIL${NC}] $msg ($url => expected $expected_code, got $code)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

assert_container_running() {
    local name=$1
    if docker ps --filter "name=$name" --format "{{.Status}}" 2>/dev/null | grep -q "Up"; then
        echo -e "  [${GREEN}PASS${NC}] Container $name is running"
    else
        echo -e "  [${RED}FAIL${NC}] Container $name is NOT running"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

assert_file_exists() {
    local path=$1 msg=$2
    if [ -f "$path" ]; then
        echo -e "  [${GREEN}PASS${NC}] $msg ($path exists)"
    else
        echo -e "  [${RED}FAIL${NC}] $msg ($path missing)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

print_summary() {
    echo ""
    echo "================================="
    echo -e "Tests: $((PASS_COUNT + FAIL_COUNT)) | ${GREEN}Passed: $PASS_COUNT${NC} | ${RED}Failed: $FAIL_COUNT${NC}"
    if [ $FAIL_COUNT -eq 0 ]; then
        echo -e "${GREEN}ALL TESTS PASSED${NC}"
        exit 0
    else
        echo -e "${RED}Some tests FAILED${NC}"
        exit 1
    fi
}
