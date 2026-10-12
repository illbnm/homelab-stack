#!/usr/bin/env bash

# Assertion Library for HomeLab Stack Integration Tests
#
# Provides functions to assert various conditions, with retry logic for network operations.
#
# Dependencies:
#   curl, jq, docker, docker compose (v2)

# --- Global Variables ---
ASSERT_LOG_FILE="/tmp/homelab_assert_errors.log"

# --- Colors for terminal output ---
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'
COLOR_BLUE='\033[0;34m'
COLOR_CYAN='\033[0;36m'
COLOR_RESET='\033[0m'

# --- Assertion Helper ---
_assert_fail() {
  local msg="$1"
  echo "${msg}" >> "${ASSERT_LOG_FILE}"
  return 1 # Indicate failure
}

# --- Core Assertions ---

# assert_eq <actual> <expected> [msg]
assert_eq() {
  local actual="$1"
  local expected="$2"
  local msg="${3:-"Expected '$expected', got '$actual'"}"
  if [[ "${actual}" != "${expected}" ]]; then
    _assert_fail "${msg}"
  fi
}

# assert_not_empty <value> [msg]
assert_not_empty() {
  local value="$1"
  local msg="${2:-"Value is empty"}"
  if [[ -z "${value}" ]]; then
    _assert_fail "${msg}"
  fi
}

# assert_exit_code <code> [msg]
# This assertion should be used immediately after the command whose exit code is being checked.
# Example:
#   my_command
#   assert_exit_code 0 "my_command failed"
assert_exit_code() {
  local expected_code="$1"
  local msg="${2:-"Unexpected exit code. Expected ${expected_code}, got $?"}"
  if [[ "$?" -ne "${expected_code}" ]]; then
    _assert_fail "${msg}"
  fi
}

# --- Docker Assertions ---

# assert_container_running <name> [timeout=60] [msg]
assert_container_running() {
  local container_name="$1"
  local timeout="${2:-60}"
  local msg="${3:-"Container '${container_name}' is not running"}"
  
  if ! wait_for_container_status "${container_name}" "running" "${timeout}"; then
    _assert_fail "${msg}"
  fi
}

# assert_container_healthy <name> [timeout=60] [msg]
assert_container_healthy() {
  local container_name="$1"
  local timeout="${2:-60}"
  local msg="${3:-"Container '${container_name}' is not healthy"}"

  if ! wait_for_container_health "${container_name}" "${timeout}"; then
    _assert_fail "${msg}"
  fi
}

# --- HTTP Assertions ---

# assert_http_status <url> <expected_status> [timeout=30] [msg]
assert_http_status() {
  local url="$1"
  local expected_status="$2"
  local timeout="${3:-30}"
  local msg="${4:-"HTTP GET ${url} failed. Expected status ${expected_status}"}"
  local actual_status=""

  if ! retry_command "${timeout}" 2 "
    actual_status=\$(curl -s -o /dev/null -w '%{http_code}' '${url}')
    [[ \"\${actual_status}\" -eq \"${expected_status}\" ]]
  "; then
    _assert_fail "${msg}. Actual status: ${actual_status}"
  fi
}

# assert_http_200 <url> [timeout=30] [msg]
assert_http_200() {
  local url="$1"
  local timeout="${2:-30}"
  local msg="${3:-"HTTP GET ${url} did not return 200"}"
  assert_http_status "${url}" 200 "${timeout}" "${msg}"
}

# assert_http_response <url> <pattern> [timeout=30] [msg]
assert_http_response() {
  local url="$1"
  local pattern="$2"
  local timeout="${3:-30}"
  local msg="${4:-"HTTP GET ${url} response does not contain pattern '${pattern}'"}"
  local response=""

  if ! retry_command "${timeout}" 2 "
    response=\$(curl -s '${url}')
    echo \"\${response}\" | grep -qE \"${pattern}\"
  "; then
    _assert_fail "${msg}. Response: ${response}"
  fi
}

# --- JSON Assertions (requires jq) ---

# assert_json_value <json> <jq_path> <expected> [msg]
assert_json_value() {
  local json="$1"
  local jq_path="$2"
  local expected="$3"
  local msg="${4:-"JSON value at '${jq_path}' mismatch. Expected '${expected}'"}"
  local actual=""

  actual=$(echo "${json}" | jq -r "${jq_path}" 2>/dev/null || echo "jq_error")

  if [[ "${actual}" == "jq_error" ]]; then
    _assert_fail "Failed to parse JSON or jq path '${jq_path}' is invalid. JSON: ${json}"
  fi

  if [[ "${actual}" != "${expected}" ]]; then
    _assert_fail "${msg}. Actual: '${actual}'"
  fi
}

# assert_json_key_exists <json> <jq_path> [msg]
assert_json_key_exists() {
  local json="$1"
  local jq_path="$2"
  local msg="${3:-"JSON key at '${jq_path}' does not exist"}"
  local value=""

  value=$(echo "${json}" | jq -r "${jq_path}" 2>/dev/null || echo "jq_error")

  if [[ "${value}" == "jq_error" ]]; then
    _assert_fail "Failed to parse JSON or jq path '${jq_path}' is invalid. JSON: ${json}"
  fi

  if [[ "${value}" == "null" || -z "${value}" ]]; then
    _assert_fail "${msg}"
  fi
}

# assert_no_errors <json> [msg]
# Assumes JSON has a top-level 'errors' array or similar structure.
assert_no_errors() {
  local json="$1"
  local msg="${2:-"JSON response contains errors"}"
  local errors=""

  errors=$(echo "${json}" | jq -r '.errors // empty' 2>/dev/null)

  if [[ -n "${errors}" ]]; then
    _assert_fail "${msg}: ${errors}"
  fi
}

# --- File Assertions ---

# assert_file_contains <file> <pattern> [msg]
assert_file_contains() {
  local file="$1"
  local pattern="$2"
  local msg="${3:-"File '${file}' does not contain pattern '${pattern}'"}"

  if [[ ! -f "${file}" ]]; then
    _assert_fail "File '${file}' not found."
  fi

  if ! grep -qE "${pattern}" "${file}"; then
    _assert_fail "${msg}"
  fi
}

# assert_no_latest_images <dir> [msg]
# Scans docker-compose.yml files in a directory for ':latest' image tags.
assert_no_latest_images() {
  local dir="$1"
  local msg="${2:-"Found ':latest' image tags in compose files"}"
  local latest_count=0

  # Find all docker-compose.yml files and check for ':latest'
  # Exclude comments and lines that might contain 'latest' in other contexts
  latest_count=$(find "${dir}" -name 'docker-compose.yml' -print0 | xargs -0 grep -E 'image:.*:latest' | grep -v '#' | wc -l)

  if [[ "${latest_count}" -gt 0 ]]; then
    _assert_fail "${msg}. Found ${latest_count} instances of ':latest' image tags."
  fi
}

# assert_all_services_have_healthcheck <compose_file> [msg]
# Checks if all services in a docker-compose file have a healthcheck defined.
assert_all_services_have_healthcheck() {
  local compose_file="$1"
  local msg="${2:-"Not all services in '${compose_file}' have a healthcheck"}"
  local services_without_healthcheck=""

  if [[ ! -f "${compose_file}" ]]; then
    _assert_fail "Compose file '${compose_file}' not found."
  fi

  # Get all service names
  local services
  mapfile -t services < <(docker compose -f "${compose_file}" config --services 2>/dev/null)

  if [[ ${#services[@]} -eq 0 ]]; then
    _assert_fail "No services found in compose file '${compose_file}'."
  fi

  for service in "${services[@]}"; do
    # Check if healthcheck is defined for the service
    # docker compose config will show healthcheck if present
    local healthcheck_output
    healthcheck_output=$(docker compose -f "${compose_file}" config --format json 2>/dev/null | jq -r ".services.${service}.healthcheck // empty")

    if [[ -z "${healthcheck_output}" ]]; then
      services_without_healthcheck+=" ${service}"
    fi
  done

  if [[ -n "${services_without_healthcheck}" ]]; then
    _assert_fail "${msg}. Services missing healthcheck:${services_without_healthcheck}"
  fi
}
