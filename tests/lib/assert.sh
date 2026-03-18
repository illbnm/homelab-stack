#!/usr/bin/env bash
# =============================================================================
# HomeLab Integration Tests — Assertion Library
#
# Pure bash assertion functions for testing Docker-based services.
# No external framework dependencies — just bash, curl, jq, docker.
#
# Usage: source this file from test scripts.
# =============================================================================

# Track test results
_TESTS_PASSED=0
_TESTS_FAILED=0
_TESTS_SKIPPED=0
_CURRENT_STACK=""
_CURRENT_TEST=""
_TEST_START_TIME=""

# ---------------------------------------------------------------------------
# Core assertion: report pass/fail
# ---------------------------------------------------------------------------
_pass() {
  local duration
  duration=$(_elapsed)
  _TESTS_PASSED=$((_TESTS_PASSED + 1))
  _report_result "PASS" "${_CURRENT_STACK}" "${_CURRENT_TEST}" "${duration}" ""
}

_fail() {
  local msg="${1:-}"
  local duration
  duration=$(_elapsed)
  _TESTS_FAILED=$((_TESTS_FAILED + 1))
  _report_result "FAIL" "${_CURRENT_STACK}" "${_CURRENT_TEST}" "${duration}" "${msg}"
}

_skip() {
  local msg="${1:-skipped}"
  _TESTS_SKIPPED=$((_TESTS_SKIPPED + 1))
  _report_result "SKIP" "${_CURRENT_STACK}" "${_CURRENT_TEST}" "0.0" "${msg}"
}

_elapsed() {
  if [[ -n "${_TEST_START_TIME}" ]]; then
    local now
    now=$(date +%s%N 2>/dev/null || date +%s)
    if [[ ${#now} -gt 10 ]]; then
      # Nanosecond precision available
      echo "scale=1; (${now} - ${_TEST_START_TIME}) / 1000000000" | bc 2>/dev/null || echo "0.0"
    else
      echo "$(( now - _TEST_START_TIME )).0"
    fi
  else
    echo "0.0"
  fi
}

# ---------------------------------------------------------------------------
# assert_eq <actual> <expected> [msg]
# Asserts that actual equals expected.
# ---------------------------------------------------------------------------
assert_eq() {
  local actual="$1"
  local expected="$2"
  local msg="${3:-Expected '${expected}', got '${actual}'}"

  if [[ "${actual}" == "${expected}" ]]; then
    _pass
  else
    _fail "${msg}"
  fi
}

# ---------------------------------------------------------------------------
# assert_not_empty <value> [msg]
# Asserts that value is not empty.
# ---------------------------------------------------------------------------
assert_not_empty() {
  local value="$1"
  local msg="${2:-Value is empty}"

  if [[ -n "${value}" ]]; then
    _pass
  else
    _fail "${msg}"
  fi
}

# ---------------------------------------------------------------------------
# assert_contains <haystack> <needle> [msg]
# Asserts that haystack contains needle.
# ---------------------------------------------------------------------------
assert_contains() {
  local haystack="$1"
  local needle="$2"
  local msg="${3:-String does not contain '${needle}'}"

  if echo "${haystack}" | grep -Fq -- "${needle}" 2>/dev/null; then
    _pass
  else
    _fail "${msg}"
  fi
}

# ---------------------------------------------------------------------------
# assert_exit_code <expected_code> [msg]
# Must be called immediately after a command. Uses $?.
# Usage: some_command; assert_exit_code 0 "command failed"
# ---------------------------------------------------------------------------
assert_exit_code() {
  local expected="$1"
  local msg="${2:-Expected exit code ${expected}, got ${_LAST_EXIT_CODE}}"

  if [[ "${_LAST_EXIT_CODE}" -eq "${expected}" ]]; then
    _pass
  else
    _fail "${msg}"
  fi
}

# ---------------------------------------------------------------------------
# assert_container_running <name>
# Asserts that a Docker container is running.
# ---------------------------------------------------------------------------
assert_container_running() {
  local name="$1"
  local status

  status=$(docker inspect --format='{{.State.Running}}' "${name}" 2>/dev/null)

  if [[ "${status}" == "true" ]]; then
    _pass
  else
    _fail "Container '${name}' is not running"
  fi
}

# ---------------------------------------------------------------------------
# assert_container_healthy <name> [timeout=60]
# Waits up to timeout seconds for container to be healthy.
# ---------------------------------------------------------------------------
assert_container_healthy() {
  local name="$1"
  local timeout="${2:-60}"
  local health=""

  for ((i = 0; i < timeout; i++)); do
    health=$(docker inspect --format='{{.State.Health.Status}}' "${name}" 2>/dev/null)
    if [[ "${health}" == "healthy" ]]; then
      _pass
      return
    fi
    sleep 1
  done

  _fail "Container '${name}' not healthy after ${timeout}s (status: ${health:-unknown})"
}

# ---------------------------------------------------------------------------
# assert_container_exited_ok <name>
# Asserts container exited with code 0 (for init containers).
# ---------------------------------------------------------------------------
assert_container_exited_ok() {
  local name="$1"
  local exit_code

  exit_code=$(docker inspect --format='{{.State.ExitCode}}' "${name}" 2>/dev/null)

  if [[ "${exit_code}" == "0" ]]; then
    _pass
  else
    _fail "Container '${name}' exited with code ${exit_code}"
  fi
}

# ---------------------------------------------------------------------------
# assert_http_200 <url> [timeout=30]
# Asserts that URL returns HTTP 200. Retries until timeout.
# ---------------------------------------------------------------------------
assert_http_200() {
  local url="$1"
  local timeout="${2:-30}"
  local code=""

  for ((i = 0; i < timeout; i++)); do
    code=$(curl -sf -o /dev/null -w '%{http_code}' "${url}" 2>/dev/null) || true
    if [[ "${code}" == "200" ]]; then
      _pass
      return
    fi
    sleep 1
  done

  _fail "Expected HTTP 200 from ${url}, got ${code:-timeout}"
}

# ---------------------------------------------------------------------------
# assert_http_status <url> <expected_code> [timeout=30]
# Asserts that URL returns a specific HTTP status code.
# ---------------------------------------------------------------------------
assert_http_status() {
  local url="$1"
  local expected="$2"
  local timeout="${3:-30}"
  local code=""

  for ((i = 0; i < timeout; i++)); do
    code=$(curl -sf -o /dev/null -w '%{http_code}' "${url}" 2>/dev/null) || true
    if [[ "${code}" == "${expected}" ]]; then
      _pass
      return
    fi
    sleep 1
  done

  _fail "Expected HTTP ${expected} from ${url}, got ${code:-timeout}"
}

# ---------------------------------------------------------------------------
# assert_http_response <url> <pattern> [timeout=30]
# Asserts that URL response body matches grep pattern.
# ---------------------------------------------------------------------------
assert_http_response() {
  local url="$1"
  local pattern="$2"
  local timeout="${3:-30}"
  local body=""

  for ((i = 0; i < timeout; i++)); do
    body=$(curl -sf "${url}" 2>/dev/null) || true
    if echo "${body}" | grep -Fq -- "${pattern}" 2>/dev/null; then
      _pass
      return
    fi
    sleep 1
  done

  _fail "Response from ${url} does not match pattern '${pattern}'"
}

# ---------------------------------------------------------------------------
# assert_http_response_auth <url> <user:pass> <pattern> [timeout=30]
# Like assert_http_response but with HTTP basic auth.
# ---------------------------------------------------------------------------
assert_http_response_auth() {
  local url="$1"
  local auth="$2"
  local pattern="$3"
  local timeout="${4:-30}"
  local body=""

  for ((i = 0; i < timeout; i++)); do
    body=$(curl -sf -u "${auth}" "${url}" 2>/dev/null) || true
    if echo "${body}" | grep -Fq -- "${pattern}" 2>/dev/null; then
      _pass
      return
    fi
    sleep 1
  done

  _fail "Authenticated response from ${url} does not match '${pattern}'"
}

# ---------------------------------------------------------------------------
# assert_json_value <json> <jq_path> <expected>
# Asserts that a jq expression on JSON produces the expected value.
# ---------------------------------------------------------------------------
assert_json_value() {
  local json="$1"
  local jq_path="$2"
  local expected="$3"
  local actual

  actual=$(echo "${json}" | jq -r "${jq_path}" 2>/dev/null)

  if [[ "${actual}" == "${expected}" ]]; then
    _pass
  else
    _fail "JSON ${jq_path} expected '${expected}', got '${actual}'"
  fi
}

# ---------------------------------------------------------------------------
# assert_json_key_exists <json> <jq_path>
# Asserts that a jq path exists and is not null.
# ---------------------------------------------------------------------------
assert_json_key_exists() {
  local json="$1"
  local jq_path="$2"
  local value

  value=$(echo "${json}" | jq -r "${jq_path}" 2>/dev/null)

  if [[ -n "${value}" && "${value}" != "null" ]]; then
    _pass
  else
    _fail "JSON key ${jq_path} does not exist or is null"
  fi
}

# ---------------------------------------------------------------------------
# assert_no_errors <json>
# Asserts that JSON response has no .errors field or it's empty.
# ---------------------------------------------------------------------------
assert_no_errors() {
  local json="$1"
  local errors

  errors=$(echo "${json}" | jq -r '.errors // empty | length' 2>/dev/null)

  if [[ -z "${errors}" || "${errors}" == "0" ]]; then
    _pass
  else
    _fail "Response contains errors: $(echo "${json}" | jq -c '.errors' 2>/dev/null)"
  fi
}

# ---------------------------------------------------------------------------
# assert_file_contains <file> <pattern>
# Asserts that a file contains the given grep pattern.
# ---------------------------------------------------------------------------
assert_file_contains() {
  local file="$1"
  local pattern="$2"

  if [[ ! -f "${file}" ]]; then
    _fail "File '${file}' does not exist"
    return
  fi

  if grep -Fq -- "${pattern}" "${file}" 2>/dev/null; then
    _pass
  else
    _fail "File '${file}' does not contain '${pattern}'"
  fi
}

# ---------------------------------------------------------------------------
# assert_file_not_contains <file> <pattern>
# Asserts that a file does NOT contain the given grep pattern.
# ---------------------------------------------------------------------------
assert_file_not_contains() {
  local file="$1"
  local pattern="$2"

  if [[ ! -f "${file}" ]]; then
    _pass  # File doesn't exist, so it doesn't contain the pattern
    return
  fi

  if grep -Fq -- "${pattern}" "${file}" 2>/dev/null; then
    _fail "File '${file}' contains '${pattern}' (should not)"
  else
    _pass
  fi
}

# ---------------------------------------------------------------------------
# assert_no_latest_images <dir>
# Scans compose files in dir for :latest image tags.
# ---------------------------------------------------------------------------
assert_no_latest_images() {
  local dir="$1"
  local count

  count=$(grep -r 'image:.*:latest' "${dir}" 2>/dev/null | wc -l | tr -d ' ')

  if [[ "${count}" == "0" ]]; then
    _pass
  else
    _fail "Found ${count} :latest image tag(s) in ${dir}"
  fi
}

# ---------------------------------------------------------------------------
# assert_port_listening <port> [protocol=tcp]
# Asserts that a port is listening on the host.
# ---------------------------------------------------------------------------
assert_port_listening() {
  local port="$1"
  local proto="${2:-tcp}"

  local ss_flag="-lnt"
  [[ "${proto}" == "udp" ]] && ss_flag="-lnu"
  if ss "${ss_flag}" 2>/dev/null | grep -q ":${port} " || \
     netstat "${ss_flag}p" 2>/dev/null | grep -q ":${port} "; then
    _pass
  else
    _fail "Port ${port}/${proto} is not listening"
  fi
}

# ---------------------------------------------------------------------------
# assert_network_exists <name>
# Asserts that a Docker network exists.
# ---------------------------------------------------------------------------
assert_network_exists() {
  local name="$1"

  if docker network inspect "${name}" > /dev/null 2>&1; then
    _pass
  else
    _fail "Docker network '${name}' does not exist"
  fi
}

# ---------------------------------------------------------------------------
# assert_container_on_network <container> <network>
# Asserts a container is connected to a specific Docker network.
# ---------------------------------------------------------------------------
assert_container_on_network() {
  local container="$1"
  local network="$2"
  if docker inspect --format='{{json .NetworkSettings.Networks}}' "${container}" 2>/dev/null | grep -q "\"${network}\""; then
    _pass
  else
    _fail "Container '${container}' is not on network '${network}'"
  fi
}

# ---------------------------------------------------------------------------
# assert_container_not_on_network <container> <network>
# Asserts a container is NOT on a specific Docker network.
# ---------------------------------------------------------------------------
assert_container_not_on_network() {
  local container="$1"
  local network="$2"

  if docker inspect --format='{{json .NetworkSettings.Networks}}' "${container}" 2>/dev/null | grep -q "\"${network}\""; then
    _fail "Container '${container}' should not be on network '${network}'"
  else
    _pass
  fi
}

# ---------------------------------------------------------------------------
# assert_volume_exists <name>
# Asserts that a Docker volume exists.
# ---------------------------------------------------------------------------
assert_volume_exists() {
  local name="$1"

  if docker volume inspect "${name}" > /dev/null 2>&1; then
    _pass
  else
    _fail "Docker volume '${name}' does not exist"
  fi
}

# ---------------------------------------------------------------------------
# assert_docker_exec <container> <command> <expected_output>
# Runs a command inside a container and checks output contains expected.
# ---------------------------------------------------------------------------
assert_docker_exec() {
  local container="$1"
  local cmd="$2"
  local expected="$3"
  local output

  output=$(docker exec "${container}" sh -c "${cmd}" 2>&1) || true

  if echo "${output}" | grep -Fq -- "${expected}" 2>/dev/null; then
    _pass
  else
    _fail "docker exec ${container}: expected '${expected}' in output, got '${output}'"
  fi
}
