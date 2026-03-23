#!/usr/bin/env bash
# =============================================================================
# Assertion Library for HomeLab Integration Tests
# Pure bash assertion functions — no external test frameworks.
# =============================================================================
# shellcheck disable=SC2034
set -euo pipefail

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------
_ASSERT_PASS=0
_ASSERT_FAIL=0
_ASSERT_SKIP=0

# Record a pass
_assert_pass() {
  (( _ASSERT_PASS++ )) || true
}

# Record a failure and print diagnostic
_assert_fail() {
  local msg="${1:-assertion failed}"
  (( _ASSERT_FAIL++ )) || true
  echo "  ASSERTION FAILED: ${msg}" >&2
  return 1
}

# ---------------------------------------------------------------------------
# 1. assert_eq <actual> <expected> [msg]
# ---------------------------------------------------------------------------
assert_eq() {
  local actual="${1:?actual value required}"
  local expected="${2:?expected value required}"
  local msg="${3:-expected '"'"'${expected}'"'"', got '"'"'${actual}'"'"'}"
  if [[ "${actual}" == "${expected}" ]]; then
    _assert_pass
  else
    _assert_fail "${msg}"
  fi
}

# ---------------------------------------------------------------------------
# 2. assert_not_empty <value> [msg]
# ---------------------------------------------------------------------------
assert_not_empty() {
  local value="${1:-}"
  local msg="${2:-value is empty}"
  if [[ -n "${value}" ]]; then
    _assert_pass
  else
    _assert_fail "${msg}"
  fi
}

# ---------------------------------------------------------------------------
# 3. assert_exit_code <expected_code> [msg]
#    Checks $? of the previously executed command.
#    Usage:  some_command; assert_exit_code 0 "command should succeed"
# ---------------------------------------------------------------------------
assert_exit_code() {
  local last_exit=$?
  local expected="${1:?expected exit code required}"
  local msg="${2:-expected exit code ${expected}, got ${last_exit}}"
  if [[ "${last_exit}" -eq "${expected}" ]]; then
    _assert_pass
  else
    _assert_fail "${msg}"
  fi
}

# ---------------------------------------------------------------------------
# 4. assert_container_running <name>
# ---------------------------------------------------------------------------
assert_container_running() {
  local name="${1:?container name required}"
  local state
  state=$(docker inspect -f '{{.State.Running}}' "${name}" 2>/dev/null || echo "false")
  if [[ "${state}" == "true" ]]; then
    _assert_pass
  else
    _assert_fail "container '${name}' is not running"
  fi
}

# ---------------------------------------------------------------------------
# 5. assert_container_healthy <name>
#    Waits up to 60 seconds for the container to become healthy.
# ---------------------------------------------------------------------------
assert_container_healthy() {
  local name="${1:?container name required}"
  local timeout=60
  local elapsed=0
  local health

  while (( elapsed < timeout )); do
    health=$(docker inspect -f '{{.State.Health.Status}}' "${name}" 2>/dev/null || echo "none")
    if [[ "${health}" == "healthy" ]]; then
      _assert_pass
      return 0
    fi
    sleep 2
    (( elapsed += 2 )) || true
  done

  _assert_fail "container '${name}' not healthy after ${timeout}s (status: ${health})"
}

# ---------------------------------------------------------------------------
# 6. assert_http_200 <url> [timeout=30]
# ---------------------------------------------------------------------------
assert_http_200() {
  local url="${1:?url required}"
  local timeout="${2:-30}"
  local code
  code=$(curl -fsSL -o /dev/null -w '%{http_code}' --max-time "${timeout}" \
    --retry 3 --retry-delay 2 --retry-connrefused -k "${url}" 2>/dev/null || echo "000")
  if [[ "${code}" == "200" ]]; then
    _assert_pass
  else
    _assert_fail "GET ${url} returned ${code}, expected 200"
  fi
}

# ---------------------------------------------------------------------------
# 7. assert_http_response <url> <pattern>
#    Checks that the HTTP response body matches grep -q <pattern>.
# ---------------------------------------------------------------------------
assert_http_response() {
  local url="${1:?url required}"
  local pattern="${2:?grep pattern required}"
  local body
  body=$(curl -fsSL --max-time 30 --retry 3 --retry-delay 2 \
    --retry-connrefused -k "${url}" 2>/dev/null || echo "")
  if echo "${body}" | grep -q "${pattern}"; then
    _assert_pass
  else
    _assert_fail "response from ${url} does not match pattern '${pattern}'"
  fi
}

# ---------------------------------------------------------------------------
# 8. assert_json_value <json> <jq_path> <expected>
# ---------------------------------------------------------------------------
assert_json_value() {
  local json="${1:?json string required}"
  local jq_path="${2:?jq path required}"
  local expected="${3:?expected value required}"
  local actual
  actual=$(echo "${json}" | jq -r "${jq_path}" 2>/dev/null || echo "__jq_error__")
  if [[ "${actual}" == "${expected}" ]]; then
    _assert_pass
  else
    _assert_fail "JSON ${jq_path} = '${actual}', expected '${expected}'"
  fi
}

# ---------------------------------------------------------------------------
# 9. assert_json_key_exists <json> <jq_path>
# ---------------------------------------------------------------------------
assert_json_key_exists() {
  local json="${1:?json string required}"
  local jq_path="${2:?jq path required}"
  local result
  if result=$(echo "${json}" | jq -e "${jq_path}" 2>/dev/null) && [[ "${result}" != "null" ]]; then
    _assert_pass
  else
    _assert_fail "JSON key '${jq_path}' does not exist"
  fi
}

# ---------------------------------------------------------------------------
# 10. assert_no_errors <json>
#     Verifies the .errors field is empty/null/absent.
# ---------------------------------------------------------------------------
assert_no_errors() {
  local json="${1:?json string required}"
  local errors
  errors=$(echo "${json}" | jq -r '.errors // empty' 2>/dev/null || echo "")
  if [[ -z "${errors}" ]] || [[ "${errors}" == "null" ]] || [[ "${errors}" == "[]" ]]; then
    _assert_pass
  else
    _assert_fail "JSON contains errors: ${errors}"
  fi
}

# ---------------------------------------------------------------------------
# 11. assert_file_contains <file> <pattern>
# ---------------------------------------------------------------------------
assert_file_contains() {
  local file="${1:?file path required}"
  local pattern="${2:?pattern required}"
  if [[ ! -f "${file}" ]]; then
    _assert_fail "file '${file}' does not exist"
    return 1
  fi
  if grep -q "${pattern}" "${file}"; then
    _assert_pass
  else
    _assert_fail "file '${file}' does not contain pattern '${pattern}'"
  fi
}

# ---------------------------------------------------------------------------
# 12. assert_no_latest_images <dir>
#     Scans compose files in <dir> for images tagged :latest.
# ---------------------------------------------------------------------------
assert_no_latest_images() {
  local dir="${1:?directory required}"
  local violations=""
  local compose_files

  compose_files=$(find "${dir}" -name 'docker-compose*.yml' -type f 2>/dev/null || true)
  if [[ -z "${compose_files}" ]]; then
    _assert_fail "no compose files found in '${dir}'"
    return 1
  fi

  while IFS= read -r f; do
    local matches
    matches=$(grep -n ':latest' "${f}" 2>/dev/null | grep -v '^\s*#' || true)
    if [[ -n "${matches}" ]]; then
      violations="${violations}${f}:\n${matches}\n"
    fi
  done <<< "${compose_files}"

  if [[ -z "${violations}" ]]; then
    _assert_pass
  else
    _assert_fail "found :latest image tags:\n${violations}"
  fi
}
