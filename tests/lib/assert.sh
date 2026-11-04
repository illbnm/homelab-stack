#!/usr/bin/env bash
# tests/lib/assert.sh
# Core test assertion primitives

assert_eq() {
    local actual="$1"
    local expected="$2"
    local msg="${3:-Values do not match}"
    if [ "$actual" != "$expected" ]; then
        echo -e "[FAIL] $msg (Expected: '$expected', Got: '$actual')" >&2
        return 1
    fi
    return 0
}

assert_not_empty() {
    local val="$1"
    local msg="${2:-Value is empty}"
    if [ -z "$val" ]; then
        echo -e "[FAIL] $msg" >&2
        return 1
    fi
    return 0
}

assert_exit_code() {
    local expected="$1"
    local actual="$?"
    local msg="${2:-Exit code mismatch}"
    assert_eq "$actual" "$expected" "$msg"
}

assert_container_running() {
    local name="$1"
    local state
    state=$(docker inspect -f '{{.State.Running}}' "$name" 2>/dev/null || echo "false")
    if [ "$state" != "true" ]; then
        echo -e "[FAIL] Container $name is not running" >&2
        return 1
    fi
    return 0
}

assert_container_healthy() {
    local name="$1"
    local timeout="${2:-60}"
    local count=0
    while [ $count -lt "$timeout" ]; do
        local health
        health=$(docker inspect -f '{{.State.Health.Status}}' "$name" 2>/dev/null || echo "none")
        if [ "$health" = "healthy" ]; then
            return 0
        fi
        sleep 2
        count=$((count + 2))
    done
    echo -e "[FAIL] Container $name failed to report healthy within ${timeout}s" >&2
    return 1
}

assert_http_200() {
    local url="$1"
    local timeout="${2:-30}"
    local code
    code=$(curl -s -o /dev/null -w "%{http_code}" -m "$timeout" "$url" 2>/dev/null || echo "000")
    if [ "$code" != "200" ]; then
        echo -e "[FAIL] HTTP request to $url returned $code (expected 200)" >&2
        return 1
    fi
    return 0
}

assert_http_response() {
    local url="$1"
    local pattern="$2"
    if ! curl -sf -m 15 "$url" | grep -q "$pattern"; then
        echo -e "[FAIL] Response from $url did not match pattern '$pattern'" >&2
        return 1
    fi
    return 0
}

assert_file_contains() {
    local file="$1"
    local pattern="$2"
    if ! grep -q "$pattern" "$file"; then
        echo -e "[FAIL] File $file does not contain '$pattern'" >&2
        return 1
    fi
    return 0
}

assert_no_latest_images() {
    local dir="$1"
    local count
    count=$(grep -rn "image:.*:latest" "$dir" 2>/dev/null | wc -l || echo 0)
    if [ "$count" -gt 0 ]; then
        echo -e "[FAIL] Found $count unpinned :latest image tags in $dir" >&2
        return 1
    fi
    return 0
}
