#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Test Assertion Library
# Copyright (c) 2026 思捷娅科技 (SJYKJ)
# License: MIT
# =============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Counters
ASSERT_PASS=0
ASSERT_FAIL=0
ASSERT_SKIP=0

# ---- Core Assertions ----

assert_eq() {
    local actual="$1" expected="$2" msg="${3:-assert_eq}"
    if [[ "$actual" == "$expected" ]]; then
        ((ASSERT_PASS++))
        return 0
    else
        ((ASSERT_FAIL++))
        echo -e "  ${RED}Expected: '$expected', Got: '$actual'${NC} ($msg)" >&2
        return 1
    fi
}

assert_not_empty() {
    local value="$1" msg="${2:-value should not be empty}"
    if [[ -n "$value" ]]; then
        ((ASSERT_PASS++))
        return 0
    else
        ((ASSERT_FAIL++))
        echo -e "  ${RED}$msg${NC}" >&2
        return 1
    fi
}

assert_exit_code() {
    local code="$1" msg="${2:-exit code should be $1}"
    if [[ "$code" -eq 0 ]]; then
        ((ASSERT_PASS++))
        return 0
    else
        ((ASSERT_FAIL++))
        echo -e "  ${RED}$msg (exit=$code)${NC}" >&2
        return 1
    fi
}

# ---- Docker Assertions ----

assert_container_running() {
    local name="$1"
    local state
    state=$(docker inspect --format '{{.State.Status}}' "$name" 2>/dev/null || echo "missing")
    if [[ "$state" == "running" ]]; then
        ((ASSERT_PASS++))
        return 0
    else
        ((ASSERT_FAIL++))
        echo -e "  ${RED}Container '$name' is '$state' (expected running)${NC}" >&2
        return 1
    fi
}

assert_container_healthy() {
    local name="$1" timeout="${2:-60}"
    local elapsed=0
    while [[ $elapsed -lt $timeout ]]; do
        local health
        health=$(docker inspect --format '{{.State.Health.Status}}' "$name" 2>/dev/null || echo "missing")
        if [[ "$health" == "healthy" ]]; then
            ((ASSERT_PASS++))
            return 0
        fi
        sleep 2
        ((elapsed += 2))
    done
    local health
    health=$(docker inspect --format '{{.State.Health.Status}}' "$name" 2>/dev/null || echo "missing")
    ((ASSERT_FAIL++))
    echo -e "  ${RED}Container '$name' not healthy after ${timeout}s (status: $health)${NC}" >&2
    return 1
}

# ---- HTTP Assertions ----

assert_http_200() {
    local url="$1" timeout="${2:-30}"
    local code
    code=$(curl -sk -o /dev/null -w '%{http_code}' --max-time "$timeout" "$url" 2>/dev/null || echo "000")
    if [[ "$code" == "200" ]]; then
        ((ASSERT_PASS++))
        return 0
    else
        ((ASSERT_FAIL++))
        echo -e "  ${RED}HTTP $url returned $code (expected 200)${NC}" >&2
        return 1
    fi
}

assert_http_response() {
    local url="$1" pattern="$2"
    local body
    body=$(curl -sk --max-time 30 "$url" 2>/dev/null || echo "")
    if echo "$body" | grep -q "$pattern"; then
        ((ASSERT_PASS++))
        return 0
    else
        ((ASSERT_FAIL++))
        echo -e "  ${RED}HTTP $url response missing pattern '$pattern'${NC}" >&2
        return 1
    fi
}

# ---- JSON Assertions (requires jq) ----

assert_json_value() {
    local json="$1" path="$2" expected="$3"
    local actual
    actual=$(echo "$json" | jq -r "$path" 2>/dev/null || echo "PARSE_ERROR")
    if [[ "$actual" == "$expected" ]]; then
        ((ASSERT_PASS++))
        return 0
    else
        ((ASSERT_FAIL++))
        echo -e "  ${RED}JSON $path: expected '$expected', got '$actual'${NC}" >&2
        return 1
    fi
}

assert_json_key_exists() {
    local json="$1" path="$2"
    local val
    val=$(echo "$json" | jq -e "$path" 2>/dev/null)
    if [[ $? -eq 0 ]]; then
        ((ASSERT_PASS++))
        return 0
    else
        ((ASSERT_FAIL++))
        echo -e "  ${RED}JSON path '$path' not found${NC}" >&2
        return 1
    fi
}

assert_no_errors() {
    local json="$1"
    local errors
    errors=$(echo "$json" | jq -r '.errors // empty' 2>/dev/null)
    if [[ -z "$errors" ]]; then
        ((ASSERT_PASS++))
        return 0
    else
        ((ASSERT_FAIL++))
        echo -e "  ${RED}JSON contains errors: $errors${NC}" >&2
        return 1
    fi
}

# ---- File Assertions ----

assert_file_contains() {
    local file="$1" pattern="$2"
    if [[ -f "$file" ]] && grep -q "$pattern" "$file"; then
        ((ASSERT_PASS++))
        return 0
    else
        ((ASSERT_FAIL++))
        echo -e "  ${RED}File '$file' missing pattern '$pattern'${NC}" >&2
        return 1
    fi
}

# ---- Compose Assertions ----

assert_no_latest_images() {
    local dir="$1"
    local count
    count=$(grep -r 'image:.*:latest' "$dir" 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$count" -eq 0 ]]; then
        ((ASSERT_PASS++))
        return 0
    else
        ((ASSERT_FAIL++))
        echo -e "  ${RED}Found $count services using :latest tag${NC}" >&2
        return 1
    fi
}
