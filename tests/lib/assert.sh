#!/bin/bash
# assert.sh - Assertion library for homelab-stack tests

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
CURRENT_TEST=""

# Report test start
test_start() {
    local test_name="$1"
    CURRENT_TEST="$test_name"
    ((TESTS_RUN++)) || true
    echo -e "${BLUE}[RUN]${NC} $test_name"
}

# Report test pass
test_pass() {
    echo -e "${GREEN}[PASS]${NC} $CURRENT_TEST"
    ((TESTS_PASSED++)) || true
}

# Report test fail
test_fail() {
    local message="${1:-Assertion failed}"
    echo -e "${RED}[FAIL]${NC} $CURRENT_TEST - $message"
    ((TESTS_FAILED++)) || true
}

# Assert equals
assert_eq() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Values not equal}"

    if [ "$expected" = "$actual" ]; then
        test_pass
        return 0
    else
        test_fail "$message (expected: '$expected', got: '$actual')"
        return 1
    fi
}

# Assert not equals
assert_neq() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Values should not be equal}"

    if [ "$expected" != "$actual" ]; then
        test_pass
        return 0
    else
        test_fail "$message (both were: '$expected')"
        return 1
    fi
}

# Assert contains
assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-String not found}"

    if echo "$haystack" | grep -q "$needle"; then
        test_pass
        return 0
    else
        test_fail "$message ('$needle' not in '$haystack')"
        return 1
    fi
}

# Assert HTTP 200
assert_http_200() {
    local url="$1"
    local message="${2:-HTTP request failed}"

    local status=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    if [ "$status" = "200" ]; then
        test_pass
        return 0
    else
        test_fail "$message (got HTTP $status from $url)"
        return 1
    fi
}

# Assert HTTP status code
assert_http_status() {
    local url="$1"
    local expected_status="$2"
    local message="${3:-HTTP status mismatch}"

    local status=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    if [ "$status" = "$expected_status" ]; then
        test_pass
        return 0
    else
        test_fail "$message (expected: $expected_status, got: $status)"
        return 1
    fi
}

# Assert JSON key exists
assert_json_key_exists() {
    local json="$1"
    local key="$2"
    local message="${3:-JSON key not found}"

    if echo "$json" | grep -q "$key"; then
        test_pass
        return 0
    else
        test_fail "$message (key '$key' not found in JSON)"
        return 1
    fi
}

# Assert JSON value
assert_json_value() {
    local json="$1"
    local key="$2"
    local expected="$3"
    local message="${4:-JSON value mismatch}"

    local actual=$(echo "$json" | grep -o "\"$key\"[[:space:]]*:[[:space:]]*[^,}]*" | sed 's/.*://' | tr -d ' "')
    if [ "$actual" = "$expected" ]; then
        test_pass
        return 0
    else
        test_fail "$message (expected: '$expected', got: '$actual')"
        return 1
    fi
}

# Assert container running
assert_container_running() {
    local container_name="$1"
    local message="${2:-Container not running}"

    if docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
        test_pass
        return 0
    else
        test_fail "$message (container '$container_name' not running)"
        return 1
    fi
}

# Assert container healthy
assert_container_healthy() {
    local container_name="$1"
    local message="${2:-Container not healthy}"

    local status=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "none")
    if [ "$status" = "healthy" ]; then
        test_pass
        return 0
    else
        test_fail "$message (container '$container_name' health: $status)"
        return 1
    fi
}

# Assert container exists (stopped or running)
assert_container_exists() {
    local container_name="$1"
    local message="${2:-Container does not exist}"

    if docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
        test_pass
        return 0
    else
        test_fail "$message (container '$container_name' not found)"
        return 1
    fi
}

# Assert no errors in response
assert_no_errors() {
    local response="$1"
    local message="${2:-Response contains errors}"

    if echo "$response" | grep -qi "error"; then
        test_fail "$message (response: $response)"
        return 1
    else
        test_pass
        return 0
    fi
}

# Assert exit code
assert_exit_code() {
    local expected_exit="$1"
    local message="${2:-Exit code mismatch}"
    shift 2
    "$@" >/dev/null 2>&1
    local actual_exit=$?

    if [ "$actual_exit" = "$expected_exit" ]; then
        test_pass
        return 0
    else
        test_fail "$message (expected: $expected_exit, got: $actual_exit)"
        return 1
    fi
}

# Assert not empty
assert_not_empty() {
    local value="$1"
    local message="${2:-Value is empty}"

    if [ -n "$value" ]; then
        test_pass
        return 0
    else
        test_fail "$message (value is empty)"
        return 1
    fi
}

# Assert empty
assert_empty() {
    local value="$1"
    local message="${2:-Value is not empty}"

    if [ -z "$value" ]; then
        test_pass
        return 0
    else
        test_fail "$message (value is: '$value')"
        return 1
    fi
}

# Print test summary
assert_summary() {
    echo ""
    echo "========================================"
    echo -e "Tests run: ${TESTS_RUN}"
    echo -e "Tests passed: ${GREEN}${TESTS_PASSED}${NC}"
    echo -e "Tests failed: ${RED}${TESTS_FAILED}${NC}"
    echo "========================================"
    echo ""

    if [ $TESTS_FAILED -gt 0 ]; then
        return 1
    else
        return 0
    fi
}

# Export functions
export -f test_start test_pass test_fail
export -f assert_eq assert_neq assert_contains
export -f assert_http_200 assert_http_status
export -f assert_json_key_exists assert_json_value
export -f assert_container_running assert_container_healthy assert_container_exists
export -f assert_no_errors assert_exit_code
export -f assert_not_empty assert_empty
export TESTS_RUN TESTS_PASSED TESTS_FAILED
