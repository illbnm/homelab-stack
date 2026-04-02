#!/bin/bash
# Assertion library for testing

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Assert equals
assert_eq() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Values should be equal}"
    
    if [ "$expected" = "$actual" ]; then
        echo -e "${GREEN}✓${NC} $message"
        return 0
    else
        echo -e "${RED}✗${NC} $message"
        echo "  Expected: $expected"
        echo "  Actual:   $actual"
        return 1
    fi
}

# Assert HTTP 200
assert_http_200() {
    local url="$1"
    local message="${2:-$url should return 200}"
    
    local status=$(curl -s -o /dev/null -w "%{http_code}" "$url" --connect-timeout 5)
    
    if [ "$status" = "200" ]; then
        echo -e "${GREEN}✓${NC} $message"
        return 0
    else
        echo -e "${RED}✗${NC} $message (got $status)"
        return 1
    fi
}

# Assert container running
assert_container_running() {
    local container="$1"
    local message="${2:-Container $container should be running}"
    
    if docker ps --filter "name=$container" --filter "status=running" | grep -q "$container"; then
        echo -e "${GREEN}✓${NC} $message"
        return 0
    else
        echo -e "${RED}✗${NC} $message"
        return 1
    fi
}

# Assert container healthy
assert_container_healthy() {
    local container="$1"
    local message="${2:-Container $container should be healthy}"
    
    local health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null)
    
    if [ "$health" = "healthy" ]; then
        echo -e "${GREEN}✓${NC} $message"
        return 0
    else
        echo -e "${RED}✗${NC} $message (status: $health)"
        return 1
    fi
}

# Assert JSON value
assert_json_value() {
    local json="$1"
    local path="$2"
    local expected="$3"
    local message="${4:-JSON value at $path should be $expected}"
    
    local actual=$(echo "$json" | jq -r "$path" 2>/dev/null)
    
    if [ "$actual" = "$expected" ]; then
        echo -e "${GREEN}✓${NC} $message"
        return 0
    else
        echo -e "${RED}✗${NC} $message (got $actual)"
        return 1
    fi
}
