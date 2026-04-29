#!/usr/bin/env bash
set -euo pipefail

ASSERT_PASS=0
ASSERT_FAIL=0
ASSERT_SKIP=0
ASSERT_CURRENT_SUITE=""
ASSERT_CURRENT_TEST=""
ASSERT_START_TIME=0
ASSERT_TEST_START_TIME=0

_assert_reset() {
    ASSERT_PASS=0
    ASSERT_FAIL=0
    ASSERT_SKIP=0
    ASSERT_CURRENT_SUITE=""
    ASSERT_CURRENT_TEST=""
}

assert_suite() {
    ASSERT_CURRENT_SUITE="$1"
    ASSERT_CURRENT_TEST=""
    echo ""
    echo -e "\033[1m[$ASSERT_CURRENT_SUITE]\033[0m"
}

assert_test() {
    ASSERT_CURRENT_TEST="$1"
    ASSERT_TEST_START_TIME=${SECONDS}
}

_pass() {
    local duration=$(( SECONDS - ASSERT_TEST_START_TIME ))
    (( ASSERT_PASS++ )) || true
    echo -e "  ▶ $ASSERT_CURRENT_TEST \033[32m✅ PASS\033[0m (${duration}s)"
}

_fail() {
    local msg="$1"
    local duration=$(( SECONDS - ASSERT_TEST_START_TIME ))
    (( ASSERT_FAIL++ )) || true
    echo -e "  ▶ $ASSERT_CURRENT_TEST \033[31m❌ FAIL\033[0m (${duration}s)"
    echo -e "    \033[31m$msg\033[0m"
}

_skip() {
    local reason="${1:-skipped}"
    (( ASSERT_SKIP++ )) || true
    echo -e "  ▶ $ASSERT_CURRENT_TEST \033[33m⏭ SKIP\033[0m ($reason)"
}

assert_eq() {
    local actual="$1" expected="$2" msg="${3:-assert_eq failed}"
    if [[ "$actual" == "$expected" ]]; then
        _pass
    else
        _fail "$msg — expected: '$expected', got: '$actual'"
    fi
}

assert_not_empty() {
    local value="$1" msg="${2:-value is empty}"
    if [[ -n "$value" ]]; then
        _pass
    else
        _fail "$msg"
    fi
}

assert_exit_code() {
    local code="$1" msg="${2:-exit code mismatch}"
    if [[ "$code" -eq 0 ]]; then
        _pass
    else
        _fail "$msg — exit code: $code"
    fi
}

assert_container_running() {
    local name="$1"
    assert_test "container $name running"
    local state
    state=$(docker inspect -f '{{.State.Running}}' "$name" 2>/dev/null || echo "false")
    if [[ "$state" == "true" ]]; then
        _pass
    else
        _fail "container $name is not running (state: $state)"
    fi
}

assert_container_healthy() {
    local name="$1"
    local timeout="${2:-60}"
    assert_test "container $name healthy"
    local elapsed=0
    while (( elapsed < timeout )); do
        local health
        health=$(docker inspect -f '{{.State.Health.Status}}' "$name" 2>/dev/null || echo "unknown")
        if [[ "$health" == "healthy" ]]; then
            _pass
            return
        fi
        sleep 5
        (( elapsed += 5 )) || true
    done
    local health
    health=$(docker inspect -f '{{.State.Health.Status}}' "$name" 2>/dev/null || echo "unknown")
    _fail "container $name not healthy after ${timeout}s (status: $health)"
}

assert_http_200() {
    local url="$1" timeout="${2:-30}"
    assert_test "HTTP 200 $url"
    local code
    code=$(curl -sS -o /dev/null -w '%{http_code}' --max-time "$timeout" "$url" 2>/dev/null || echo "000")
    if [[ "$code" == "200" ]]; then
        _pass
    else
        _fail "Expected 200, got $code for $url"
    fi
}

assert_http_response() {
    local url="$1" pattern="$2"
    assert_test "HTTP response matches: $pattern"
    local body
    body=$(curl -sS --max-time 30 "$url" 2>/dev/null || echo "")
    if echo "$body" | grep -qE "$pattern"; then
        _pass
    else
        _fail "Response from $url does not match pattern: $pattern"
    fi
}

assert_json_value() {
    local json="$1" jq_path="$2" expected="$3"
    assert_test "JSON $jq_path == $expected"
    local actual
    actual=$(echo "$json" | jq -r "$jq_path" 2>/dev/null || echo "__JQ_ERROR__")
    if [[ "$actual" == "$expected" ]]; then
        _pass
    else
        _fail "JSON path $jq_path — expected: '$expected', got: '$actual'"
    fi
}

assert_json_key_exists() {
    local json="$1" jq_path="$2"
    assert_test "JSON key exists: $jq_path"
    local value
    value=$(echo "$json" | jq -r "$jq_path" 2>/dev/null || echo "__JQ_ERROR__")
    if [[ -n "$value" && "$value" != "null" && "$value" != "__JQ_ERROR__" ]]; then
        _pass
    else
        _fail "JSON key $jq_path does not exist or is null"
    fi
}

assert_no_errors() {
    local json="$1"
    assert_test "JSON has no .errors"
    local errors
    errors=$(echo "$json" | jq -r '.errors // empty' 2>/dev/null || echo "")
    if [[ -z "$errors" ]]; then
        _pass
    else
        _fail "JSON contains errors: $errors"
    fi
}

assert_file_contains() {
    local file="$1" pattern="$2"
    assert_test "file contains: $pattern"
    if grep -qE "$pattern" "$file" 2>/dev/null; then
        _pass
    else
        _fail "File $file does not contain pattern: $pattern"
    fi
}

assert_no_latest_images() {
    local dir="$1"
    assert_test "no :latest image tags in $dir"
    local count
    count=$(grep -r 'image:.*:latest' "$dir" --include='*.yml' --include='*.yaml' 2>/dev/null | wc -l || echo "0")
    count=${count// /}
    if [[ "$count" -eq 0 ]]; then
        _pass
    else
        _fail "Found $count services using :latest image tag"
    fi
}

assert_compose_valid() {
    local file="$1"
    assert_test "compose config valid: $file"
    local output
    if docker compose -f "$file" config --quiet 2>&1; then
        _pass
    else
        output=$(docker compose -f "$file" config 2>&1 | head -5)
        _fail "docker compose config failed for $file: $output"
    fi
}

assert_all_have_healthcheck() {
    local file="$1"
    assert_test "all services have healthcheck in $file"
    local services
    services=$(docker compose -f "$file" config --services 2>/dev/null || echo "")
    local missing=()
    for svc in $services; do
        local hc
        hc=$(docker compose -f "$file" config 2>/dev/null | jq -r ".services[\"$svc\"].healthcheck" 2>/dev/null || echo "null")
        if [[ -z "$hc" || "$hc" == "null" ]]; then
            missing+=("$svc")
        fi
    done
    if [[ ${#missing[@]} -eq 0 ]]; then
        _pass
    else
        _fail "Services missing healthcheck: ${missing[*]}"
    fi
}