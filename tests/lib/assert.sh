#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Exit codes
EXIT_SUCCESS=0
EXIT_FAILURE=1

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Core assertion framework
assert_test_start() {
    ((TESTS_TOTAL++))
}

assert_test_pass() {
    ((TESTS_PASSED++))
    log_info "✓ $1"
}

assert_test_fail() {
    ((TESTS_FAILED++))
    log_error "✗ $1"
    if [ "${FAIL_FAST:-false}" = "true" ]; then
        exit $EXIT_FAILURE
    fi
}

# Basic assertions
assert_eq() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Values should be equal}"

    assert_test_start
    if [ "$expected" = "$actual" ]; then
        assert_test_pass "$message"
    else
        assert_test_fail "$message (expected: '$expected', actual: '$actual')"
    fi
}

assert_not_eq() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Values should not be equal}"

    assert_test_start
    if [ "$expected" != "$actual" ]; then
        assert_test_pass "$message"
    else
        assert_test_fail "$message (both values: '$expected')"
    fi
}

# HTTP assertions
assert_http_200() {
    local url="$1"
    local timeout="${2:-10}"
    local message="${3:-HTTP 200 response from $url}"

    assert_test_start
    local status_code
    status_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$timeout" "$url" 2>/dev/null || echo "000")

    if [ "$status_code" = "200" ]; then
        assert_test_pass "$message"
    else
        assert_test_fail "$message (got HTTP $status_code)"
    fi
}

assert_http_ok() {
    local url="$1"
    local timeout="${2:-10}"
    local message="${3:-HTTP OK response (2xx) from $url}"

    assert_test_start
    local status_code
    status_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$timeout" "$url" 2>/dev/null || echo "000")

    if [[ "$status_code" =~ ^2[0-9][0-9]$ ]]; then
        assert_test_pass "$message"
    else
        assert_test_fail "$message (got HTTP $status_code)"
    fi
}

assert_http_body_contains() {
    local url="$1"
    local expected_content="$2"
    local timeout="${3:-10}"
    local message="${4:-HTTP response body contains '$expected_content'}"

    assert_test_start
    local response_body
    response_body=$(curl -s --max-time "$timeout" "$url" 2>/dev/null || echo "")

    if echo "$response_body" | grep -q "$expected_content"; then
        assert_test_pass "$message"
    else
        assert_test_fail "$message (content not found in response)"
    fi
}

# Container assertions
assert_container_running() {
    local container_name="$1"
    local message="${2:-Container '$container_name' is running}"

    assert_test_start
    if docker ps --format "table {{.Names}}" | grep -q "^${container_name}$"; then
        assert_test_pass "$message"
    else
        assert_test_fail "$message (container not found or not running)"
    fi
}

assert_container_healthy() {
    local container_name="$1"
    local message="${2:-Container '$container_name' is healthy}"

    assert_test_start
    local health_status
    health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "no-healthcheck")

    case "$health_status" in
        "healthy")
            assert_test_pass "$message"
            ;;
        "no-healthcheck")
            assert_test_pass "$message (no health check configured)"
            ;;
        "unhealthy")
            assert_test_fail "$message (container is unhealthy)"
            ;;
        "starting")
            log_warn "Container '$container_name' health check still starting, waiting..."
            sleep 5
            assert_container_healthy "$container_name" "$message"
            ;;
        *)
            assert_test_fail "$message (unknown health status: $health_status)"
            ;;
    esac
}

assert_container_not_restarting() {
    local container_name="$1"
    local message="${2:-Container '$container_name' is not restarting}"

    assert_test_start
    local restart_count
    restart_count=$(docker inspect --format='{{.RestartCount}}' "$container_name" 2>/dev/null || echo "unknown")

    if [ "$restart_count" = "0" ] || [ "$restart_count" = "unknown" ]; then
        assert_test_pass "$message"
    else
        assert_test_fail "$message (restart count: $restart_count)"
    fi
}

# Network assertions
assert_port_open() {
    local host="${1:-localhost}"
    local port="$2"
    local timeout="${3:-5}"
    local message="${4:-Port $port is open on $host}"

    assert_test_start
    if timeout "$timeout" bash -c "</dev/tcp/$host/$port" 2>/dev/null; then
        assert_test_pass "$message"
    else
        assert_test_fail "$message (port not reachable)"
    fi
}

# Test result summary
print_test_summary() {
    echo
    echo "================================"
    echo "Test Summary"
    echo "================================"
    echo "Total:  $TESTS_TOTAL"
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $TESTS_FAILED"

    if [ $TESTS_FAILED -eq 0 ]; then
        log_info "All tests passed! ✓"
        return $EXIT_SUCCESS
    else
        log_error "$TESTS_FAILED test(s) failed! ✗"
        return $EXIT_FAILURE
    fi
}

# Export functions for use in test files
export -f log_info log_warn log_error
export -f assert_test_start assert_test_pass assert_test_fail
export -f assert_eq assert_not_eq
export -f assert_http_200 assert_http_ok assert_http_body_contains
export -f assert_container_running assert_container_healthy assert_container_not_restarting
export -f assert_port_open
export -f print_test_summary
