#!/bin/bash

# Assert library for HomeLab Stack testing
# Provides common assertion functions with colored output

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Test counters
ASSERT_TOTAL=0
ASSERT_PASSED=0
ASSERT_FAILED=0

# Initialize test counters
init_assertions() {
    ASSERT_TOTAL=0
    ASSERT_PASSED=0
    ASSERT_FAILED=0
}

# Print test result
print_result() {
    local status=$1
    local message=$2

    ASSERT_TOTAL=$((ASSERT_TOTAL + 1))

    if [ "$status" = "PASS" ]; then
        ASSERT_PASSED=$((ASSERT_PASSED + 1))
        echo -e "${GREEN}✓${NC} $message"
    else
        ASSERT_FAILED=$((ASSERT_FAILED + 1))
        echo -e "${RED}✗${NC} $message"
    fi
}

# Print test summary
print_summary() {
    echo ""
    echo "Test Results:"
    echo "  Total: $ASSERT_TOTAL"
    echo -e "  ${GREEN}Passed: $ASSERT_PASSED${NC}"
    if [ "$ASSERT_FAILED" -gt 0 ]; then
        echo -e "  ${RED}Failed: $ASSERT_FAILED${NC}"
        return 1
    else
        echo "  Failed: 0"
        return 0
    fi
}

# Basic equality assertion
assert_eq() {
    local expected=$1
    local actual=$2
    local message=${3:-"Expected '$expected', got '$actual'"}

    if [ "$expected" = "$actual" ]; then
        print_result "PASS" "$message"
        return 0
    else
        print_result "FAIL" "$message"
        return 1
    fi
}

# String contains assertion
assert_contains() {
    local haystack=$1
    local needle=$2
    local message=${3:-"Expected '$haystack' to contain '$needle'"}

    if [[ "$haystack" == *"$needle"* ]]; then
        print_result "PASS" "$message"
        return 0
    else
        print_result "FAIL" "$message"
        return 1
    fi
}

# Check if container is running
assert_container_running() {
    local container_name=$1
    local message=${2:-"Container '$container_name' should be running"}

    if docker ps --filter "name=$container_name" --filter "status=running" --format "{{.Names}}" | grep -q "^${container_name}$"; then
        print_result "PASS" "$message"
        return 0
    else
        print_result "FAIL" "$message"
        return 1
    fi
}

# Check if container is healthy
assert_container_healthy() {
    local container_name=$1
    local message=${2:-"Container '$container_name' should be healthy"}

    local health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null)

    if [ "$health_status" = "healthy" ]; then
        print_result "PASS" "$message"
        return 0
    elif [ "$health_status" = "" ]; then
        # No health check defined, check if running
        if docker ps --filter "name=$container_name" --filter "status=running" --format "{{.Names}}" | grep -q "^${container_name}$"; then
            print_result "PASS" "$message (no healthcheck, but running)"
            return 0
        else
            print_result "FAIL" "$message (not running)"
            return 1
        fi
    else
        print_result "FAIL" "$message (status: $health_status)"
        return 1
    fi
}

# Check if container exists
assert_container_exists() {
    local container_name=$1
    local message=${2:-"Container '$container_name' should exist"}

    if docker ps -a --filter "name=$container_name" --format "{{.Names}}" | grep -q "^${container_name}$"; then
        print_result "PASS" "$message"
        return 0
    else
        print_result "FAIL" "$message"
        return 1
    fi
}

# HTTP 200 status assertion
assert_http_200() {
    local url=$1
    local timeout=${2:-10}
    local message=${3:-"HTTP GET $url should return 200"}

    local status_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$timeout" "$url" 2>/dev/null)

    if [ "$status_code" = "200" ]; then
        print_result "PASS" "$message"
        return 0
    else
        print_result "FAIL" "$message (got: $status_code)"
        return 1
    fi
}

# HTTP status assertion (any status)
assert_http_status() {
    local url=$1
    local expected_status=$2
    local timeout=${3:-10}
    local message=${4:-"HTTP GET $url should return $expected_status"}

    local status_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$timeout" "$url" 2>/dev/null)

    if [ "$status_code" = "$expected_status" ]; then
        print_result "PASS" "$message"
        return 0
    else
        print_result "FAIL" "$message (got: $status_code)"
        return 1
    fi
}

# Network connectivity assertion
assert_port_open() {
    local host=$1
    local port=$2
    local timeout=${3:-5}
    local message=${4:-"Port $port on $host should be open"}

    if timeout "$timeout" bash -c "</dev/tcp/$host/$port" 2>/dev/null; then
        print_result "PASS" "$message"
        return 0
    else
        print_result "FAIL" "$message"
        return 1
    fi
}

# File exists assertion
assert_file_exists() {
    local file_path=$1
    local message=${2:-"File '$file_path' should exist"}

    if [ -f "$file_path" ]; then
        print_result "PASS" "$message"
        return 0
    else
        print_result "FAIL" "$message"
        return 1
    fi
}

# Directory exists assertion
assert_dir_exists() {
    local dir_path=$1
    local message=${2:-"Directory '$dir_path' should exist"}

    if [ -d "$dir_path" ]; then
        print_result "PASS" "$message"
        return 0
    else
        print_result "FAIL" "$message"
        return 1
    fi
}

# Environment variable assertion
assert_env_set() {
    local var_name=$1
    local message=${2:-"Environment variable '$var_name' should be set"}

    if [ -n "${!var_name}" ]; then
        print_result "PASS" "$message"
        return 0
    else
        print_result "FAIL" "$message"
        return 1
    fi
}

# Docker volume exists assertion
assert_volume_exists() {
    local volume_name=$1
    local message=${2:-"Docker volume '$volume_name' should exist"}

    if docker volume ls --filter "name=$volume_name" --format "{{.Name}}" | grep -q "^${volume_name}$"; then
        print_result "PASS" "$message"
        return 0
    else
        print_result "FAIL" "$message"
        return 1
    fi
}

# Docker network exists assertion
assert_network_exists() {
    local network_name=$1
    local message=${2:-"Docker network '$network_name' should exist"}

    if docker network ls --filter "name=$network_name" --format "{{.Name}}" | grep -q "^${network_name}$"; then
        print_result "PASS" "$message"
        return 0
    else
        print_result "FAIL" "$message"
        return 1
    fi
}

# Wait for condition with timeout
wait_for_condition() {
    local condition_func=$1
    local timeout=${2:-30}
    local interval=${3:-2}
    local description=${4:-"condition"}

    local elapsed=0

    while [ $elapsed -lt $timeout ]; do
        if $condition_func; then
            echo -e "${GREEN}✓${NC} $description met after ${elapsed}s"
            return 0
        fi

        sleep $interval
        elapsed=$((elapsed + interval))
    done

    echo -e "${RED}✗${NC} $description not met within ${timeout}s"
    return 1
}
