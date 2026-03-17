#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Assertion Library
# =============================================================================
# Pure-bash assertion functions for integration testing.
# Provides typed assertions for strings, containers, HTTP endpoints, JSON, etc.
#
# Usage:
#   source tests/lib/assert.sh
#
# All assertions call _record_result() (from report.sh) to track pass/fail.
# =============================================================================

# Guard against double-sourcing
[[ -n "${__ASSERT_SH_LOADED:-}" ]] && return 0
readonly __ASSERT_SH_LOADED=1

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

# _assert_fail <message>
# Records a failure and returns 1 (does NOT exit — tests keep running).
_assert_fail() {
  local msg="${1:-Assertion failed}"
  _record_result "FAIL" "${CURRENT_TEST_NAME:-unknown}" "${msg}" "${CURRENT_STACK:-unknown}"
  return 1
}

# _assert_pass <message>
_assert_pass() {
  local msg="${1:-}"
  _record_result "PASS" "${CURRENT_TEST_NAME:-unknown}" "${msg}" "${CURRENT_STACK:-unknown}"
  return 0
}

# _assert_skip <message>
_assert_skip() {
  local msg="${1:-Skipped}"
  _record_result "SKIP" "${CURRENT_TEST_NAME:-unknown}" "${msg}" "${CURRENT_STACK:-unknown}"
  return 0
}

# ---------------------------------------------------------------------------
# String / value assertions
# ---------------------------------------------------------------------------

# assert_eq <actual> <expected> [msg]
assert_eq() {
  local actual="$1"
  local expected="$2"
  local msg="${3:-Expected '${expected}', got '${actual}'}"

  if [[ "${actual}" == "${expected}" ]]; then
    _assert_pass "${msg}"
  else
    _assert_fail "Expected '${expected}', got '${actual}'. ${msg}"
  fi
}

# assert_not_empty <value> [msg]
assert_not_empty() {
  local value="$1"
  local msg="${2:-Value should not be empty}"

  if [[ -n "${value}" ]]; then
    _assert_pass "${msg}"
  else
    _assert_fail "${msg}"
  fi
}

# assert_exit_code <expected_code> [msg]
# Validates the exit code of the previous command.
#
# IMPORTANT: In bash, $? inside a function reflects the exit code of the
# function call itself, NOT the command before the function was called.
# Therefore, callers MUST capture $? BEFORE calling this function:
#
#   some_command
#   local rc=$?
#   assert_exit_code "${rc}" 0 "some_command should succeed"
#
# When called with 3 args: assert_exit_code <actual_code> <expected_code> [msg]
# When called with 2 args: assert_exit_code <expected_code> [msg]  (uses $?)
# The 3-arg form is STRONGLY recommended.
assert_exit_code() {
  local actual expected msg

  if [[ $# -ge 2 && "$1" =~ ^[0-9]+$ && "$2" =~ ^[0-9]+$ ]]; then
    # 3-arg form: assert_exit_code <actual> <expected> [msg]
    actual="$1"
    expected="$2"
    msg="${3:-Expected exit code ${expected}, got ${actual}}"
  else
    # 2-arg legacy form: assert_exit_code <expected> [msg]  — uses $?
    # WARNING: $? here is the exit code of entering this function, which
    # may not be what the caller intended. Use the 3-arg form instead.
    actual=$?
    expected="${1:-0}"
    msg="${2:-Expected exit code ${expected}, got ${actual}}"
  fi

  if [[ "${actual}" -eq "${expected}" ]]; then
    _assert_pass "${msg}"
  else
    _assert_fail "Expected exit code ${expected}, got ${actual}. ${msg}"
  fi
}

# ---------------------------------------------------------------------------
# Docker container assertions
# ---------------------------------------------------------------------------

# assert_container_running <container_name>
assert_container_running() {
  local name="$1"
  local running

  running=$(docker inspect --format='{{.State.Running}}' "${name}" 2>/dev/null || echo "false")

  if [[ "${running}" == "true" ]]; then
    _assert_pass "Container '${name}' is running"
  else
    _assert_fail "Container '${name}' is not running (state: ${running})"
  fi
}

# assert_container_healthy <container_name> [timeout=60]
# Waits up to <timeout> seconds for the container to become healthy.
assert_container_healthy() {
  local name="$1"
  local timeout="${2:-60}"
  local waited=0
  local status

  while [[ "${waited}" -lt "${timeout}" ]]; do
    status=$(docker inspect --format='{{.State.Health.Status}}' "${name}" 2>/dev/null || echo "not found")

    if [[ "${status}" == "healthy" ]]; then
      _assert_pass "Container '${name}' is healthy (waited ${waited}s)"
      return 0
    fi

    sleep 2
    waited=$((waited + 2))
  done

  _assert_fail "Container '${name}' not healthy after ${timeout}s (status: ${status})"
}

# assert_container_not_running <container_name>
assert_container_not_running() {
  local name="$1"
  local running

  running=$(docker inspect --format='{{.State.Running}}' "${name}" 2>/dev/null || echo "false")

  if [[ "${running}" != "true" ]]; then
    _assert_pass "Container '${name}' is not running (expected)"
  else
    _assert_fail "Container '${name}' is running but should not be"
  fi
}

# assert_container_on_network <container_name> <network_name>
assert_container_on_network() {
  local name="$1"
  local network="$2"
  local networks

  networks=$(docker inspect --format='{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' "${name}" 2>/dev/null || echo "")

  if echo "${networks}" | grep -q "${network}"; then
    _assert_pass "Container '${name}' is on network '${network}'"
  else
    _assert_fail "Container '${name}' is NOT on network '${network}' (networks: ${networks})"
  fi
}

# assert_container_not_on_network <container_name> <network_name>
assert_container_not_on_network() {
  local name="$1"
  local network="$2"
  local networks

  networks=$(docker inspect --format='{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' "${name}" 2>/dev/null || echo "")

  if echo "${networks}" | grep -q "${network}"; then
    _assert_fail "Container '${name}' should NOT be on network '${network}'"
  else
    _assert_pass "Container '${name}' is correctly not on network '${network}'"
  fi
}

# assert_no_host_ports <container_name>
assert_no_host_ports() {
  local name="$1"
  local ports

  ports=$(docker inspect --format='{{range $p, $conf := .NetworkSettings.Ports}}{{if $conf}}{{(index $conf 0).HostPort}} {{end}}{{end}}' "${name}" 2>/dev/null || echo "")

  if [[ -z "${ports}" ]]; then
    _assert_pass "Container '${name}' has no host-exposed ports"
  else
    _assert_fail "Container '${name}' exposes host ports: ${ports}"
  fi
}

# ---------------------------------------------------------------------------
# HTTP assertions
# ---------------------------------------------------------------------------

# assert_http_200 <url> [timeout=30]
assert_http_200() {
  local url="$1"
  local timeout="${2:-30}"
  local http_code

  http_code=$(curl -s -o /dev/null -w '%{http_code}' \
    --max-time "${timeout}" --connect-timeout 10 \
    -k -L "${url}" 2>/dev/null || echo "000")

  if [[ "${http_code}" == "200" ]]; then
    _assert_pass "HTTP 200 from ${url}"
  else
    _assert_fail "Expected HTTP 200 from ${url}, got ${http_code}"
  fi
}

# assert_http_status <url> <expected_code> [timeout=30]
assert_http_status() {
  local url="$1"
  local expected="$2"
  local timeout="${3:-30}"
  local http_code

  http_code=$(curl -s -o /dev/null -w '%{http_code}' \
    --max-time "${timeout}" --connect-timeout 10 \
    -k -L "${url}" 2>/dev/null || echo "000")

  if [[ "${http_code}" == "${expected}" ]]; then
    _assert_pass "HTTP ${expected} from ${url}"
  else
    _assert_fail "Expected HTTP ${expected} from ${url}, got ${http_code}"
  fi
}

# assert_http_response <url> <grep_pattern> [timeout=30]
# Checks that the response body matches a grep pattern.
assert_http_response() {
  local url="$1"
  local pattern="$2"
  local timeout="${3:-30}"
  local body

  body=$(curl -s --max-time "${timeout}" --connect-timeout 10 \
    -k -L "${url}" 2>/dev/null || echo "")

  if echo "${body}" | grep -q "${pattern}"; then
    _assert_pass "HTTP response from ${url} matches '${pattern}'"
  else
    _assert_fail "HTTP response from ${url} does not match '${pattern}'"
  fi
}

# ---------------------------------------------------------------------------
# JSON assertions (requires jq)
# ---------------------------------------------------------------------------

# assert_json_value <json_string> <jq_path> <expected_value>
assert_json_value() {
  local json="$1"
  local jq_path="$2"
  local expected="$3"
  local actual

  if ! command -v jq &>/dev/null; then
    _assert_skip "jq not installed — cannot validate JSON"
    return 0
  fi

  actual=$(echo "${json}" | jq -r "${jq_path}" 2>/dev/null || echo "__JQ_ERROR__")

  if [[ "${actual}" == "__JQ_ERROR__" ]]; then
    _assert_fail "jq parse error for path '${jq_path}'"
  elif [[ "${actual}" == "${expected}" ]]; then
    _assert_pass "JSON ${jq_path} == '${expected}'"
  else
    _assert_fail "JSON ${jq_path}: expected '${expected}', got '${actual}'"
  fi
}

# assert_json_key_exists <json_string> <jq_path>
assert_json_key_exists() {
  local json="$1"
  local jq_path="$2"
  local value

  if ! command -v jq &>/dev/null; then
    _assert_skip "jq not installed — cannot validate JSON"
    return 0
  fi

  value=$(echo "${json}" | jq -r "${jq_path}" 2>/dev/null || echo "null")

  if [[ "${value}" != "null" && -n "${value}" ]]; then
    _assert_pass "JSON key '${jq_path}' exists"
  else
    _assert_fail "JSON key '${jq_path}' does not exist or is null"
  fi
}

# assert_no_errors <json_string>
# Checks that .errors is empty/null/absent in the JSON.
assert_no_errors() {
  local json="$1"

  if ! command -v jq &>/dev/null; then
    _assert_skip "jq not installed — cannot validate JSON"
    return 0
  fi

  local errors
  errors=$(echo "${json}" | jq -r '.errors // empty' 2>/dev/null || echo "")

  if [[ -z "${errors}" || "${errors}" == "null" || "${errors}" == "[]" ]]; then
    _assert_pass "No errors in JSON response"
  else
    _assert_fail "JSON response contains errors: ${errors}"
  fi
}

# ---------------------------------------------------------------------------
# File assertions
# ---------------------------------------------------------------------------

# assert_file_contains <file_path> <grep_pattern>
assert_file_contains() {
  local file="$1"
  local pattern="$2"

  if [[ ! -f "${file}" ]]; then
    _assert_fail "File '${file}' does not exist"
    return 1
  fi

  if grep -q "${pattern}" "${file}"; then
    _assert_pass "File '${file}' contains '${pattern}'"
  else
    _assert_fail "File '${file}' does not contain '${pattern}'"
  fi
}

# assert_file_exists <file_path>
assert_file_exists() {
  local file="$1"

  if [[ -f "${file}" ]]; then
    _assert_pass "File '${file}' exists"
  else
    _assert_fail "File '${file}' does not exist"
  fi
}

# assert_file_executable <file_path>
assert_file_executable() {
  local file="$1"

  if [[ -x "${file}" ]]; then
    _assert_pass "File '${file}' is executable"
  else
    _assert_fail "File '${file}' is not executable"
  fi
}

# ---------------------------------------------------------------------------
# Compose / image assertions
# ---------------------------------------------------------------------------

# assert_no_latest_images <directory>
# Scans all docker-compose.yml files in <directory> for:
#   1. Explicit :latest tags (including with trailing comments)
#   2. Untagged images (which default to :latest at pull time)
# Ignores variable references like ${VAR} since those are resolved at runtime.
assert_no_latest_images() {
  local dir="$1"
  local fail=0
  local offenders=""

  # Check 1: Explicit :latest tags (handles trailing whitespace and comments)
  local latest_count
  latest_count=$(grep -rE 'image:\s+\S+:latest(\s|$|#)' "${dir}" \
    --include='*.yml' --include='*.yaml' 2>/dev/null | wc -l)
  latest_count=$(echo "${latest_count}" | tr -d '[:space:]')

  if [[ "${latest_count}" -gt 0 ]]; then
    offenders+="Explicit :latest tags:\n"
    offenders+=$(grep -rnE 'image:\s+\S+:latest(\s|$|#)' "${dir}" \
      --include='*.yml' --include='*.yaml' 2>/dev/null || true)
    offenders+="\n"
    fail=1
  fi

  # Check 2: Untagged images (no : after image name → defaults to :latest)
  # Matches "image: nginx" but not "image: nginx:1.25" or "${VARIABLE}" refs
  local untagged_count
  untagged_count=$(grep -rE 'image:\s+[a-zA-Z0-9_./-]+\s*$' "${dir}" \
    --include='*.yml' --include='*.yaml' 2>/dev/null \
    | grep -v ':\S*:' | grep -v '\$\{' | wc -l)
  untagged_count=$(echo "${untagged_count}" | tr -d '[:space:]')

  if [[ "${untagged_count}" -gt 0 ]]; then
    offenders+="Untagged images (default to :latest):\n"
    offenders+=$(grep -rnE 'image:\s+[a-zA-Z0-9_./-]+\s*$' "${dir}" \
      --include='*.yml' --include='*.yaml' 2>/dev/null \
      | grep -v ':\S*:' | grep -v '\$\{' || true)
    fail=1
  fi

  local total=$(( latest_count + untagged_count ))

  if [[ "${fail}" -eq 0 ]]; then
    _assert_pass "No ':latest' or untagged images in ${dir}"
  else
    _assert_fail "Found ${total} problematic image tags in ${dir}:\n${offenders}"
  fi
}

# assert_compose_valid <compose_file>
# Validates that a docker-compose file has valid syntax.
assert_compose_valid() {
  local file="$1"

  if docker compose -f "${file}" config --quiet 2>/dev/null; then
    _assert_pass "Compose file '${file}' is valid"
  else
    _assert_fail "Compose file '${file}' has invalid syntax"
  fi
}

# assert_no_gcr_images <directory>
# Scans compose files for references to gcr.io, ghcr.io/google, or k8s.gcr.io
# images that would be inaccessible in China's network.
assert_no_gcr_images() {
  local dir="$1"
  local count

  count=$(grep -rE 'image:\s*(gcr\.io|k8s\.gcr\.io|registry\.k8s\.io)' \
    "${dir}" --include='*.yml' --include='*.yaml' 2>/dev/null | wc -l)
  count=$(echo "${count}" | tr -d '[:space:]')

  if [[ "${count}" -eq 0 ]]; then
    _assert_pass "No GCR/k8s.gcr.io images in ${dir}"
  else
    local offenders
    offenders=$(grep -rE 'image:\s*(gcr\.io|k8s\.gcr\.io|registry\.k8s\.io)' \
      "${dir}" --include='*.yml' --include='*.yaml' 2>/dev/null || true)
    _assert_fail "Found ${count} GCR/k8s.gcr.io images in ${dir} (inaccessible in China):\n${offenders}"
  fi
}

# assert_all_services_have_healthcheck <compose_file>
# Parses a compose file and verifies every service has a healthcheck block.
assert_all_services_have_healthcheck() {
  local file="$1"

  if ! command -v jq &>/dev/null; then
    _assert_skip "jq not installed — cannot parse compose config"
    return 0
  fi

  local config
  config=$(docker compose -f "${file}" config --format json 2>/dev/null || echo "")

  if [[ -z "${config}" ]]; then
    _assert_fail "Could not parse compose file '${file}'"
    return 1
  fi

  local services_without_hc
  services_without_hc=$(echo "${config}" | jq -r \
    '.services | to_entries[] | select(.value.healthcheck == null) | .key' 2>/dev/null || echo "")

  if [[ -z "${services_without_hc}" ]]; then
    _assert_pass "All services in '${file}' have healthchecks"
  else
    _assert_fail "Services without healthcheck in '${file}': ${services_without_hc}"
  fi
}
