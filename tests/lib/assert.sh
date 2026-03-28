#!/usr/bin/env bash
# =============================================================================
# Assertion Library — HomeLab Stack Integration Tests
# =============================================================================

# Track test results
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0
CURRENT_TEST=""

# ---- Core Assert Functions ----

assert_eq() {
    local actual="$1"
    local expected="$2"
    local msg="${3:-}"
    if [[ "$actual" == "$expected" ]]; then
        _pass "$msg (expected: $expected, got: $actual)"
    else
        _fail "$msg (expected: $expected, got: $actual)"
    fi
}

assert_not_eq() {
    local actual="$1"
    local expected="$2"
    local msg="${3:-}"
    if [[ "$actual" != "$expected" ]]; then
        _pass "$msg (not equal: $actual)"
    else
        _fail "$msg (should not equal: $expected)"
    fi
}

assert_not_empty() {
    local value="$1"
    local msg="${2:-}"
    if [[ -n "$value" ]]; then
        _pass "$msg (value: $value)"
    else
        _fail "$msg (value is empty)"
    fi
}

assert_exit_code() {
    local actual_code="$1"
    local expected_code="${2:-0}"
    local msg="${3:-}"
    if [[ "$actual_code" == "$expected_code" ]]; then
        _pass "$msg (exit code: $actual_code)"
    else
        _fail "$msg (expected exit: $expected_code, got: $actual_code)"
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local msg="${3:-}"
    if [[ "$haystack" == *"$needle"* ]]; then
        _pass "$msg (found: $needle)"
    else
        _fail "$msg (did not find: $needle)"
    fi
}

# ---- Docker-specific Asserts ----

assert_container_running() {
    local name="$1"
    local msg="${2:-Container $name running}"
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${name}$"; then
        _pass "$msg"
    else
        _fail "$msg (container not running)"
    fi
}

assert_container_healthy() {
    local name="$1"
    local timeout="${2:-60}"
    local msg="Container $name healthy"

    local health status elapsed=0 interval=2
    while [[ $elapsed -lt $timeout ]]; do
        health=$(docker inspect --format '{{.State.Health.Status}}' "$name" 2>/dev/null || echo 'no-healthcheck')
        status=$(docker inspect --format '{{.State.Status}}' "$name" 2>/dev/null || echo 'missing')

        if [[ "$status" != "running" ]]; then
            _fail "$msg (container not running, status: $status)"
            return 1
        fi

        if [[ "$health" == "healthy" ]] || [[ "$health" == "no-healthcheck" ]]; then
            _pass "$msg (health: $health)"
            return 0
        fi

        sleep $interval
        elapsed=$((elapsed + interval))
    done

    _fail "$msg (timeout after ${timeout}s, health: $health)"
    return 1
}

assert_container_not_running() {
    local name="$1"
    local msg="${2:-Container $name not running}"
    if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${name}$"; then
        _pass "$msg"
    else
        _fail "$msg (container is still running)"
    fi
}

# ---- HTTP Asserts ----

assert_http_200() {
    local url="$1"
    local timeout="${2:-30}"
    local msg="${3:-HTTP 200 at $url}"

    local code
    code=$(curl -sf -o /dev/null -w '%{http_code}' \
        --connect-timeout 5 --max-time "$timeout" \
        "$url" 2>/dev/null || echo 000)

    if [[ "$code" =~ ^[23] ]]; then
        _pass "$msg (HTTP $code)"
    else
        _fail "$msg (expected 2xx/3xx, got HTTP $code)"
    fi
}

assert_http_not_200() {
    local url="$1"
    local timeout="${2:-30}"
    local msg="${3:-Not HTTP 200 at $url}"

    local code
    code=$(curl -sf -o /dev/null -w '%{http_code}' \
        --connect-timeout 5 --max-time "$timeout" \
        "$url" 2>/dev/null || echo 000)

    if [[ ! "$code" =~ ^[23] ]]; then
        _pass "$msg (HTTP $code)"
    else
        _fail "$msg (expected non-2xx, got HTTP $code)"
    fi
}

assert_http_response() {
    local url="$1"
    local pattern="$2"
    local timeout="${3:-30}"
    local msg="Response matches: $pattern"

    local response
    response=$(curl -sf --connect-timeout 5 --max-time "$timeout" \
        "$url" 2>/dev/null || echo "")

    if echo "$response" | grep -q "$pattern"; then
        _pass "$msg (at $url)"
    else
        _fail "$msg (at $url, pattern not found)"
    fi
}

# ---- JSON Asserts ----

assert_json_value() {
    local json="$1"
    local jq_path="$2"
    local expected="$3"
    local msg="${4:-JSON value at $jq_path}"

    if command -v jq &>/dev/null; then
        local actual
        actual=$(echo "$json" | jq -r "$jq_path" 2>/dev/null || echo "__JQ_ERROR__")
        if [[ "$actual" == "$expected" ]]; then
            _pass "$msg (expected: $expected, got: $actual)"
        else
            _fail "$msg (expected: $expected, got: $actual)"
        fi
    else
        # Fallback: grep-based check
        if echo "$json" | grep -q "$expected"; then
            _pass "$msg (found: $expected)"
        else
            _fail "$msg (did not find: $expected)"
        fi
    fi
}

assert_json_key_exists() {
    local json="$1"
    local jq_path="$2"
    local msg="${3:-JSON key exists at $jq_path}"

    if command -v jq &>/dev/null; then
        local result
        result=$(echo "$json" | jq -r "$jq_path" 2>/dev/null || echo "__JQ_ERROR__")
        if [[ "$result" != "__JQ_ERROR__" ]] && [[ "$result" != "null" ]]; then
            _pass "$msg (value: $result)"
        else
            _fail "$msg (key path not found or null)"
        fi
    else
        _skip "jq not available, skipping JSON key check"
    fi
}

assert_no_errors() {
    local json="$1"
    local msg="${2:-No errors in response}"
    # Check for common error patterns
    if echo "$json" | grep -qi 'error\|exception\|traceback'; then
        _fail "$msg (found error in response)"
    else
        _pass "$msg"
    fi
}

# ---- File Asserts ----

assert_file_exists() {
    local file="$1"
    local msg="${2:-File exists: $file}"
    if [[ -f "$file" ]]; then
        _pass "$msg"
    else
        _fail "$msg (file not found)"
    fi
}

assert_file_contains() {
    local file="$1"
    local pattern="$2"
    local msg="${3:-File contains: $pattern}"

    if [[ ! -f "$file" ]]; then
        _fail "$msg (file not found: $file)"
        return 1
    fi

    if grep -q "$pattern" "$file" 2>/dev/null; then
        _pass "$msg"
    else
        _fail "$msg (pattern not found in $file)"
    fi
}

assert_no_latest_images() {
    local dir="$1"
    local msg="${2:-No :latest image tags in $dir}"
    local count
    count=$(grep -r 'image:.*:latest' "$dir" 2>/dev/null | wc -l)
    if [[ "$count" -eq 0 ]]; then
        _pass "$msg"
    else
        _fail "$msg (found $count occurrences of :latest)"
    fi
}

# ---- Network Asserts ----

assert_port_open() {
    local host="$1"
    local port="$2"
    local timeout="${3:-10}"
    local msg="${4:-Port $port open at $host}"

    if command -v nc &>/dev/null; then
        if nc -z -w"$timeout" "$host" "$port" 2>/dev/null; then
            _pass "$msg"
        else
            _fail "$msg (port not reachable)"
        fi
    elif command -v timeout &>/dev/null; then
        if timeout "$timeout" bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null; then
            _pass "$msg"
        else
            _fail "$msg (port not reachable)"
        fi
    else
        _skip "netcat not available, skipping port check"
    fi
}

# ---- Internal helpers ----

_pass() {
    local msg="$1"
    echo -e "  ${GREEN}✓${NC} $msg"
    ((TESTS_PASSED++))
}

_fail() {
    local msg="$1"
    echo -e "  ${RED}✗${NC} $msg"
    ((TESTS_FAILED++))
}

_skip() {
    local msg="$1"
    echo -e "  ${YELLOW}~${NC} $msg (skipped)"
    ((TESTS_SKIPPED++))
}

print_summary() {
    local duration="${1:-0}"
    echo ""
    echo -e "${BOLD}========================================${NC}"
    echo -e "  Results: ${GREEN}$TESTS_PASSED passed${NC} | ${RED}$TESTS_FAILED failed${NC} | ${YELLOW}$TESTS_SKIPPED skipped${NC}"
    echo -e "  Duration: ${duration}s"
    echo -e "${BOLD}========================================${NC}"
}

reset_counters() {
    TESTS_PASSED=0
    TESTS_FAILED=0
    TESTS_SKIPPED=0
}
