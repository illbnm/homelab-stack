#!/bin/bash
# =============================================================================
# assert.sh - Testing assertion library
# =============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# -----------------------------------------------------------------------------
# Core assertions
# -----------------------------------------------------------------------------

assert_eq() {
    local actual="$1"
    local expected="$2"
    local msg="${3:-Values should be equal}"
    
    if [[ "$actual" == "$expected" ]]; then
        return 0
    else
        echo -e "${RED}ASSERT FAILED${NC}: $msg"
        echo "  Expected: $expected"
        echo "  Actual:   $actual"
        return 1
    fi
}

assert_not_empty() {
    local value="$1"
    local msg="${2:-Value should not be empty}"
    
    if [[ -n "$value" ]]; then
        return 0
    else
        echo -e "${RED}ASSERT FAILED${NC}: $msg"
        echo "  Value is empty"
        return 1
    fi
}

assert_exit_code() {
    local code="$1"
    local msg="${2:-Command should exit with code 0}"
    
    if [[ "$code" -eq 0 ]]; then
        return 0
    else
        echo -e "${RED}ASSERT FAILED${NC}: $msg"
        echo "  Exit code: $code"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Docker assertions
# -----------------------------------------------------------------------------

assert_container_running() {
    local name="$1"
    local msg="${2:-Container $name should be running}"
    
    local status
    status=$(docker inspect -f '{{.State.Status}}' "$name" 2>/dev/null || echo "not_found")
    
    if [[ "$status" == "running" ]]; then
        return 0
    else
        echo -e "${RED}ASSERT FAILED${NC}: $msg"
        echo "  Status: $status"
        return 1
    fi
}

assert_container_healthy() {
    local name="$1"
    local timeout="${2:-60}"
    local msg="${3:-Container $name should be healthy}"
    
    local start_time=$(date +%s)
    local current_time
    
    while true; do
        current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [[ $elapsed -ge $timeout ]]; then
            echo -e "${RED}ASSERT FAILED${NC}: $msg"
            echo "  Timeout after ${timeout}s"
            return 1
        fi
        
        local health
        health=$(docker inspect -f '{{.State.Health.Status}}' "$name" 2>/dev/null || echo "not_found")
        
        if [[ "$health" == "healthy" ]]; then
            return 0
        elif [[ "$health" == "unhealthy" ]]; then
            echo -e "${RED}ASSERT FAILED${NC}: $msg"
            echo "  Health: unhealthy"
            return 1
        fi
        
        sleep 2
    done
}

assert_container_exists() {
    local name="$1"
    local msg="${2:-Container $name should exist}"
    
    if docker inspect "$name" &>/dev/null; then
        return 0
    else
        echo -e "${RED}ASSERT FAILED${NC}: $msg"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# HTTP assertions
# -----------------------------------------------------------------------------

assert_http_200() {
    local url="$1"
    local timeout="${2:-30}"
    local msg="${3:-HTTP request should return 200}"
    
    local code
    code=$(curl -sf -o /dev/null -w "%{http_code}" --connect-timeout "$timeout" "$url" 2>/dev/null || echo "000")
    
    if [[ "$code" == "200" ]]; then
        return 0
    else
        echo -e "${RED}ASSERT FAILED${NC}: $msg"
        echo "  URL: $url"
        echo "  Expected: 200"
        echo "  Got: $code"
        return 1
    fi
}

assert_http_response() {
    local url="$1"
    local pattern="$2"
    local msg="${3:-HTTP response should contain pattern}"
    
    local response
    response=$(curl -sf --connect-timeout 30 "$url" 2>/dev/null)
    
    if echo "$response" | grep -q "$pattern"; then
        return 0
    else
        echo -e "${RED}ASSERT FAILED${NC}: $msg"
        echo "  URL: $url"
        echo "  Pattern: $pattern"
        return 1
    fi
}

assert_http_redirect() {
    local url="$1"
    local expected_location="${2:-}"
    local msg="${3:-HTTP should redirect}"
    
    local location
    location=$(curl -sf -o /dev/null -w "%{redirect_url}" "$url" 2>/dev/null)
    
    if [[ -n "$location" ]]; then
        if [[ -n "$expected_location" ]]; then
            if [[ "$location" == *"$expected_location"* ]]; then
                return 0
            else
                echo -e "${RED}ASSERT FAILED${NC}: $msg"
                echo "  Expected location: $expected_location"
                echo "  Got: $location"
                return 1
            fi
        fi
        return 0
    else
        echo -e "${RED}ASSERT FAILED${NC}: $msg"
        echo "  No redirect found"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# JSON assertions
# -----------------------------------------------------------------------------

assert_json_value() {
    local json="$1"
    local jq_path="$2"
    local expected="$3"
    local msg="${4:-JSON value should match}"
    
    local actual
    actual=$(echo "$json" | jq -r "$jq_path" 2>/dev/null)
    
    if [[ "$actual" == "$expected" ]]; then
        return 0
    else
        echo -e "${RED}ASSERT FAILED${NC}: $msg"
        echo "  Path: $jq_path"
        echo "  Expected: $expected"
        echo "  Got: $actual"
        return 1
    fi
}

assert_json_key_exists() {
    local json="$1"
    local jq_path="$2"
    local msg="${3:-JSON key should exist}"
    
    if echo "$json" | jq -e "$jq_path" &>/dev/null; then
        return 0
    else
        echo -e "${RED}ASSERT FAILED${NC}: $msg"
        echo "  Path: $jq_path"
        echo "  Key not found"
        return 1
    fi
}

assert_no_errors() {
    local json="$1"
    local msg="${2:-JSON should have no errors}"
    
    local errors
    errors=$(echo "$json" | jq -r '.errors // empty' 2>/dev/null)
    
    if [[ -z "$errors" || "$errors" == "null" ]]; then
        return 0
    else
        echo -e "${RED}ASSERT FAILED${NC}: $msg"
        echo "  Errors: $errors"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# File assertions
# -----------------------------------------------------------------------------

assert_file_exists() {
    local file="$1"
    local msg="${2:-File should exist}"
    
    if [[ -f "$file" ]]; then
        return 0
    else
        echo -e "${RED}ASSERT FAILED${NC}: $msg"
        echo "  File: $file"
        return 1
    fi
}

assert_file_contains() {
    local file="$1"
    local pattern="$2"
    local msg="${3:-File should contain pattern}"
    
    if grep -q "$pattern" "$file" 2>/dev/null; then
        return 0
    else
        echo -e "${RED}ASSERT FAILED${NC}: $msg"
        echo "  File: $file"
        echo "  Pattern: $pattern"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Compose assertions
# -----------------------------------------------------------------------------

assert_no_latest_images() {
    local dir="$1"
    local msg="${2:-No :latest image tags should be used}"
    
    local count
    count=$(grep -r 'image:.*:latest' "$dir" 2>/dev/null | wc -l || echo "0")
    
    if [[ "$count" -eq 0 ]]; then
        return 0
    else
        echo -e "${RED}ASSERT FAILED${NC}: $msg"
        echo "  Found $count :latest tags"
        grep -r 'image:.*:latest' "$dir" 2>/dev/null || true
        return 1
    fi
}

assert_all_services_have_healthcheck() {
    local compose_file="$1"
    local msg="${2:-All services should have healthcheck}"
    
    local services_without_healthcheck
    services_without_healthcheck=$(python3 -c "
import yaml
import sys

with open('$compose_file') as f:
    config = yaml.safe_load(f)

services = config.get('services', {})
missing = []

for name, service in services.items():
    if 'healthcheck' not in service:
        missing.append(name)

if missing:
    print(','.join(missing))
    sys.exit(1)
else:
    sys.exit(0)
" 2>/dev/null)
    
    if [[ $? -eq 0 ]]; then
        return 0
    else
        echo -e "${RED}ASSERT FAILED${NC}: $msg"
        echo "  Missing healthcheck: $services_without_healthcheck"
        return 1
    fi
}
