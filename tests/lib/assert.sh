#!/bin/bash
# =============================================================================
# Bash Assertion Library — HomeLab Stack Integration Tests
# =============================================================================
# Description: 12 core assertion functions for Docker and HTTP testing
# Usage: source this library in test scripts
# Requirements: curl, jq, docker
# =============================================================================

# -----------------------------------------------------------------------------
# Color codes
# -----------------------------------------------------------------------------
export COLOR_RED='\033[0;31m'
export COLOR_GREEN='\033[0;32m'
export COLOR_YELLOW='\033[0;33m'
export COLOR_BLUE='\033[0;34m'
export COLOR_RESET='\033[0m'
export COLOR_BOLD='\033[1m'

# Track test results
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0
CURRENT_SUITE=""

# -----------------------------------------------------------------------------
# Suite management
# -----------------------------------------------------------------------------
suite_start() {
    CURRENT_SUITE="${1:-unknown}"
    echo ""
    echo -e "${COLOR_BOLD}${COLOR_BLUE}═══════════════════════════════════════════${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_BLUE}  $CURRENT_SUITE${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_BLUE}═══════════════════════════════════════════${COLOR_RESET}"
}

# -----------------------------------------------------------------------------
# assert_eq — 相等比较
# Usage: assert_eq <actual> <expected> [message]
# -----------------------------------------------------------------------------
assert_eq() {
    local actual="$1"
    local expected="$2"
    local msg="${3:-Expected '$expected', got '$actual'}"
    if [[ "$actual" == "$expected" ]]; then
        _pass "$msg"
        return 0
    else
        _fail "$msg"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# assert_not_eq — 不等比较
# Usage: assert_not_eq <actual> <expected> [message]
# -----------------------------------------------------------------------------
assert_not_eq() {
    local actual="$1"
    local expected="$2"
    local msg="${3:-Expected not '$expected', but got it}"
    if [[ "$actual" != "$expected" ]]; then
        _pass "$msg"
        return 0
    else
        _fail "$msg"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# assert_contains — 字符串包含检查
# Usage: assert_contains <string> <substring> [message]
# -----------------------------------------------------------------------------
assert_contains() {
    local str="$1"
    local substr="$2"
    local msg="${3:-Expected string to contain '$substr'}"
    if [[ "$str" == *"$substr"* ]]; then
        _pass "$msg"
        return 0
    else
        _fail "$msg"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# assert_not_empty — 非空检查
# Usage: assert_not_empty <value> [message]
# -----------------------------------------------------------------------------
assert_not_empty() {
    local value="$1"
    local msg="${2:-Expected non-empty value, got empty}"
    if [[ -n "$value" ]]; then
        _pass "$msg"
        return 0
    else
        _fail "$msg"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# assert_exit_code — 退出码检查
# Usage: assert_exit_code <expected_code> <command>...
# -----------------------------------------------------------------------------
assert_exit_code() {
    local expected_code="$1"
    shift
    local cmd="$*"
    local actual_code
    set +e
    eval "$cmd" > /dev/null 2>&1
    actual_code=$?
    set -e
    local msg="Command '$cmd' should exit with $expected_code, got $actual_code"
    if [[ "$actual_code" -eq "$expected_code" ]]; then
        _pass "$msg"
        return 0
    else
        _fail "$msg"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# assert_container_running — 容器运行检查
# Usage: assert_container_running <container_name>
# -----------------------------------------------------------------------------
assert_container_running() {
    local name="$1"
    local status
    status=$(docker inspect -f '{{.State.Status}}' "$name" 2>/dev/null || echo "not_found")
    local msg="Container '$name' should be running"
    if [[ "$status" == "running" ]]; then
        _pass "$msg"
        return 0
    else
        _fail "${msg}; actual status was '${status}'"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# assert_container_healthy — 容器健康检查（等待最多60s）
# Usage: assert_container_healthy <container_name>
# -----------------------------------------------------------------------------
assert_container_healthy() {
    local name="$1"
    local timeout="${2:-60}"
    local elapsed=0
    local interval=2

    while [[ $elapsed -lt $timeout ]]; do
        local health
        health=$(docker inspect -f '{{.State.Health.Status}}' "$name" 2>/dev/null || echo "none")
        case "$health" in
            healthy)
                _pass "Container '$name' is healthy"
                return 0
                ;;
            unhealthy)
                _fail "Container '$name' is unhealthy"
                return 1
                ;;
            none|"")
                # No healthcheck defined — fall back to running state
                local status
                status=$(docker inspect -f '{{.State.Status}}' "$name" 2>/dev/null || echo "not_found")
                if [[ "$status" == "running" ]]; then
                    _pass "Container '$name' is running without healthcheck"
                    return 0
                fi
                ;;
        esac
        sleep $interval
        elapsed=$((elapsed + interval))
    done

    _fail "Container '$name' did not become healthy within ${timeout}s"
    return 1
}

# -----------------------------------------------------------------------------
# assert_http_200 — HTTP 200检查
# Usage: assert_http_200 <url> [timeout=30]
# -----------------------------------------------------------------------------
assert_http_200() {
    local url="$1"
    local timeout="${2:-30}"
    local http_code
    http_code=$(curl -sf -o /dev/null -w "%{http_code}" --max-time "$timeout" "$url" 2>/dev/null || echo "000")
    local msg="HTTP GET $url should return 200, got $http_code"
    if [[ "$http_code" == "200" ]]; then
        _pass "$msg"
        return 0
    else
        _fail "$msg"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# assert_http_response — HTTP响应匹配模式
# Usage: assert_http_response <url> <pattern> [timeout=30]
# -----------------------------------------------------------------------------
assert_http_response() {
    local url="$1"
    local pattern="$2"
    local timeout="${3:-30}"
    local response
    response=$(curl -sf --max-time "$timeout" "$url" 2>/dev/null || echo "")
    local msg="HTTP GET $url should contain '$pattern'"
    if echo "$response" | grep -q "$pattern"; then
        _pass "$msg"
        return 0
    else
        _fail "$msg"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# assert_json_value — JSON字段值验证
# Usage: assert_json_value <json> <jq_path> <expected>
# -----------------------------------------------------------------------------
assert_json_value() {
    local json="$1"
    local jq_path="$2"
    local expected="$3"
    local actual
    actual=$(echo "$json" | jq -r "$jq_path" 2>/dev/null || echo "null")
    local msg="JSON value at '$jq_path' should be '$expected', got '$actual'"
    if [[ "$actual" == "$expected" ]]; then
        _pass "$msg"
        return 0
    else
        _fail "$msg"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# assert_json_key_exists — JSON字段存在性
# Usage: assert_json_key_exists <json> <jq_path>
# -----------------------------------------------------------------------------
assert_json_key_exists() {
    local json="$1"
    local jq_path="$2"
    local value
    value=$(echo "$json" | jq -r "$jq_path" 2>/dev/null || echo "null")
    local msg="JSON key '$jq_path' should exist, got '$value'"
    if [[ "$value" != "null" ]]; then
        _pass "$msg"
        return 0
    else
        _fail "$msg"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# assert_no_errors — JSON错误检查（.errors 为空）
# Usage: assert_no_errors <json>
# -----------------------------------------------------------------------------
assert_no_errors() {
    local json="$1"
    local errors
    errors=$(echo "$json" | jq -r '.errors // [] | if type == "array" then length else 0 end' 2>/dev/null || echo "1")
    local msg="JSON should have no errors, but found $errors"
    if [[ "$errors" == "0" ]]; then
        _pass "$msg"
        return 0
    else
        _fail "$msg"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# assert_file_contains — 文件内容检查
# Usage: assert_file_contains <file> <pattern>
# -----------------------------------------------------------------------------
assert_file_contains() {
    local file="$1"
    local pattern="$2"
    local msg="File '$file' should contain '$pattern'"
    if [[ -f "$file" ]] && grep -q "$pattern" "$file"; then
        _pass "$msg"
        return 0
    else
        _fail "$msg"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# assert_no_latest_images — Compose文件中无:latest标签
# Usage: assert_no_latest_images <dir>
# -----------------------------------------------------------------------------
assert_no_latest_images() {
    local dir="${1:-stacks}"
    local count
    count=$(find "$dir" -name 'docker-compose*.yml' -exec grep -l 'image:.*:latest' {} \; 2>/dev/null | wc -l | tr -d ' ')
    local msg="No ':latest' image tags should exist in $dir"
    if [[ "$count" == "0" ]]; then
        _pass "$msg"
        return 0
    else
        _fail "${msg} - found in ${count} file"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Internal helpers
# -----------------------------------------------------------------------------
_pass() {
    local msg="$1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "  ${COLOR_GREEN}✅ PASS${COLOR_RESET} $msg"
}

_fail() {
    local msg="$1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "  ${COLOR_RED}❌ FAIL${COLOR_RESET} $msg"
}

skip() {
    local msg="$1"
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
    echo -e "  ${COLOR_YELLOW}⏭️  SKIP${COLOR_RESET} $msg"
}

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
summary() {
    local duration="${1:-0}"
    echo ""
    echo -e "${COLOR_BOLD}─────────────────────────────────────────────${COLOR_RESET}"
    echo -e "${COLOR_BOLD}Results: ${COLOR_GREEN}$TESTS_PASSED passed${COLOR_RESET}, ${COLOR_RED}$TESTS_FAILED failed${COLOR_RESET}, ${COLOR_YELLOW}$TESTS_SKIPPED skipped${COLOR_RESET}"
    echo -e "${COLOR_BOLD}Duration: ${duration}s${COLOR_RESET}"
    echo -e "${COLOR_BOLD}─────────────────────────────────────────────${COLOR_RESET}"
    return $TESTS_FAILED
}

get_summary() {
    echo "$TESTS_PASSED|$TESTS_FAILED|$TESTS_SKIPPED"
}

reset_counters() {
    TESTS_PASSED=0
    TESTS_FAILED=0
    TESTS_SKIPPED=0
}
