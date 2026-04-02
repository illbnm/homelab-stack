#!/usr/bin/env bash
# 断言库 for HomeLab Stack tests
# TODO: add more assertions later

set -euo pipefail

# colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# 断言函数
# equality check
assert_eq() {
    local actual="$1"
    local expected="$2"
    local msg="${3:-Values should be equal}"

    if [[ "$actual" == "$expected" ]]; then
        echo -e "${GREEN}✅ PASS${NC}: $msg"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}❌ FAIL${NC}: $msg"
        echo "   Expected: $expected"
        echo "   Got: $actual"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_not_empty() {
    local value="$1"
    local msg="${2:-Value should not be empty}"

    if [[ -n "$value" ]]; then
        echo -e "${GREEN}✅ PASS${NC}: $msg"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}❌ FAIL${NC}: $msg"
        echo -e "   Value is empty"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_exit_code() {
    local code="$1"
    local msg="${2:-Command should exit with code 0}"

    if [[ "$code" -eq 0 ]]; then
        echo -e "${GREEN}✅ PASS${NC}: $msg"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}❌ FAIL${NC}: $msg"
        echo -e "   Exit code: $code"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_container_running() {
    local name="$1"
    local msg="${2:-Container $name should be running}"

    if docker ps --filter "name=$name" --filter "status=running" | grep -q "$name"; then
        echo -e "${GREEN}✅ PASS${NC}: $msg"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}❌ FAIL${NC}: $msg"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_container_healthy() {
    local name="$1"
    local timeout="${2:-60}"
    local msg="${3:-Container $name should be healthy}"

    echo -e "${YELLOW}⏳ WAIT${NC}: Waiting for $name to be healthy (timeout: ${timeout}s)..."

    local elapsed=0
    while [[ $elapsed -lt $timeout ]]; do
        if docker ps --filter "name=$name" --filter "health=healthy" | grep -q "$name"; then
            echo -e "${GREEN}✅ PASS${NC}: $msg (took ${elapsed}s)"
            ((TESTS_PASSED++))
            return 0
        fi
        sleep 2
        ((elapsed += 2))
    done

    echo -e "${RED}❌ FAIL${NC}: $msg (timed out after ${timeout}s)"
    ((TESTS_FAILED++))
    return 1
}

assert_http_200() {
    local url="$1"
    local timeout="${2:-30}"
    local msg="${3:-HTTP request to $url should return 200}"

    echo -e "${YELLOW}⏳ WAIT${NC}: Testing HTTP endpoint $url..."

    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$timeout" "$url" 2>/dev/null || echo "000")

    if [[ "$http_code" == "200" ]]; then
        echo -e "${GREEN}✅ PASS${NC}: $msg"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}❌ FAIL${NC}: $msg"
        echo -e "   Expected: 200"
        echo -e "   Got: $http_code"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_http_response() {
    local url="$1"
    local pattern="$2"
    local msg="${3:-HTTP response should match pattern}"

    local response
    response=$(curl -s --max-time 30 "$url" 2>/dev/null)

    if echo "$response" | grep -q "$pattern"; then
        echo -e "${GREEN}✅ PASS${NC}: $msg"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}❌ FAIL${NC}: $msg"
        echo -e "   Pattern not found: $pattern"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_json_value() {
    local json="$1"
    local jq_path="$2"
    local expected="$3"
    local msg="${4:-JSON value should match}"

    local actual
    actual=$(echo "$json" | jq -r "$jq_path" 2>/dev/null)

    if [[ "$actual" == "$expected" ]]; then
        echo -e "${GREEN}✅ PASS${NC}: $msg"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}❌ FAIL${NC}: $msg"
        echo -e "   Expected: $expected"
        echo -e "   Got: $actual"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_json_key_exists() {
    local json="$1"
    local jq_path="$2"
    local msg="${3:-JSON key should exist}"

    if echo "$json" | jq -e "$jq_path" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ PASS${NC}: $msg"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}❌ FAIL${NC}: $msg"
        echo -e "   Key not found: $jq_path"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_no_errors() {
    local json="$1"
    local msg="${2:-JSON should not contain errors}"

    local errors
    errors=$(echo "$json" | jq -r '.errors // empty' 2>/dev/null)

    if [[ -z "$errors" ]]; then
        echo -e "${GREEN}✅ PASS${NC}: $msg"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}❌ FAIL${NC}: $msg"
        echo -e "   Errors: $errors"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_file_contains() {
    local file="$1"
    local pattern="$2"
    local msg="${3:-File should contain pattern}"

    if grep -q "$pattern" "$file" 2>/dev/null; then
        echo -e "${GREEN}✅ PASS${NC}: $msg"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}❌ FAIL${NC}: $msg"
        echo -e "   Pattern not found in $file: $pattern"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_no_latest_images() {
    local dir="$1"
    local msg="${2:-No :latest image tags should be used}"

    local count
    count=$(grep -r 'image:.*:latest' "$dir" 2>/dev/null | wc -l)

    if [[ "$count" -eq 0 ]]; then
        echo -e "${GREEN}✅ PASS${NC}: $msg"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}❌ FAIL${NC}: $msg"
        echo -e "   Found $count :latest image tags"
        grep -r 'image:.*:latest' "$dir"
        ((TESTS_FAILED++))
        return 1
    fi
}

# 导出计数器
export TESTS_PASSED TESTS_FAILED TESTS_SKIPPED
