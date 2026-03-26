#!/usr/bin/env bash
# =============================================================================
# assert.sh - 断言库 for HomeLab Stack Integration Tests
# =============================================================================

# 颜色定义
export COLOR_RED='\033[0;31m'
export COLOR_GREEN='\033[0;32m'
export COLOR_YELLOW='\033[0;33m'
export COLOR_BLUE='\033[0;34m'
export COLOR_MAGENTA='\033[0;35m'
export COLOR_CYAN='\033[0;36m'
export COLOR_BOLD='\033[1m'
export COLOR_RESET='\033[0m'

# 测试统计
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0
TEST_RESULTS=()

# -----------------------------------------------------------------------------
# 基础断言函数
# -----------------------------------------------------------------------------
assert_eq() {
    local actual="$1"
    local expected="$2"
    local msg="${3:-Expected '$expected' but got '$actual'}"
    if [[ "$actual" == "$expected" ]]; then
        _assert_pass "$msg"
        return 0
    else
        _assert_fail "$msg" "actual=$actual" "expected=$expected"
        return 1
    fi
}

assert_not_empty() {
    local value="$1"
    local msg="${2:-Value should not be empty}"
    if [[ -n "$value" ]]; then
        _assert_pass "$msg"
        return 0
    else
        _assert_fail "$msg" "value is empty"
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local msg="${3:-'$haystack' should contain '$needle'}"
    if [[ "$haystack" == *"$needle"* ]]; then
        _assert_pass "$msg"
        return 0
    else
        _assert_fail "$msg" "haystack='$haystack'" "needle='$needle'"
        return 1
    fi
}

assert_exit_code() {
    local actual_code="$1"
    local expected_code="${2:-0}"
    local msg="${3:-Exit code should be $expected_code but was $actual_code}"
    if [[ "$actual_code" == "$expected_code" ]]; then
        _assert_pass "$msg"
        return 0
    else
        _assert_fail "$msg" "actual_exit_code=$actual_code" "expected_exit_code=$expected_code"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Docker 容器相关断言
# -----------------------------------------------------------------------------
assert_container_running() {
    local container_name="$1"
    local msg="${2:-Container '$container_name' should be running}"
    local state
    state=$(docker inspect -f '{{.State.Running}}' "$container_name" 2>/dev/null)
    if [[ "$state" == "true" ]]; then
        _assert_pass "$msg"
        return 0
    else
        _assert_fail "$msg" "container=$container_name" "state=$state"
        return 1
    fi
}

assert_container_healthy() {
    local container_name="$1"
    local msg="${2:-Container '$container_name' should be healthy}"
    local health_status
    health_status=$(docker inspect -f '{{.State.Health.Status}}' "$container_name" 2>/dev/null)
    if [[ "$health_status" == "<no value>" ]] || [[ -z "$health_status" ]]; then
        local running
        running=$(docker inspect -f '{{.State.Running}}' "$container_name" 2>/dev/null)
        if [[ "$running" == "true" ]]; then
            _assert_pass "${msg} (no health check, running is ok)"
            return 0
        else
            _assert_fail "$msg" "container=$container_name" "running=$running"
            return 1
        fi
    elif [[ "$health_status" == "healthy" ]]; then
        _assert_pass "$msg"
        return 0
    else
        _assert_fail "$msg" "container=$container_name" "health_status=$health_status"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# HTTP 相关断言
# -----------------------------------------------------------------------------
assert_http_200() {
    local url="$1"
    local timeout="${2:-30}"
    local msg="${3:-HTTP GET '$url' should return 200}"
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$timeout" "$url" 2>/dev/null)
    if [[ "$http_code" == "200" ]]; then
        _assert_pass "$msg"
        return 0
    else
        _assert_fail "$msg" "url=$url" "http_code=$http_code" "timeout=${timeout}s"
        return 1
    fi
}

assert_http_status() {
    local url="$1"
    local expected_status="$2"
    local timeout="${3:-30}"
    local msg="${4:-HTTP GET '$url' should return $expected_status}"
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$timeout" "$url" 2>/dev/null)
    if [[ "$http_code" == "$expected_status" ]]; then
        _assert_pass "$msg"
        return 0
    else
        _assert_fail "$msg" "url=$url" "http_code=$http_code" "expected=$expected_status"
        return 1
    fi
}

assert_http_contains() {
    local url="$1"
    local expected_content="$2"
    local timeout="${3:-30}"
    local msg="${4:-HTTP GET '$url' should contain '$expected_content'}"
    local response
    response=$(curl -s --max-time "$timeout" "$url" 2>/dev/null)
    if [[ "$response" == *"$expected_content"* ]]; then
        _assert_pass "$msg"
        return 0
    else
        _assert_fail "$msg" "url=$url" "expected_content='$expected_content'"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# JSON 相关断言
# -----------------------------------------------------------------------------
assert_json_value() {
    local json="$1"
    local jq_path="$2"
    local expected="$3"
    local msg="${4:-JSON value at '$jq_path' should be '$expected'}"
    if ! command -v jq &> /dev/null; then
        _assert_skip "jq not installed, cannot parse JSON"
        return 2
    fi
    local actual
    actual=$(echo "$json" | jq -r "$jq_path" 2>/dev/null)
    if [[ "$actual" == "$expected" ]]; then
        _assert_pass "$msg"
        return 0
    else
        _assert_fail "$msg" "jq_path=$jq_path" "actual='$actual'" "expected='$expected'"
        return 1
    fi
}

assert_json_value_from_url() {
    local url="$1"
    local jq_path="$2"
    local expected="$3"
    local timeout="${4:-30}"
    local msg="${5:-JSON from '$url' at '$jq_path' should be '$expected'}"
    if ! command -v jq &> /dev/null; then
        _assert_skip "jq not installed, cannot parse JSON"
        return 2
    fi
    local json
    json=$(curl -s --max-time "$timeout" "$url" 2>/dev/null)
    if [[ -z "$json" ]]; then
        _assert_fail "$msg" "url=$url" "error=empty response"
        return 1
    fi
    local actual
    actual=$(echo "$json" | jq -r "$jq_path" 2>/dev/null)
    if [[ "$actual" == "$expected" ]]; then
        _assert_pass "$msg"
        return 0
    else
        _assert_fail "$msg" "url=$url" "jq_path=$jq_path" "actual='$actual'" "expected='$expected'"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Docker Compose 相关断言
# -----------------------------------------------------------------------------
assert_compose_service_running() {
    local compose_file="$1"
    local service_name="$2"
    local msg="${3:-Service '$service_name' in '$compose_file' should be running}"
    local state
    state=$(docker compose -f "$compose_file" ps --status running --format json 2>/dev/null | jq -r ".[] | select(.Service == \"$service_name\") | .State" 2>/dev/null)
    if [[ "$state" == "running" ]]; then
        _assert_pass "$msg"
        return 0
    else
        _assert_fail "$msg" "compose_file=$compose_file" "service=$service_name" "state=$state"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# 辅助函数
# -----------------------------------------------------------------------------
get_container_ip() {
    local container_name="$1"
    docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$container_name" 2>/dev/null
}

get_container_port() {
    local container_name="$1"
    local internal_port="$2"
    docker inspect -f "{{range \$k, \$v := .NetworkSettings.Ports}}{\$k}}:{{range \$v}}{{.HostPort}}{{end}}{{end}}" "$container_name" 2>/dev/null | grep "$internal_port" | cut -d: -f2
}

check_port() {
    local host="$1"
    local port="$2"
    local timeout="${3:-5}"
    if command -v nc &> /dev/null; then
        nc -z -w "$timeout" "$host" "$port" 2>/dev/null
        return $?
    elif command -v timeout &> /dev/null; then
        timeout "$timeout" bash -c "echo > /dev/tcp/$host/$port" 2>/dev/null
        return $?
    else
        curl -s -o /dev/null --max-time "$timeout" "http://$host:$port" 2>/dev/null
        return $?
    fi
}

containers_in_same_network() {
    local container1="$1"
    local container2="$2"
    local net1 net2
    net1=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.NetworkID}}{{end}}' "$container1" 2>/dev/null | head -1)
    net2=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.NetworkID}}{{end}}' "$container2" 2>/dev/null | head -1)
    [[ "$net1" == "$net2" ]] && [[ -n "$net1" ]]
}

wait_for_container() {
    local container_name="$1"
    local timeout="${2:-60}"
    local interval="${3:-2}"
    local elapsed=0
    while (( elapsed < timeout )); do
        local state
        state=$(docker inspect -f '{{.State.Running}}' "$container_name" 2>/dev/null)
        if [[ "$state" == "true" ]]; then
            return 0
        fi
        sleep "$interval"
        elapsed=$((elapsed + interval))
    done
    return 1
}

wait_for_http() {
    local url="$1"
    local timeout="${2:-60}"
    local interval="${3:-2}"
    local elapsed=0
    while (( elapsed < timeout )); do
        local http_code
        http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null)
        if [[ "$http_code" == "200" ]] || [[ "$http_code" == "301" ]] || [[ "$http_code" == "302" ]]; then
            return 0
        fi
        sleep "$interval"
        elapsed=$((elapsed + interval))
    done
    return 1
}

# -----------------------------------------------------------------------------
# 内部函数
# -----------------------------------------------------------------------------
_assert_pass() {
    local msg="$1"
    local extra="${2:-}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    TEST_RESULTS+=("{\"status\":\"PASS\",\"message\":\"$msg\"$extra}")
}

_assert_fail() {
    local msg="$1"
    local extra="${2:-}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    TEST_RESULTS+=("{\"status\":\"FAIL\",\"message\":\"$msg\"$extra}")
}

_assert_skip() {
    local msg="$1"
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
    TEST_RESULTS+=("{\"status\":\"SKIP\",\"message\":\"$msg\"}")
}

get_test_stats() {
    echo "{\"passed\":$TESTS_PASSED,\"failed\":$TESTS_FAILED,\"skipped\":$TESTS_SKIPPED,\"total\":$((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))}"
}

export -f assert_eq assert_not_empty assert_contains assert_exit_code
export -f assert_container_running assert_container_healthy
export -f assert_http_200 assert_http_status assert_http_contains
export -f assert_json_value assert_json_value_from_url
export -f assert_compose_service_running
export -f get_container_ip get_container_port check_port containers_in_same_network
export -f wait_for_container wait_for_http get_test_stats
