#!/usr/bin/env bash
# Assertion library for HomeLab Stack integration testing

assert_eq() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Values should be equal}"
    if [ "$expected" = "$actual" ]; then
        return 0
    else
        echo "FAIL: $message (Expected: '$expected', Got: '$actual')" >&2
        return 1
    fi
}

assert_http_200() {
    local url="$1"
    local message="${2:-HTTP endpoint should return 200 OK}"
    local code
    code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$url" 2>/dev/null || echo "000")
    if [ "$code" = "200" ] || [ "$code" = "301" ] || [ "$code" = "302" ]; then
        return 0
    else
        echo "FAIL: $message ($url returned status $code)" >&2
        return 1
    fi
}

assert_container_running() {
    local name="$1"
    local status
    status=$(docker inspect -f '{{.State.Running}}' "$name" 2>/dev/null || echo "false")
    if [ "$status" = "true" ]; then
        return 0
    else
        echo "FAIL: Container '$name' is not running" >&2
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    if [ -f "$file" ]; then
        return 0
    else
        echo "FAIL: Required file '$file' not found" >&2
        return 1
    fi
}
