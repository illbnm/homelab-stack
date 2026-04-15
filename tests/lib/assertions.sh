#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Test Assertion Library
# Provides reusable assertion functions for stack integration tests.
# Source this file from test scripts: source "$(dirname "$0")/lib/assertions.sh"
# =============================================================================

# --- Strict mode (caller can override) ---
set -uo pipefail

# --- Colors & Formatting ---
_RED='\033[0;31m'
_GREEN='\033[0;32m'
_YELLOW='\033[1;33m'
_BLUE='\033[0;34m'
_CYAN='\033[0;36m'
_BOLD='\033[1m'
_DIM='\033[2m'
_NC='\033[0m'

# --- Counters ---
TEST_PASSED=0
TEST_FAILED=0
TEST_SKIPPED=0
TEST_TOTAL=0
TEST_SUITE_NAME="${TEST_SUITE_NAME:-unnamed}"
TEST_START_TIME=$(date +%s)
JUNIT_ENTRIES=""
CURRENT_GROUP=""

# --- Output directory ---
RESULTS_DIR="${RESULTS_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/results}"
mkdir -p "$RESULTS_DIR"

# =============================================================================
# Logging helpers
# =============================================================================
_log_pass() {
    echo -e "  ${_GREEN}[PASS]${_NC} $*"
    ((TEST_PASSED++))
    ((TEST_TOTAL++))
    _junit_testcase "$*" "pass"
}

_log_fail() {
    echo -e "  ${_RED}[FAIL]${_NC} $*"
    ((TEST_FAILED++))
    ((TEST_TOTAL++))
    _junit_testcase "$*" "fail" "$*"
}

_log_skip() {
    echo -e "  ${_YELLOW}[SKIP]${_NC} $*"
    ((TEST_SKIPPED++))
    ((TEST_TOTAL++))
    _junit_testcase "$*" "skip" "$*"
}

log_group() {
    CURRENT_GROUP="$*"
    echo -e "\n${_BLUE}${_BOLD}=== $* ===${_NC}"
}

log_info() {
    echo -e "  ${_DIM}INFO:${_NC} $*"
}

log_warn() {
    echo -e "  ${_YELLOW}WARN:${_NC} $*"
}

# =============================================================================
# JUnit XML generation
# =============================================================================
_junit_escape() {
    local s="$1"
    s="${s//&/&amp;}"
    s="${s//</&lt;}"
    s="${s//>/&gt;}"
    s="${s//\"/&quot;}"
    s="${s//\'/&apos;}"
    echo "$s"
}

_junit_testcase() {
    local name="$1" status="$2" message="${3:-}"
    local classname
    classname=$(_junit_escape "${CURRENT_GROUP:-$TEST_SUITE_NAME}")
    name=$(_junit_escape "$name")
    message=$(_junit_escape "$message")

    local entry="    <testcase classname=\"${classname}\" name=\"${name}\" time=\"0\">"
    case "$status" in
        fail)
            entry+="<failure message=\"${message}\">Assertion failed: ${message}</failure>"
            ;;
        skip)
            entry+="<skipped message=\"${message}\"/>"
            ;;
    esac
    entry+="</testcase>"
    JUNIT_ENTRIES+="${entry}\n"
}

write_junit_report() {
    local elapsed=$(( $(date +%s) - TEST_START_TIME ))
    local outfile="${RESULTS_DIR}/${TEST_SUITE_NAME}.xml"
    cat > "$outfile" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="${TEST_SUITE_NAME}" tests="${TEST_TOTAL}" failures="${TEST_FAILED}" skipped="${TEST_SKIPPED}" time="${elapsed}">
$(echo -e "$JUNIT_ENTRIES")
</testsuite>
EOF
    echo -e "\n${_DIM}JUnit report: ${outfile}${_NC}"
}

# =============================================================================
# Summary
# =============================================================================
print_summary() {
    local elapsed=$(( $(date +%s) - TEST_START_TIME ))
    echo ""
    echo -e "${_BOLD}============================================${_NC}"
    echo -e "  Suite: ${_CYAN}${TEST_SUITE_NAME}${_NC} (${elapsed}s)"
    echo -e "  ${_GREEN}${TEST_PASSED} passed${_NC} | ${_RED}${TEST_FAILED} failed${_NC} | ${_YELLOW}${TEST_SKIPPED} skipped${_NC} | Total: ${TEST_TOTAL}"
    echo -e "${_BOLD}============================================${_NC}"
    write_junit_report
}

# =============================================================================
# Container assertions
# =============================================================================

# assert_container_running <name>
# Checks that a container with the given name is running.
assert_container_running() {
    local name="$1"
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${name}$"; then
        _log_pass "Container '${name}' is running"
        return 0
    else
        _log_fail "Container '${name}' is NOT running"
        return 1
    fi
}

# assert_container_not_running <name>
assert_container_not_running() {
    local name="$1"
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${name}$"; then
        _log_fail "Container '${name}' is running (expected stopped)"
        return 1
    else
        _log_pass "Container '${name}' is not running (as expected)"
        return 0
    fi
}

# assert_healthy <name> [timeout_seconds]
# Waits up to timeout for container to become healthy.
assert_healthy() {
    local name="$1"
    local timeout="${2:-60}"
    local deadline=$(( $(date +%s) + timeout ))

    if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${name}$"; then
        _log_skip "Container '${name}' not running, cannot check health"
        return 1
    fi

    local health
    while [[ $(date +%s) -lt $deadline ]]; do
        health=$(docker inspect --format '{{.State.Health.Status}}' "$name" 2>/dev/null || echo 'none')
        case "$health" in
            healthy)
                _log_pass "Container '${name}' is healthy"
                return 0
                ;;
            none|"")
                _log_pass "Container '${name}' has no healthcheck (running OK)"
                return 0
                ;;
            unhealthy)
                _log_fail "Container '${name}' is unhealthy"
                return 1
                ;;
        esac
        sleep 2
    done
    _log_fail "Container '${name}' did not become healthy within ${timeout}s (status: ${health})"
    return 1
}

# assert_container_image <name> <expected_image_substr>
assert_container_image() {
    local name="$1" expected="$2"
    local actual
    actual=$(docker inspect --format '{{.Config.Image}}' "$name" 2>/dev/null || echo "NOT_FOUND")
    if [[ "$actual" == *"$expected"* ]]; then
        _log_pass "Container '${name}' uses image matching '${expected}'"
        return 0
    else
        _log_fail "Container '${name}' image '${actual}' does not match '${expected}'"
        return 1
    fi
}

# assert_container_label <name> <label_key> [expected_value]
assert_container_label() {
    local name="$1" key="$2" expected="${3:-}"
    local actual
    actual=$(docker inspect --format "{{index .Config.Labels \"${key}\"}}" "$name" 2>/dev/null || echo "NOT_FOUND")
    if [[ -z "$expected" ]]; then
        # Just check label exists
        if [[ -n "$actual" && "$actual" != "NOT_FOUND" ]]; then
            _log_pass "Container '${name}' has label '${key}'"
            return 0
        else
            _log_fail "Container '${name}' missing label '${key}'"
            return 1
        fi
    else
        if [[ "$actual" == "$expected" ]]; then
            _log_pass "Container '${name}' label '${key}' = '${expected}'"
            return 0
        else
            _log_fail "Container '${name}' label '${key}': got '${actual}', expected '${expected}'"
            return 1
        fi
    fi
}

# assert_restart_policy <name> <expected_policy>
assert_restart_policy() {
    local name="$1" expected="$2"
    local actual
    actual=$(docker inspect --format '{{.HostConfig.RestartPolicy.Name}}' "$name" 2>/dev/null || echo "NOT_FOUND")
    if [[ "$actual" == "$expected" ]]; then
        _log_pass "Container '${name}' restart policy: '${expected}'"
        return 0
    else
        _log_fail "Container '${name}' restart policy: got '${actual}', expected '${expected}'"
        return 1
    fi
}

# assert_container_network <name> <network>
assert_container_network() {
    local name="$1" network="$2"
    if docker inspect --format '{{json .NetworkSettings.Networks}}' "$name" 2>/dev/null | grep -q "\"${network}\""; then
        _log_pass "Container '${name}' is on network '${network}'"
        return 0
    else
        _log_fail "Container '${name}' is NOT on network '${network}'"
        return 1
    fi
}

# assert_volume_mounted <name> <mount_dest>
assert_volume_mounted() {
    local name="$1" dest="$2"
    if docker inspect --format '{{json .Mounts}}' "$name" 2>/dev/null | grep -q "\"Destination\":\"${dest}\""; then
        _log_pass "Container '${name}' has volume at '${dest}'"
        return 0
    else
        _log_fail "Container '${name}' missing volume at '${dest}'"
        return 1
    fi
}

# =============================================================================
# HTTP assertions
# =============================================================================

# assert_http_200 <label> <url>
assert_http_200() {
    local label="$1" url="$2"
    local code
    code=$(curl -sf -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 10 "$url" 2>/dev/null || echo "000")
    if [[ "$code" == "200" ]]; then
        _log_pass "${label} -> HTTP 200 (${url})"
        return 0
    else
        _log_fail "${label} -> HTTP ${code}, expected 200 (${url})"
        return 1
    fi
}

# assert_http_code <label> <url> <expected_code>
assert_http_code() {
    local label="$1" url="$2" expected="$3"
    local code
    code=$(curl -sf -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 10 "$url" 2>/dev/null || echo "000")
    if [[ "$code" == "$expected" ]]; then
        _log_pass "${label} -> HTTP ${code} (${url})"
        return 0
    else
        _log_fail "${label} -> HTTP ${code}, expected ${expected} (${url})"
        return 1
    fi
}

# assert_http_redirect <label> <url> <expected_location_substr>
assert_http_redirect() {
    local label="$1" url="$2" expected_loc="$3"
    local response
    response=$(curl -sI --connect-timeout 5 --max-time 10 "$url" 2>/dev/null || echo "")
    local code
    code=$(echo "$response" | head -1 | grep -oP '\d{3}' || echo "000")
    local location
    location=$(echo "$response" | grep -i '^location:' | tr -d '\r' | awk '{print $2}' || echo "")

    if [[ "$code" =~ ^3[0-9]{2}$ ]] && [[ "$location" == *"$expected_loc"* ]]; then
        _log_pass "${label} -> ${code} redirect to ${expected_loc}"
        return 0
    else
        _log_fail "${label} -> code=${code}, location='${location}', expected redirect to '${expected_loc}'"
        return 1
    fi
}

# assert_http_response_contains <label> <url> <expected_substr>
assert_http_response_contains() {
    local label="$1" url="$2" expected="$3"
    local body
    body=$(curl -sf --connect-timeout 5 --max-time 10 "$url" 2>/dev/null || echo "")
    if [[ "$body" == *"$expected"* ]]; then
        _log_pass "${label} response contains '${expected}'"
        return 0
    else
        _log_fail "${label} response does NOT contain '${expected}'"
        return 1
    fi
}

# assert_https_valid <label> <hostname> [port]
assert_https_valid() {
    local label="$1" host="$2" port="${3:-443}"
    if echo | openssl s_client -connect "${host}:${port}" -servername "$host" 2>/dev/null | openssl x509 -noout 2>/dev/null; then
        _log_pass "${label} has valid TLS certificate"
        return 0
    else
        _log_fail "${label} TLS certificate check failed"
        return 1
    fi
}

# =============================================================================
# Port / Network assertions
# =============================================================================

# assert_port_open <label> <host> <port>
assert_port_open() {
    local label="$1" host="$2" port="$3"
    if nc -z -w3 "$host" "$port" 2>/dev/null || (echo >/dev/tcp/"$host"/"$port") 2>/dev/null; then
        _log_pass "${label} port ${port} is open on ${host}"
        return 0
    else
        _log_fail "${label} port ${port} is NOT open on ${host}"
        return 1
    fi
}

# assert_port_closed <label> <host> <port>
assert_port_closed() {
    local label="$1" host="$2" port="$3"
    if nc -z -w3 "$host" "$port" 2>/dev/null || (echo >/dev/tcp/"$host"/"$port") 2>/dev/null; then
        _log_fail "${label} port ${port} is open (expected closed)"
        return 1
    else
        _log_pass "${label} port ${port} is closed (as expected)"
        return 0
    fi
}

# assert_dns_resolves <label> <hostname> [server]
assert_dns_resolves() {
    local label="$1" host="$2" server="${3:-}"
    local result
    if [[ -n "$server" ]]; then
        result=$(dig +short "@${server}" "$host" 2>/dev/null || echo "")
    else
        result=$(dig +short "$host" 2>/dev/null || nslookup "$host" 2>/dev/null | grep -oP 'Address: \K[\d.]+' | tail -1 || echo "")
    fi
    if [[ -n "$result" ]]; then
        _log_pass "${label} DNS resolves: ${host} -> ${result}"
        return 0
    else
        _log_fail "${label} DNS failed to resolve: ${host}"
        return 1
    fi
}

# assert_network_exists <network_name>
assert_network_exists() {
    local name="$1"
    if docker network ls --format '{{.Name}}' 2>/dev/null | grep -q "^${name}$"; then
        _log_pass "Docker network '${name}' exists"
        return 0
    else
        _log_fail "Docker network '${name}' does NOT exist"
        return 1
    fi
}

# =============================================================================
# Docker Compose assertions
# =============================================================================

# assert_compose_valid <compose_file>
assert_compose_valid() {
    local file="$1"
    local label
    label=$(basename "$(dirname "$file")")/$(basename "$file")
    if docker compose -f "$file" config --quiet 2>/dev/null; then
        _log_pass "Compose file valid: ${label}"
        return 0
    else
        _log_fail "Compose file invalid: ${label}"
        return 1
    fi
}

# assert_compose_services <compose_file> <expected_count>
assert_compose_services() {
    local file="$1" expected="$2"
    local actual
    actual=$(docker compose -f "$file" config --services 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$actual" -eq "$expected" ]]; then
        _log_pass "Compose ${file##*/} has ${expected} services"
        return 0
    else
        _log_fail "Compose ${file##*/}: ${actual} services, expected ${expected}"
        return 1
    fi
}

# assert_image_pinned <compose_file>
# Checks that no images use :latest tag
assert_image_pinned() {
    local file="$1"
    local label
    label=$(basename "$(dirname "$file")")
    local images
    images=$(docker compose -f "$file" config 2>/dev/null | grep -E '^\s+image:' | awk '{print $2}')
    local bad=""
    while IFS= read -r img; do
        if [[ "$img" == *":latest" ]] || [[ "$img" != *":"* ]]; then
            bad+="  ${img}\n"
        fi
    done <<< "$images"
    if [[ -z "$bad" ]]; then
        _log_pass "Stack '${label}' — all images pinned to specific versions"
        return 0
    else
        _log_fail "Stack '${label}' — unpinned images:\n${bad}"
        return 1
    fi
}

# =============================================================================
# Resource / security assertions
# =============================================================================

# assert_memory_limit <container_name> <max_bytes>
assert_memory_limit() {
    local name="$1" max_bytes="$2"
    local limit
    limit=$(docker inspect --format '{{.HostConfig.Memory}}' "$name" 2>/dev/null || echo "0")
    if [[ "$limit" -gt 0 ]] && [[ "$limit" -le "$max_bytes" ]]; then
        _log_pass "Container '${name}' memory limit: $(( limit / 1024 / 1024 ))MB"
        return 0
    elif [[ "$limit" -eq 0 ]]; then
        _log_skip "Container '${name}' has no memory limit set"
        return 1
    else
        _log_fail "Container '${name}' memory limit ${limit} exceeds max ${max_bytes}"
        return 1
    fi
}

# assert_read_only_rootfs <container_name>
assert_read_only_rootfs() {
    local name="$1"
    local ro
    ro=$(docker inspect --format '{{.HostConfig.ReadonlyRootfs}}' "$name" 2>/dev/null || echo "false")
    if [[ "$ro" == "true" ]]; then
        _log_pass "Container '${name}' has read-only rootfs"
        return 0
    else
        _log_skip "Container '${name}' rootfs is writable"
        return 1
    fi
}

# assert_no_privileged <container_name>
assert_no_privileged() {
    local name="$1"
    local priv
    priv=$(docker inspect --format '{{.HostConfig.Privileged}}' "$name" 2>/dev/null || echo "true")
    if [[ "$priv" == "false" ]]; then
        _log_pass "Container '${name}' is not privileged"
        return 0
    else
        _log_fail "Container '${name}' is running privileged"
        return 1
    fi
}

# =============================================================================
# Exec-in-container assertions
# =============================================================================

# assert_exec <container_name> <label> <command...>
# Runs a command inside the container; passes if exit code is 0.
assert_exec() {
    local name="$1" label="$2"
    shift 2
    if docker exec "$name" "$@" >/dev/null 2>&1; then
        _log_pass "${label}"
        return 0
    else
        _log_fail "${label}"
        return 1
    fi
}

# assert_exec_contains <container_name> <label> <expected_substr> <command...>
assert_exec_contains() {
    local name="$1" label="$2" expected="$3"
    shift 3
    local output
    output=$(docker exec "$name" "$@" 2>/dev/null || echo "")
    if [[ "$output" == *"$expected"* ]]; then
        _log_pass "${label}"
        return 0
    else
        _log_fail "${label} — output does not contain '${expected}'"
        return 1
    fi
}

# =============================================================================
# File / config assertions
# =============================================================================

# assert_file_exists <path>
assert_file_exists() {
    local path="$1"
    if [[ -f "$path" ]]; then
        _log_pass "File exists: ${path}"
        return 0
    else
        _log_fail "File missing: ${path}"
        return 1
    fi
}

# assert_file_contains <path> <expected_substr>
assert_file_contains() {
    local path="$1" expected="$2"
    if [[ -f "$path" ]] && grep -q "$expected" "$path" 2>/dev/null; then
        _log_pass "File '${path##*/}' contains '${expected}'"
        return 0
    else
        _log_fail "File '${path##*/}' does not contain '${expected}'"
        return 1
    fi
}

# assert_env_var_set <var_name>
assert_env_var_set() {
    local var="$1"
    if [[ -n "${!var:-}" ]]; then
        _log_pass "Env var '${var}' is set"
        return 0
    else
        _log_fail "Env var '${var}' is not set"
        return 1
    fi
}

# =============================================================================
# Wait helpers
# =============================================================================

# wait_for_container <name> [timeout_seconds]
wait_for_container() {
    local name="$1" timeout="${2:-120}"
    local deadline=$(( $(date +%s) + timeout ))
    log_info "Waiting for container '${name}' (timeout: ${timeout}s)..."
    while [[ $(date +%s) -lt $deadline ]]; do
        if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${name}$"; then
            return 0
        fi
        sleep 2
    done
    return 1
}

# wait_for_http <url> [timeout_seconds]
wait_for_http() {
    local url="$1" timeout="${2:-120}"
    local deadline=$(( $(date +%s) + timeout ))
    log_info "Waiting for HTTP ${url} (timeout: ${timeout}s)..."
    while [[ $(date +%s) -lt $deadline ]]; do
        local code
        code=$(curl -sf -o /dev/null -w '%{http_code}' --connect-timeout 3 --max-time 5 "$url" 2>/dev/null || echo "000")
        if [[ "$code" =~ ^[23] ]]; then
            return 0
        fi
        sleep 2
    done
    return 1
}
