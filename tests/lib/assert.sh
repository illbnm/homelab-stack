#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Test Assertion Library
# =============================================================================
set -euo pipefail

# Colors
_RED='\033[0;31m'; _GREEN='\033[0;32m'; _YELLOW='\033[1;33m'; _NC='\033[0m'
_BOLD='\033[1m'

# Counters
_TESTS_RUN=0; _TESTS_PASSED=0; _TESTS_FAILED=0; _TESTS_SKIPPED=0
_CURRENT_TEST=""; _FAILED_TESTS=()

# ---------------------------------------------------------------------------
# Core assertions
# ---------------------------------------------------------------------------

assert_eq() {
    local actual="$1" expected="$2" msg="${3:-Values should be equal}"
    _TESTS_RUN=$((_TESTS_RUN + 1))
    if [[ "$actual" == "$expected" ]]; then
        _TESTS_PASSED=$((_TESTS_PASSED + 1))
        echo -e "  ${_GREEN}✓${_NC} $_CURRENT_TEST: $msg"
    else
        _TESTS_FAILED=$((_TESTS_FAILED + 1))
        _FAILED_TESTS+=("$_CURRENT_TEST")
        echo -e "  ${_RED}✗${_NC} $_CURRENT_TEST: $msg"
        echo -e "    expected: '$expected'"
        echo -e "    actual:   '$actual'"
    fi
}

assert_not_eq() {
    local actual="$1" expected="$2" msg="${3:-Values should differ}"
    _TESTS_RUN=$((_TESTS_RUN + 1))
    if [[ "$actual" != "$expected" ]]; then
        _TESTS_PASSED=$((_TESTS_PASSED + 1))
        echo -e "  ${_GREEN}✓${_NC} $_CURRENT_TEST: $msg"
    else
        _TESTS_FAILED=$((_TESTS_FAILED + 1))
        _FAILED_TESTS+=("$_CURRENT_TEST")
        echo -e "  ${_RED}✗${_NC} $_CURRENT_TEST: $msg"
    fi
}

assert_contains() {
    local haystack="$1" needle="$2" msg="${3:-Should contain substring}"
    _TESTS_RUN=$((_TESTS_RUN + 1))
    if [[ "$haystack" == *"$needle"* ]]; then
        _TESTS_PASSED=$((_TESTS_PASSED + 1))
        echo -e "  ${_GREEN}✓${_NC} $_CURRENT_TEST: $msg"
    else
        _TESTS_FAILED=$((_TESTS_FAILED + 1))
        _FAILED_TESTS+=("$_CURRENT_TEST")
        echo -e "  ${_RED}✗${_NC} $_CURRENT_TEST: $msg"
        echo -e "    '$haystack' does not contain '$needle'"
    fi
}

assert_exit_code() {
    local expected_code="$1"; shift
    local cmd="$*"
    _TESTS_RUN=$((_TESTS_RUN + 1))
    local actual_code=0
    eval "$cmd" >/dev/null 2>&1 || actual_code=$?
    if [[ "$actual_code" -eq "$expected_code" ]]; then
        _TESTS_PASSED=$((_TESTS_PASSED + 1))
        echo -e "  ${_GREEN}✓${_NC} $_CURRENT_TEST: exit code $expected_code"
    else
        _TESTS_FAILED=$((_TESTS_FAILED + 1))
        _FAILED_TESTS+=("$_CURRENT_TEST")
        echo -e "  ${_RED}✗${_NC} $_CURRENT_TEST: expected exit $expected_code, got $actual_code"
        echo -e "    command: $cmd"
    fi
}

# ---------------------------------------------------------------------------
# Docker assertions
# ---------------------------------------------------------------------------

assert_container_running() {
    local name="$1"
    _TESTS_RUN=$((_TESTS_RUN + 1))
    local state
    state=$(docker inspect -f '{{.State.Running}}' "$name" 2>/dev/null || echo "false")
    if [[ "$state" == "true" ]]; then
        _TESTS_PASSED=$((_TESTS_PASSED + 1))
        echo -e "  ${_GREEN}✓${_NC} $_CURRENT_TEST: container '$name' is running"
    else
        _TESTS_FAILED=$((_TESTS_FAILED + 1))
        _FAILED_TESTS+=("$_CURRENT_TEST")
        echo -e "  ${_RED}✗${_NC} $_CURRENT_TEST: container '$name' is NOT running"
    fi
}

assert_container_healthy() {
    local name="$1"
    _TESTS_RUN=$((_TESTS_RUN + 1))
    local health
    health=$(docker inspect -f '{{.State.Health.Status}}' "$name" 2>/dev/null || echo "none")
    if [[ "$health" == "healthy" ]]; then
        _TESTS_PASSED=$((_TESTS_PASSED + 1))
        echo -e "  ${_GREEN}✓${_NC} $_CURRENT_TEST: container '$name' is healthy"
    elif [[ "$health" == "none" ]]; then
        _TESTS_SKIPPED=$((_TESTS_SKIPPED + 1))
        echo -e "  ${_YELLOW}⊘${_NC} $_CURRENT_TEST: container '$name' has no healthcheck (skipped)"
    else
        _TESTS_FAILED=$((_TESTS_FAILED + 1))
        _FAILED_TESTS+=("$_CURRENT_TEST")
        echo -e "  ${_RED}✗${_NC} $_CURRENT_TEST: container '$name' health='$health'"
    fi
}

assert_container_restarted() {
    local name="$1" max_restarts="${2:-5}"
    _TESTS_RUN=$((_TESTS_RUN + 1))
    local restarts
    restarts=$(docker inspect -f '{{.RestartCount}}' "$name" 2>/dev/null || echo "0")
    if [[ "$restarts" -le "$max_restarts" ]]; then
        _TESTS_PASSED=$((_TESTS_PASSED + 1))
        echo -e "  ${_GREEN}✓${_NC} $_CURRENT_TEST: container '$name' restarts=$restarts (≤$max_restarts)"
    else
        _TESTS_FAILED=$((_TESTS_FAILED + 1))
        _FAILED_TESTS+=("$_CURRENT_TEST")
        echo -e "  ${_RED}✗${_NC} $_CURRENT_TEST: container '$name' too many restarts ($restarts)"
    fi
}

# ---------------------------------------------------------------------------
# HTTP assertions
# ---------------------------------------------------------------------------

assert_http_200() {
    local url="$1" timeout="${2:-10}"
    _TESTS_RUN=$((_TESTS_RUN + 1))
    local code
    code=$(curl -sf -o /dev/null -w '%{http_code}' --max-time "$timeout" "$url" 2>/dev/null || echo "000")
    if [[ "$code" -ge 200 && "$code" -lt 400 ]]; then
        _TESTS_PASSED=$((_TESTS_PASSED + 1))
        echo -e "  ${_GREEN}✓${_NC} $_CURRENT_TEST: HTTP $code — $url"
    else
        _TESTS_FAILED=$((_TESTS_FAILED + 1))
        _FAILED_TESTS+=("$_CURRENT_TEST")
        echo -e "  ${_RED}✗${_NC} $_CURRENT_TEST: HTTP $code — $url"
    fi
}

assert_http_status() {
    local url="$1" expected="$2" timeout="${3:-10}"
    _TESTS_RUN=$((_TESTS_RUN + 1))
    local code
    code=$(curl -sf -o /dev/null -w '%{http_code}' --max-time "$timeout" "$url" 2>/dev/null || echo "000")
    if [[ "$code" == "$expected" ]]; then
        _TESTS_PASSED=$((_TESTS_PASSED + 1))
        echo -e "  ${_GREEN}✓${_NC} $_CURRENT_TEST: HTTP $code — $url"
    else
        _TESTS_FAILED=$((_TESTS_FAILED + 1))
        _FAILED_TESTS+=("$_CURRENT_TEST")
        echo -e "  ${_RED}✗${_NC} $_CURRENT_TEST: expected HTTP $expected, got $code — $url"
    fi
}

assert_http_contains() {
    local url="$1" needle="$2" timeout="${3:-10}"
    _TESTS_RUN=$((_TESTS_RUN + 1))
    local body
    body=$(curl -sf --max-time "$timeout" "$url" 2>/dev/null || echo "")
    if [[ "$body" == *"$needle"* ]]; then
        _TESTS_PASSED=$((_TESTS_PASSED + 1))
        echo -e "  ${_GREEN}✓${_NC} $_CURRENT_TEST: response contains '$needle'"
    else
        _TESTS_FAILED=$((_TESTS_FAILED + 1))
        _FAILED_TESTS+=("$_CURRENT_TEST")
        echo -e "  ${_RED}✗${_NC} $_CURRENT_TEST: response does not contain '$needle'"
    fi
}

# ---------------------------------------------------------------------------
# Config assertions
# ---------------------------------------------------------------------------

assert_file_exists() {
    local path="$1"
    _TESTS_RUN=$((_TESTS_RUN + 1))
    if [[ -f "$path" ]]; then
        _TESTS_PASSED=$((_TESTS_PASSED + 1))
        echo -e "  ${_GREEN}✓${_NC} $_CURRENT_TEST: file exists — $path"
    else
        _TESTS_FAILED=$((_TESTS_FAILED + 1))
        _FAILED_TESTS+=("$_CURRENT_TEST")
        echo -e "  ${_RED}✗${_NC} $_CURRENT_TEST: file missing — $path"
    fi
}

assert_dir_exists() {
    local path="$1"
    _TESTS_RUN=$((_TESTS_RUN + 1))
    if [[ -d "$path" ]]; then
        _TESTS_PASSED=$((_TESTS_PASSED + 1))
        echo -e "  ${_GREEN}✓${_NC} $_CURRENT_TEST: dir exists — $path"
    else
        _TESTS_FAILED=$((_TESTS_FAILED + 1))
        _FAILED_TESTS+=("$_CURRENT_TEST")
        echo -e "  ${_RED}✗${_NC} $_CURRENT_TEST: dir missing — $path"
    fi
}

assert_env_var_set() {
    local var="$1"
    _TESTS_RUN=$((_TESTS_RUN + 1))
    if [[ -n "${!var:-}" ]]; then
        _TESTS_PASSED=$((_TESTS_PASSED + 1))
        echo -e "  ${_GREEN}✓${_NC} $_CURRENT_TEST: \$$var is set"
    else
        _TESTS_FAILED=$((_TESTS_FAILED + 1))
        _FAILED_TESTS+=("$_CURRENT_TEST")
        echo -e "  ${_RED}✗${_NC} $_CURRENT_TEST: \$$var is not set"
    fi
}

# ---------------------------------------------------------------------------
# Test lifecycle
# ---------------------------------------------------------------------------

describe() {
    echo -e "\n${_BOLD}━━━ $* ━━━${_NC}"
}

it() {
    _CURRENT_TEST="$*"
}

skip() {
    _TESTS_RUN=$((_TESTS_RUN + 1))
    _TESTS_SKIPPED=$((_TESTS_SKIPPED + 1))
    echo -e "  ${_YELLOW}⊘${_NC} $_CURRENT_TEST: skipped — $*"
}
