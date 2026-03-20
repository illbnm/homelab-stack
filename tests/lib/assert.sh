#!/bin/bash

# Assertion library for HomeLab Stack integration tests

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

# Assert functions
assert_eq() {
    local actual="$1"
    local expected="$2"
    local msg="${3:-Assertion failed}"
    if [[ "$actual" != "$expected" ]]; then
        log_error "$msg: expected '$expected', got '$actual'"
        return 1
    else
        log_success "$msg"
        return 0
    fi
}

assert_not_empty() {
    local value="$1"
    local msg="${2:-Value should not be empty}"
    if [[ -z "$value" ]]; then
        log_error "$msg: value is empty"
        return 1
    else
        log_success "$msg"
        return 0
    fi
}

assert_exit_code() {
    local code="$1"
    local msg="${2:-Command failed with non-zero exit code}"
    if [[ "$code" != "0" ]]; then
        log_error "$msg: exit code $code"
        return 1
    else
        log_success "$msg"
        return 0
    fi
}

assert_container_running() {
    local name="$1"
    local msg="${2:-Container $name should be running}"
    local running=$(docker ps --format "table {{.Names}}" | grep -w "$name" || echo "")
    if [[ -n "$running" ]]; then
        log_success "$msg"
        return 0
    else
        log_error "$msg: container not running"
        return 1
    fi
}

assert_container_healthy() {
    local name="$1"
    local timeout="${2:-60}"
    local msg="${3:-Container $name should be healthy}"
    
    local start_time=$(date +%s)
    local end_time=$((start_time + timeout))
    
    while [[ $(date +%s) -lt $end_time ]]; do
        local health=$(docker inspect "$name" --format='{{.State.Health.Status}}' 2>/dev/null || echo "")
        if [[ "$health" == "healthy" ]]; then
            log_success "$msg"
            return 0
        fi
        sleep 1
    done
    
    log_error "$msg: container not healthy after $timeout seconds"
    return 1
}

assert_http_200() {
    local url="$1"
    local timeout="${2:-30}"
    local msg="${3:-HTTP request should return 200}"
    
    local start_time=$(date +%s)
    local end_time=$((start_time + timeout))
    
    while [[ $(date +%s) -lt $end_time ]]; do
        local status=$(curl -s -o /dev/null -w "%{http_code}" "$url" || echo "")
        if [[ "$status" == "200" ]]; then
            log_success "$msg"
            return 0
        fi
        sleep 1
    done
    
    log_error "$msg: expected 200, got $status"
    return 1
}

assert_http_response() {
    local url="$1"
    local pattern="$2"
    local msg="${3:-HTTP response should match pattern}"
    
    if curl -s "$url" | grep -q "$pattern"; then
        log_success "$msg"
        return 0
    else
        log_error "$msg: pattern not found in response from $url"
        return 1
    fi
}

assert_json_value() {
    local json="$1"
    local jq_path="$2"
    local expected="$3"
    local msg="${4:-JSON value assertion failed}"
    
    local actual=$(echo "$json" | jq -r "$jq_path" 2>/dev/null || echo "")
    if [[ "$actual" != "$expected" ]]; then
        log_error "$msg: expected '$expected' at '$jq_path', got '$actual'"
        return 1
    else
        log_success "$msg"
        return 0
    fi
}

assert_json_key_exists() {
    local json="$1"
    local jq_path="$2"
    local msg="${3:-JSON key assertion failed}"
    
    local exists=$(echo "$json" | jq -e "$jq_path" 2>/dev/null && echo "true" || echo "false")
    if [[ "$exists" != "true" ]]; then
        log_error "$msg: key '$jq_path' not found"
        return 1
    else
        log_success "$msg"
        return 0
    fi
}

assert_no_errors() {
    local json="$1"
    local msg="${2:-JSON should have no errors}"
    
    local errors=$(echo "$json" | jq -r '.errors? // empty' 2>/dev/null)
    if [[ -n "$errors" ]]; then
        log_error "$msg: found errors in JSON"
        return 1
    else
        log_success "$msg"
        return 0
    fi
}

assert_file_contains() {
    local file="$1"
    local pattern="$2"
    local msg="${3:-File should contain pattern}"
    
    if grep -q "$pattern" "$file" 2>/dev/null; then
        log_success "$msg"
        return 0
    else
        log_error "$msg: pattern not found in $file"
        return 1
    fi
}

assert_no_latest_images() {
    local dir="$1"
    local msg="${2:-Should not find :latest image tags}"
    
    local count=$(grep -r ':latest' "$dir" | wc -l || echo "0")
    if [[ "$count" -gt 0 ]]; then
        log_error "$msg: found $count :latest tags"
        return 1
    else
        log_success "$msg"
        return 0
    fi
}

# Utility functions

wait_for_healthy() {
    local timeout="${1:-120}"
    local start_time=$(date +%s)
    local end_time=$((start_time + timeout))
    
    log_info "Waiting for all services to be healthy..."
    
    while [[ $(date +%s) -lt $end_time ]]; do
        local unhealthy=$(docker ps --format "table {{.Names}} {{.Status}}" | grep -E "(unhealthy|starting)" || echo "")
        if [[ -z "$unhealthy" ]]; then
            log_success "All services are healthy"
            return 0
        fi
        sleep 5
    done
    
    log_error "Services not healthy after $timeout seconds"
    return 1
}

# Export all functions for use in other scripts
export -f assert_eq assert_not_empty assert_exit_code assert_container_running assert_container_healthy assert_http_200 assert_http_response assert_json_value assert_json_key_exists assert_no_errors assert_file_contains assert_no_latest_images wait_for_healthy