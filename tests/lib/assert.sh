#!/bin/bash
# assert.sh - 断言库 for HomeLab Stack Integration Tests
set -u

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ASSERTIONS_PASSED=0
ASSERTIONS_FAILED=0
ASSERTIONS_SKIPPED=0

assert_eq() {
    local actual="$1"
    local expected="$2"
    local msg="${3:-}"
    if [[ "$actual" == "$expected" ]]; then
        ((ASSERTIONS_PASSED++))
        return 0
    else
        ((ASSERTIONS_FAILED++))
        echo -e "${RED}❌ FAIL${NC} [assert_eq] Expected: $expected, Actual: $actual"
        [[ -n "$msg" ]] && echo -e "  Message: $msg"
        return 1
    fi
}

assert_container_running() {
    local container="$1"
    local status=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null)
    if [[ "$status" == "running" ]]; then
        ((ASSERTIONS_PASSED++))
        return 0
    else
        ((ASSERTIONS_FAILED++))
        echo -e "${RED}❌ FAIL${NC} Container $container status: ${status:-not found}"
        return 1
    fi
}

assert_container_healthy() {
    local container="$1"
    local timeout="${2:-60}"
    local elapsed=0
    while [[ $elapsed -lt $timeout ]]; do
        local health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null)
        if [[ "$health" == "healthy" ]]; then
            ((ASSERTIONS_PASSED++))
            return 0
        elif [[ "$health" == "unhealthy" ]]; then
            ((ASSERTIONS_FAILED++))
            echo -e "${RED}❌ FAIL${NC} Container $container is unhealthy"
            return 1
        fi
        sleep 5
        ((elapsed+=5))
    done
    ((ASSERTIONS_FAILED++))
    echo -e "${RED}❌ FAIL${NC} Timeout waiting for $container"
    return 1
}

assert_http_200() {
    local url="$1"
    local timeout="${2:-30}"
    local http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$timeout" "$url" 2>/dev/null)
    if [[ "$http_code" == "200" ]]; then
        ((ASSERTIONS_PASSED++))
        return 0
    else
        ((ASSERTIONS_FAILED++))
        echo -e "${RED}❌ FAIL${NC} $url returned $http_code"
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    if [[ -f "$file" ]]; then
        ((ASSERTIONS_PASSED++))
        return 0
    else
        ((ASSERTIONS_FAILED++))
        echo -e "${RED}❌ FAIL${NC} File not found: $file"
        return 1
    fi
}

print_summary() {
    local passed=$1
    local failed=$2
    local skipped=$3
    local total=$((passed + failed + skipped))
    echo ""
    echo -e "${BLUE}──────────────────────────────────────${NC}"
    echo -e "Results: ${GREEN}✅ $passed passed${NC}, ${RED}❌ $failed failed${NC}, ${YELLOW}⏭️ $skipped skipped${NC}"
    echo -e "Total: $total"
    echo -e "${BLUE}──────────────────────────────────────${NC}"
    [[ $failed -gt 0 ]] && return 1
    return 0
}

reset_counters() {
    ASSERTIONS_PASSED=0
    ASSERTIONS_FAILED=0
    ASSERTIONS_SKIPPED=0
}

export -f assert_eq assert_container_running assert_container_healthy assert_http_200 assert_file_exists print_summary reset_counters
