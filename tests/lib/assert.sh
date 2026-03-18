#!/usr/bin/env bash
# assert.sh - Assertion library for homelab-stack integration tests
# Copyright (c) 2026 homelab-stack contributors
# SPDX-License-Identifier: MIT

# Track assertion counts
_ASSERT_PASSED=0
_ASSERT_FAILED=0
_ASSERT_SKIPPED=0
_CURRENT_TEST=""

# Colors
readonly _C_RED='\033[0;31m'
readonly _C_GREEN='\033[0;32m'
readonly _C_YELLOW='\033[0;33m'
readonly _C_CYAN='\033[0;36m'
readonly _C_RESET='\033[0m'

# Internal: record a pass
_assert_pass() {
    local msg="$1"
    _ASSERT_PASSED=$((_ASSERT_PASSED + 1))
    echo -e "  ${_C_GREEN}✓ PASS${_C_RESET} ${msg}"
    report_record_test "$_CURRENT_TEST" "pass" "$msg"
}

# Internal: record a failure
_assert_fail() {
    local msg="$1"
    local detail="$2"
    _ASSERT_FAILED=$((_ASSERT_FAILED + 1))
    echo -e "  ${_C_RED}✗ FAIL${_C_RESET} ${msg}"
    [ -n "$detail" ] && echo -e "         ${_C_RED}→ ${detail}${_C_RESET}"
    report_record_test "$_CURRENT_TEST" "fail" "$msg" "$detail"
}

# Internal: record a skip
_assert_skip() {
    local msg="$1"
    local detail="$2"
    _ASSERT_SKIPPED=$((_ASSERT_SKIPPED + 1))
    echo -e "  ${_C_YELLOW}⊘ SKIP${_C_RESET} ${msg}"
    [ -n "$detail" ] && echo -e "         ${_C_YELLOW}→ ${detail}${_C_RESET}"
    report_record_test "$_CURRENT_TEST" "skip" "$msg" "$detail"
}

# Set current test name for reporting
assert_set_test() {
    _CURRENT_TEST="$1"
}

# Assert two values are equal
assert_eq() {
    local actual="$1" expected="$2" msg="${3:-values should be equal}"
    if [ "$actual" = "$expected" ]; then
        _assert_pass "$msg"
    else
        _assert_fail "$msg" "expected='${expected}', actual='${actual}'"
    fi
}

# Assert two values are not equal
assert_ne() {
    local a="$1" b="$2" msg="${3:-values should not be equal}"
    if [ "$a" != "$b" ]; then
        _assert_pass "$msg"
    else
        _assert_fail "$msg" "both values are '${a}'"
    fi
}

# Assert haystack contains needle
assert_contains() {
    local haystack="$1" needle="$2" msg="${3:-should contain substring}"
    if [[ "$haystack" == *"$needle"* ]]; then
        _assert_pass "$msg"
    else
        _assert_fail "$msg" "'${haystack}' does not contain '${needle}'"
    fi
}

# Assert command exits with expected code
assert_exit_code() {
    local expected="$1" shift
    local cmd="$*"
    local output exit_code
    output=$(eval "$cmd" 2>&1)
    exit_code=$?
    if [ "$exit_code" -eq "$expected" ]; then
        _assert_pass "exit code ${expected} for: ${cmd}"
    else
        _assert_fail "exit code ${expected} for: ${cmd}" "got exit code ${exit_code}, output: ${output:0:200}"
    fi
}

# Assert a docker container is running
assert_container_running() {
    local container="$1"
    local msg="${2:-container ${container} should be running}"
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$container"; then
        _assert_pass "$msg"
    else
        _assert_fail "$msg" "container '${container}' not found in running containers"
    fi
}

# Assert a docker container is healthy
assert_container_healthy() {
    local container="$1"
    local msg="${2:-container ${container} should be healthy}"
    local health
    health=$(docker inspect --format '{{.State.Health.Status}}' "$container" 2>/dev/null) || true
    if [ "$health" = "healthy" ]; then
        _assert_pass "$msg"
    elif [ "$health" = "" ]; then
        _assert_skip "$msg" "no healthcheck configured for '${container}'"
    else
        _assert_fail "$msg" "health status: '${health}'"
    fi
}

# Assert HTTP response is 200
assert_http_200() {
    local url="$1"
    local msg="${2:-HTTP 200 for ${url}}"
    assert_http_status "$url" 200 "$msg"
}

# Assert HTTP response matches expected status
assert_http_status() {
    local url="$1" expected="$2"
    local msg="${3:-HTTP ${expected} for ${url}}"
    local status
    status=$(curl -sf -o /dev/null -w '%{http_code}' --max-time 10 "$url" 2>/dev/null) || true
    if [ "$status" = "$expected" ]; then
        _assert_pass "$msg"
    else
        _assert_fail "$msg" "got HTTP ${status}"
    fi
}

# Assert JSON value at jq path matches expected
assert_json_value() {
    local json="$1" jq_path="$2" expected="$3"
    local msg="${4:-JSON value at ${jq_path} should be '${expected}'}"
    if ! command -v jq &>/dev/null; then
        _assert_skip "$msg" "jq not available"
        return
    fi
    local actual
    actual=$(echo "$json" | jq -r "$jq_path" 2>/dev/null) || true
    if [ "$actual" = "$expected" ]; then
        _assert_pass "$msg"
    else
        _assert_fail "$msg" "expected='${expected}', actual='${actual}'"
    fi
}

# Assert JSON key exists
assert_json_key_exists() {
    local json="$1" jq_path="$2"
    local msg="${3:-JSON key ${jq_path} should exist}"
    if ! command -v jq &>/dev/null; then
        _assert_skip "$msg" "jq not available"
        return
    fi
    if echo "$json" | jq -e "$jq_path" &>/dev/null; then
        _assert_pass "$msg"
    else
        _assert_fail "$msg" "key '${jq_path}' not found in JSON"
    fi
}

# Assert JSON has no error keys
assert_no_errors() {
    local json="$1"
    local msg="${2:-JSON should contain no errors}"
    if ! command -v jq &>/dev/null; then
        _assert_skip "$msg" "jq not available"
        return
    fi
    local has_error
    has_error=$(echo "$json" | jq -e 'has("error") or has("errors") or has("message")' 2>/dev/null) || true
    if [ "$has_error" = "true" ]; then
        _assert_fail "$msg" "error found in JSON"
    else
        _assert_pass "$msg"
    fi
}

# Assert port is open on host
assert_port_open() {
    local host="$1" port="$2"
    local msg="${3:-port ${port} on ${host} should be open}"
    if timeout 3 bash -c "echo >/dev/tcp/${host}/${port}" 2>/dev/null; then
        _assert_pass "$msg"
    else
        _assert_fail "$msg" "connection refused or timed out"
    fi
}

# Assert service exists in compose file
assert_service_exists() {
    local compose_file="$1" service="$2"
    local msg="${3:-service '${service}' should exist in ${compose_file}}"
    if [ ! -f "$compose_file" ]; then
        _assert_skip "$msg" "compose file not found: ${compose_file}"
        return
    fi
    if grep -q "^  ${service}:" "$compose_file" 2>/dev/null; then
        _assert_pass "$msg"
    else
        _assert_fail "$msg" "service '${service}' not found in compose file"
    fi
}

# Assert file exists
assert_file_exists() {
    local file="$1"
    local msg="${2:-file '${file}' should exist}"
    if [ -f "$file" ]; then
        _assert_pass "$msg"
    else
        _assert_fail "$msg" "file not found"
    fi
}

# Assert directory exists
assert_dir_exists() {
    local dir="$1"
    local msg="${2:-directory '${dir}' should exist}"
    if [ -d "$dir" ]; then
        _assert_pass "$msg"
    else
        _assert_fail "$msg" "directory not found"
    fi
}

# Reset assertion counters
assert_reset() {
    _ASSERT_PASSED=0
    _ASSERT_FAILED=0
    _ASSERT_SKIPPED=0
}

# Print assertion summary
assert_summary() {
    local total=$((_ASSERT_PASSED + _ASSERT_FAILED + _ASSERT_SKIPPED))
    echo ""
    echo -e "${_C_CYAN}══════════════════════════════════════════${_C_RESET}"
    echo -e "  Total: ${total}  ${_C_GREEN}Pass: ${_ASSERT_PASSED}${_C_RESET}  ${_C_RED}Fail: ${_ASSERT_FAILED}${_C_RESET}  ${_C_YELLOW}Skip: ${_ASSERT_SKIPPED}${_C_RESET}"
    echo -e "${_C_CYAN}══════════════════════════════════════════${_C_RESET}"
    [ "$_ASSERT_FAILED" -gt 0 ] && return 1
    return 0
}
