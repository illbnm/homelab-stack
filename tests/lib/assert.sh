#!/bin/bash

# Core assertion library for testing

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Log function
log() {
    echo -e "${1}"
}

# Success logging
log_success() {
    log "${GREEN}✓ ${1}${NC}"
}

# Error logging
log_error() {
    log "${RED}✗ ${1}${NC}"
}

# Warning logging
log_warning() {
    log "${YELLOW}⚠ ${1}${NC}"
}

# Assert equal function
assert_eq() {
    local expected="$1"
    local actual="$2"
    local message="${3:-"Values should be equal"}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [[ "$expected" == "$actual" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "$message"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_error "$message"
        log_error "  Expected: '$expected'"
        log_error "  Actual:   '$actual'"
        return 1
    fi
}

# Assert not equal function
assert_ne() {
    local expected="$1"
    local actual="$2"
    local message="${3:-"Values should not be equal"}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [[ "$expected" != "$actual" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "$message"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_error "$message"
        log_error "  Expected: NOT '$expected'"
        log_error "  Actual:   '$actual'"
        return 1
    fi
}

# Assert HTTP 200 status
assert_http_200() {
    local url="$1"
    local message="${2:-"HTTP request should return 200"}"
    local timeout="${3:-10}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    local status_code
    status_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$timeout" "$url" 2>/dev/null || echo "000")
    
    if [[ "$status_code" == "200" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "$message (URL: $url)"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_error "$message"
        log_error "  URL: $url"
        log_error "  Expected: 200"
        log_error "  Actual:   $status_code"
        return 1
    fi
}

# Assert HTTP status code
assert_http_status() {
    local expected_status="$1"
    local url="$2"
    local message="${3:-"HTTP request should return $expected_status"}"
    local timeout="${4:-10}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    local status_code
    status_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$timeout" "$url" 2>/dev/null || echo "000")
    
    if [[ "$status_code" == "$expected_status" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "$message (URL: $url)"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_error "$message"
        log_error "  URL: $url"
        log_error "  Expected: $expected_status"
        log_error "  Actual:   $status_code"
        return 1
    fi
}

# Assert container is running
assert_container_running() {
    local container_name="$1"
    local message="${2:-"Container should be running"}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    local status
    status=$(docker inspect --format='{{.State.Status}}' "$container_name" 2>/dev/null || echo "not_found")
    
    if [[ "$status" == "running" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "$message (Container: $container_name)"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_error "$message"
        log_error "  Container: $container_name"
        log_error "  Expected: running"
        log_error "  Actual:   $status"
        return 1
    fi
}

# Assert container is stopped
assert_container_stopped() {
    local container_name="$1"
    local message="${2:-"Container should be stopped"}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    local status
    status=$(docker inspect --format='{{.State.Status}}' "$container_name" 2>/dev/null || echo "not_found")
    
    if [[ "$status" == "exited" ]] || [[ "$status" == "not_found" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "$message (Container: $container_name)"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_error "$message"
        log_error "  Container: $container_name"
        log_error "  Expected: exited or not_found"
        log_error "  Actual:   $status"
        return 1
    fi
}

# Assert file exists
assert_file_exists() {
    local file_path="$1"
    local message="${2:-"File should exist"}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [[ -f "$file_path" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "$message (File: $file_path)"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_error "$message"
        log_error "  File: $file_path"
        return 1
    fi
}

# Assert directory exists
assert_dir_exists() {
    local dir_path="$1"
    local message="${2:-"Directory should exist"}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [[ -d "$dir_path" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "$message (Directory: $dir_path)"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_error "$message"
        log_error "  Directory: $dir_path"
        return 1
    fi
}

# Assert command succeeds
assert_command_success() {
    local command="$1"
    local message="${2:-"Command should succeed"}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if eval "$command" >/dev/null 2>&1; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "$message"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_error "$message"
        log_error "  Command: $command"
        return 1
    fi
}

# Assert command fails
assert_command_fails() {
    local command="$1"
    local message="${2:-"Command should fail"}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if ! eval "$command" >/dev/null 2>&1; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "$message"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_error "$message"
        log_error "  Command: $command"
        return 1
    fi
}

# Assert string contains substring
assert_contains() {
    local string="$1"
    local substring="$2"
    local message="${3:-"String should contain substring"}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [[ "$string" == *"$substring"* ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "$message"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_error "$message"
        log_error "  String: '$string'"
        log_error "  Should contain: '$substring'"
        return 1
    fi
}

# Assert string does not contain substring
assert_not_contains() {
    local string="$1"
    local substring="$2"
    local message="${3:-"String should not contain substring"}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [[ "$string" != *"$substring"* ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "$message"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_error "$message"
        log_error "  String: '$string'"
        log_error "  Should not contain: '$substring'"
        return 1
    fi
}

# Wait for condition with timeout
wait_for_condition() {
    local condition="$1"
    local timeout="${2:-30}"
    local message="${3:-"Waiting for condition"}"
    
    local start_time
    start_time=$(date +%s)
    
    while true; do
        if eval "$condition" >/dev/null 2>&1; then
            log_success "$message - condition met"
            return 0
        fi
        
        local current_time
        current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [[ $elapsed -ge $timeout ]]; then
            log_error "$message - timeout after ${timeout}s"
            return 1
        fi
        
        sleep 1
    done
}

# Print test summary
print_test_summary() {
    echo
    log "Test Summary:"
    log "  Total:  $TESTS_RUN"
    log_success "  Passed: $TESTS_PASSED"
    
    if [[ $TESTS_FAILED -gt 0 ]]; then
        log_error "  Failed: $TESTS_FAILED"
        return 1
    else
        log_success "  Failed: $TESTS_FAILED"
        return 0
    fi
}

# Reset test counters
reset_test_counters() {
    TESTS_RUN=0
    TESTS_PASSED=0
    TESTS_FAILED=0
}