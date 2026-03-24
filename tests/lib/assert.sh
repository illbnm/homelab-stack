#!/usr/bin/env bash
# ==============================================================================
# HomeLab Stack — Assertion Library
# Provides assertion functions for testing Docker containers and services
# ==============================================================================

# Colors for output
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

# Test counters (global)
PASSED=${PASSED:-0}
FAILED=${FAILED:-0}
SKIPPED=${SKIPPED:-0}

# Timing
_TEST_START=""

# Start timing a test
begin_test() {
    _TEST_START=$(date +%s%N)
}

# End timing and return duration in seconds
end_test() {
    local end=$(date +%s%N)
    local duration=$(( (end - _TEST_START) / 1000000 ))
    echo "$(echo "scale=1; $duration / 1000" | bc)"
}

# Log pass
log_pass() {
    local duration=""
    [[ -n "$_TEST_START" ]] && duration=" ($(end_test)s)"
    echo -e "  ${GREEN}✓ PASS${NC} $*${duration}"
    ((PASSED++))
}

# Log fail
log_fail() {
    local duration=""
    [[ -n "$_TEST_START" ]] && duration=" ($(end_test)s)"
    echo -e "  ${RED}✗ FAIL${NC} $*${duration}"
    ((FAILED++))
}

# Log skip
log_skip() {
    echo -e "  ${YELLOW}⊘ SKIP${NC} $*"
    ((SKIPPED++))
}

# Log group header
log_group() {
    echo -e "\n${BLUE}[$*]${NC}"
}

# =============================================================================
# Basic Assertions
# =============================================================================

# Assert two values are equal
assert_eq() {
    local actual="$1" expected="$2" msg="${3:-Values should be equal}"
    begin_test
    if [[ "$actual" == "$expected" ]]; then
        log_pass "$msg"
        return 0
    else
        log_fail "$msg — Expected: '$expected', Got: '$actual'"
        return 1
    fi
}

# Assert value is not empty
assert_not_empty() {
    local value="$1" msg="${2:-Value should not be empty}"
    begin_test
    if [[ -n "$value" ]]; then
        log_pass "$msg"
        return 0
    else
        log_fail "$msg — Value is empty"
        return 1
    fi
}

# Assert exit code
assert_exit_code() {
    local expected="$1" msg="${2:-Command should exit with expected code}"
    begin_test
    if [[ $? -eq "$expected" ]]; then
        log_pass "$msg"
        return 0
    else
        log_fail "$msg — Expected exit code $expected, got $?"
        return 1
    fi
}

# =============================================================================
# Docker Assertions
# =============================================================================

# Assert container is running
assert_container_running() {
    local name="$1"
    begin_test
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${name}$"; then
        log_pass "Container $name is running"
        return 0
    else
        log_fail "Container $name is not running"
        return 1
    fi
}

# Assert container is healthy (wait up to 60s)
assert_container_healthy() {
    local name="$1" timeout="${2:-60}"
    begin_test
    local elapsed=0
    
    while [[ $elapsed -lt $timeout ]]; do
        local status=$(docker inspect --format '{{.State.Health.Status}}' "$name" 2>/dev/null || echo "not-found")
        
        case "$status" in
            healthy)
                log_pass "Container $name is healthy"
                return 0
                ;;
            unhealthy)
                log_fail "Container $name is unhealthy"
                return 1
                ;;
            "not-found")
                log_fail "Container $name not found"
                return 1
                ;;
        esac
        
        sleep 2
        ((elapsed += 2))
    done
    
    log_fail "Container $name health check timed out after ${timeout}s"
    return 1
}

# Assert container exists (running or stopped)
assert_container_exists() {
    local name="$1"
    begin_test
    if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^${name}$"; then
        log_pass "Container $name exists"
        return 0
    else
        log_fail "Container $name does not exist"
        return 1
    fi
}

# =============================================================================
# HTTP Assertions
# =============================================================================

# Assert HTTP response code
assert_http_code() {
    local url="$1" expected="${2:-200}" timeout="${3:-30}"
    begin_test
    local code=$(curl -sf -o /dev/null -w '%{http_code}' \
        --connect-timeout 5 --max-time "$timeout" "$url" 2>/dev/null || echo "000")
    
    if [[ "$code" == "$expected" ]]; then
        log_pass "HTTP $code — $url"
        return 0
    else
        log_fail "HTTP $code — $url (expected $expected)"
        return 1
    fi
}

# Assert HTTP 200
assert_http_200() {
    local url="$1" timeout="${2:-30}"
    assert_http_code "$url" 200 "$timeout"
}

# Assert HTTP response contains pattern
assert_http_response() {
    local url="$1" pattern="$2" timeout="${3:-30}"
    begin_test
    local response=$(curl -sf --connect-timeout 5 --max-time "$timeout" "$url" 2>/dev/null)
    
    if echo "$response" | grep -q "$pattern"; then
        log_pass "Response matches pattern — $url"
        return 0
    else
        log_fail "Response does not match pattern '$pattern' — $url"
        return 1
    fi
}

# =============================================================================
# JSON Assertions
# =============================================================================

# Assert JSON value equals expected
assert_json_value() {
    local json="$1" path="$2" expected="$3"
    begin_test
    local actual=$(echo "$json" | jq -r "$path" 2>/dev/null)
    
    if [[ "$actual" == "$expected" ]]; then
        log_pass "JSON $path == '$expected'"
        return 0
    else
        log_fail "JSON $path — Expected: '$expected', Got: '$actual'"
        return 1
    fi
}

# Assert JSON key exists
assert_json_key_exists() {
    local json="$1" path="$2"
    begin_test
    local value=$(echo "$json" | jq -r "$path // empty" 2>/dev/null)
    
    if [[ -n "$value" ]]; then
        log_pass "JSON key exists: $path"
        return 0
    else
        log_fail "JSON key missing: $path"
        return 1
    fi
}

# Assert no errors in JSON response
assert_no_errors() {
    local json="$1"
    begin_test
    local errors=$(echo "$json" | jq -r '.errors // empty' 2>/dev/null)
    
    if [[ -z "$errors" ]] || [[ "$errors" == "null" ]]; then
        log_pass "No errors in response"
        return 0
    else
        log_fail "Errors found in response: $errors"
        return 1
    fi
}

# =============================================================================
# File Assertions
# =============================================================================

# Assert file contains pattern
assert_file_contains() {
    local file="$1" pattern="$2"
    begin_test
    if [[ ! -f "$file" ]]; then
        log_fail "File not found: $file"
        return 1
    fi
    
    if grep -q "$pattern" "$file" 2>/dev/null; then
        log_pass "File contains pattern: $file"
        return 0
    else
        log_fail "Pattern not found in $file: $pattern"
        return 1
    fi
}

# Assert file exists
assert_file_exists() {
    local file="$1"
    begin_test
    if [[ -f "$file" ]]; then
        log_pass "File exists: $file"
        return 0
    else
        log_fail "File not found: $file"
        return 1
    fi
}

# =============================================================================
# Docker Compose Assertions
# =============================================================================

# Assert no :latest image tags in compose files
assert_no_latest_tags() {
    local dir="$1"
    begin_test
    local count=$(grep -r 'image:.*:latest' "$dir" 2>/dev/null | wc -l || echo 0)
    
    if [[ "$count" -eq 0 ]]; then
        log_pass "No :latest tags found in $dir"
        return 0
    else
        log_fail "Found $count :latest tags in $dir"
        return 1
    fi
}

# Assert compose file syntax is valid
assert_compose_syntax() {
    local file="$1"
    begin_test
    if docker compose -f "$file" config --quiet 2>/dev/null; then
        log_pass "Valid compose syntax: $file"
        return 0
    else
        log_fail "Invalid compose syntax: $file"
        return 1
    fi
}

# Assert all services have healthcheck
assert_all_have_healthcheck() {
    local file="$1"
    begin_test
    local missing=$(docker compose -f "$file" config 2>/dev/null | \
        yq '.services | to_entries | map(select(.value.healthcheck == null)) | length' 2>/dev/null || echo "unknown")
    
    if [[ "$missing" == "0" ]]; then
        log_pass "All services have healthcheck: $file"
        return 0
    else
        log_fail "$missing services missing healthcheck in $file"
        return 1
    fi
}