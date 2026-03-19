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

# 基础断言
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

assert_not_empty() {
    local value="$1"
    local msg="${2:-}"
    if [[ -n "$value" ]]; then
        ((ASSERTIONS_PASSED++))
        return 0
    else
        ((ASSERTIONS_FAILED++))
        echo -e "${RED}❌ FAIL${NC} [assert_not_empty] Value is empty"
        [[ -n "$msg" ]] && echo -e "  Message: $msg"
        return 1
    fi
}

assert_exit_code() {
    local expected_code="$1"
    local msg="${2:-}"
    local actual_code=$?
    if [[ "$actual_code" -eq "$expected_code" ]]; then
        ((ASSERTIONS_PASSED++))
        return 0
    else
        ((ASSERTIONS_FAILED++))
        echo -e "${RED}❌ FAIL${NC} [assert_exit_code] Expected: $expected_code, Actual: $actual_code"
        [[ -n "$msg" ]] && echo -e "  Message: $msg"
        return 1
    fi
}

# Docker 相关断言
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

# HTTP 相关断言
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

assert_http_response() {
    local url="$1"
    local pattern="$2"
    local timeout="${3:-30}"
    local response=$(curl -s --max-time "$timeout" "$url" 2>/dev/null)
    if echo "$response" | grep -q "$pattern"; then
        ((ASSERTIONS_PASSED++))
        return 0
    else
        ((ASSERTIONS_FAILED++))
        echo -e "${RED}❌ FAIL${NC} $url does not contain pattern: $pattern"
        return 1
    fi
}

# JSON 相关断言
assert_json_value() {
    local json="$1"
    local jq_path="$2"
    local expected="$3"
    local actual=$(echo "$json" | jq -r "$jq_path" 2>/dev/null)
    if [[ "$actual" == "$expected" ]]; then
        ((ASSERTIONS_PASSED++))
        return 0
    else
        ((ASSERTIONS_FAILED++))
        echo -e "${RED}❌ FAIL${NC} [assert_json_value] Expected: $expected, Actual: $actual"
        return 1
    fi
}

assert_json_key_exists() {
    local json="$1"
    local jq_path="$2"
    local result=$(echo "$json" | jq "$jq_path" 2>/dev/null)
    if [[ "$result" != "null" && -n "$result" ]]; then
        ((ASSERTIONS_PASSED++))
        return 0
    else
        ((ASSERTIONS_FAILED++))
        echo -e "${RED}❌ FAIL${NC} [assert_json_key_exists] Key not found: $jq_path"
        return 1
    fi
}

assert_no_errors() {
    local json="$1"
    local errors=$(echo "$json" | jq '.errors' 2>/dev/null)
    if [[ "$errors" == "null" || "$errors" == "[]" || -z "$errors" ]]; then
        ((ASSERTIONS_PASSED++))
        return 0
    else
        ((ASSERTIONS_FAILED++))
        echo -e "${RED}❌ FAIL${NC} [assert_no_errors] JSON contains errors: $errors"
        return 1
    fi
}

# 文件相关断言
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

assert_file_contains() {
    local file="$1"
    local pattern="$2"
    if grep -q "$pattern" "$file" 2>/dev/null; then
        ((ASSERTIONS_PASSED++))
        return 0
    else
        ((ASSERTIONS_FAILED++))
        echo -e "${RED}❌ FAIL${NC} File $file does not contain: $pattern"
        return 1
    fi
}

# 镜像相关断言
assert_no_latest_images() {
    local dir="$1"
    local count=$(grep -r 'image:.*:latest' "$dir" 2>/dev/null | wc -l)
    if [[ "$count" -eq 0 ]]; then
        ((ASSERTIONS_PASSED++))
        return 0
    else
        ((ASSERTIONS_FAILED++))
        echo -e "${RED}❌ FAIL${NC} Found $count :latest image tags in $dir"
        return 1
    fi
}

# 摘要输出
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

# 导出所有函数
export -f assert_eq assert_not_empty assert_exit_code
export -f assert_container_running assert_container_healthy
export -f assert_http_200 assert_http_response
export -f assert_json_value assert_json_key_exists assert_no_errors
export -f assert_file_exists assert_file_contains
export -f assert_no_latest_images
export -f print_summary reset_counters
