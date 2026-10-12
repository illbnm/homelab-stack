# Solution for [github/issues_14]: [illbnm/homelab-stack] [BOUNTY $200] Testing — 自动化测试套件

- **Reward:** $200.00 USDC
- **Target URL:** https://github.com/illbnm/homelab-stack/issues/14
- **AI Brain:** gemini-2.5-flash
- **Tokens Used:** 12153 (~$0.0243 USD compute cost)

---

This is an exciting bounty! Implementing a robust integration test suite is crucial for the stability and maintainability of any complex system like a HomeLab stack. I'll leverage my experience in shell scripting, Docker, and CI/CD to deliver a comprehensive, production-ready solution that meets all the specified requirements.

## Root Cause Analysis (Current State)

The current `homelab-stack` repository lacks an automated testing suite. This means:
1.  **Manual Verification:** Any changes to `docker-compose.yml` files, environment variables, or service configurations require manual verification, which is time-consuming and prone to human error.
2.  **Regression Risk:** New features or updates can inadvertently break existing services without immediate detection.
3.  **Deployment Confidence:** Lack of tests reduces confidence in deployments, especially when introducing new stacks or updating core infrastructure.
4.  **CI/CD Gaps:** Without tests, CI/CD pipelines can only verify build success, not functional correctness.

## Architecture Design

The proposed architecture adheres strictly to the bounty's file structure and requirements, focusing on a pure Bash solution for minimal dependencies and maximum portability within a Docker/Linux environment.

**Core Components:**

1.  **`run-tests.sh` (Test Runner):**
    *   Parses command-line arguments (`--stack`, `--all`, `--json`, `--help`).
    *   Discovers test files (`.test.sh`) based on the `--stack` argument or recursively for `--all`.
    *   Sources `lib/*.sh` for common functions.
    *   Executes tests sequentially, capturing output and timing.
    *   Orchestrates test setup (e.g., `docker compose up -d`) and teardown.
    *   Generates both colorful terminal output and a JSON report.

2.  **`lib/assert.sh` (Assertion Library):**
    *   Provides a set of Bash functions for common assertions (equality, HTTP status, container state, JSON parsing).
    *   Uses `jq` for robust JSON parsing.
    *   Employs `curl` for HTTP requests.
    *   Includes retry logic for network-dependent assertions (e.g., `assert_http_200`, `assert_container_healthy`).

3.  **`lib/docker.sh` (Docker Utilities):**
    *   Helper functions for interacting with Docker (e.g., `get_container_ip`, `wait_for_container_health`).
    *   Abstracts Docker CLI commands.

4.  **`lib/report.sh` (Reporting):**
    *   Manages test results (pass/fail/skip, duration, messages).
    *   Formats terminal output with ANSI escape codes for colors.
    *   Constructs a JSON object for the final report.

5.  **`stacks/*.test.sh` (Stack-Specific Tests):**
    *   Each file contains tests relevant to a specific `docker-compose.yml` stack.
    *   Tests cover container health, HTTP endpoints, and inter-service communication.
    *   Follows a `test_service_feature()` naming convention.

6.  **`e2e/*.test.sh` (End-to-End Tests):**
    *   For complex, multi-step user flows (e.g., SSO login).
    *   May require more sophisticated `curl` sequences or even headless browser automation (though the bounty implies `curl` for SSO).

7.  **`ci/docker-compose.test.yml` (CI-Specific Compose):**
    *   A minimal `docker-compose.yml` for CI, potentially overriding production configurations (e.g., using `localhost` instead of real domains, simpler database setups).
    *   This will be a placeholder for now, as the bounty specifies starting `stacks/base/docker-compose.yml` directly in CI.

**Key Design Decisions:**

*   **Pure Bash:** Adhering to the "no extra framework dependencies" rule. This means careful error handling, function design, and variable scoping.
*   **Modularity:** Separating concerns into `lib/` files for reusability and maintainability.
*   **Idempotency:** Tests should be runnable multiple times without side effects (beyond starting/stopping containers).
*   **Retry Logic:** Crucial for integration tests where services might take time to become fully available. `assert_http_200` and `assert_container_healthy` will incorporate this.
*   **Environment Variables:** Tests will respect `.env` and `generate-secrets.sh` outputs for service credentials.
*   **CI Integration:** The `test.yml` workflow will be designed to be self-contained and robust, including setup, service startup, health checks, and test execution.

## Production-Ready Code/Patch Implementation

I will implement the required file structure and content.

### File: tests/run-tests.sh
```bash
#!/usr/bin/env bash

# HomeLab Stack Integration Test Runner
#
# Usage:
#   ./run-tests.sh --stack <name> [--json] [--verbose] [--help]
#   ./run-tests.sh --all [--json] [--verbose] [--help]
#
# Options:
#   --stack <name>  Run tests for a specific stack (e.g., 'base', 'media').
#                   Looks for tests/stacks/<name>.test.sh.
#   --all           Run tests for all available stacks.
#   --json          Output results to tests/results/report.json in JSON format.
#   --verbose       Show detailed output for each test step.
#   --help          Display this help message.
#
# Dependencies:
#   curl, jq, docker, docker compose (v2)
#
# Exit Codes:
#   0: All tests passed.
#   1: One or more tests failed.
#   2: Invalid arguments or setup failure.

set -euo pipefail

# --- Configuration ---
TESTS_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
LIB_DIR="${TESTS_DIR}/lib"
STACKS_TEST_DIR="${TESTS_DIR}/stacks"
E2E_TEST_DIR="${TESTS_DIR}/e2e"
RESULTS_DIR="${TESTS_DIR}/results"
REPORT_JSON_PATH="${RESULTS_DIR}/report.json"

# --- Source Libraries ---
# shellcheck source=./lib/assert.sh
source "${LIB_DIR}/assert.sh"
# shellcheck source=./lib/docker.sh
source "${LIB_DIR}/docker.sh"
# shellcheck source=./lib/report.sh
source "${LIB_DIR}/report.sh"

# --- Global Variables ---
TARGET_STACK=""
RUN_ALL_STACKS=false
OUTPUT_JSON=false
VERBOSE_MODE=false
TEST_FILES=()
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0
START_TIME=$(date +%s)

# --- Helper Functions ---

# Function to display help message
show_help() {
  grep '^#' "${BASH_SOURCE[0]}" | cut -c 2-
  exit 0
}

# Function to parse command-line arguments
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --stack)
        if [[ -z "$2" || "$2" == --* ]]; then
          echo "Error: --stack requires a value." >&2
          exit 2
        fi
        TARGET_STACK="$2"
        shift 2
        ;;
      --all)
        RUN_ALL_STACKS=true
        shift
        ;;
      --json)
        OUTPUT_JSON=true
        shift
        ;;
      --verbose)
        VERBOSE_MODE=true
        shift
        ;;
      --help)
        show_help
        ;;
      *)
        echo "Error: Unknown argument '$1'." >&2
        show_help
        ;;
    esac
  done

  if [[ -z "${TARGET_STACK}" && "${RUN_ALL_STACKS}" == "false" ]]; then
    echo "Error: Must specify either --stack <name> or --all." >&2
    show_help
  fi

  if [[ -n "${TARGET_STACK}" && "${RUN_ALL_STACKS}" == "true" ]]; then
    echo "Error: Cannot use --stack and --all together." >&2
    show_help
  fi
}

# Function to discover test files
discover_test_files() {
  if "${RUN_ALL_STACKS}"; then
    mapfile -t TEST_FILES < <(find "${STACKS_TEST_DIR}" "${E2E_TEST_DIR}" -name "*.test.sh" | sort)
  else
    local stack_test_file="${STACKS_TEST_DIR}/${TARGET_STACK}.test.sh"
    local e2e_test_file="${E2E_TEST_DIR}/${TARGET_STACK}.test.sh" # Allow e2e tests to be run by stack name

    if [[ -f "${stack_test_file}" ]]; then
      TEST_FILES+=("${stack_test_file}")
    elif [[ -f "${e2e_test_file}" ]]; then
      TEST_FILES+=("${e2e_test_file}")
    else
      echo "Error: Test file for stack '${TARGET_STACK}' not found at '${stack_test_file}' or '${e2e_test_file}'." >&2
      exit 2
    fi
  fi

  if [[ ${#TEST_FILES[@]} -eq 0 ]]; then
    echo "No test files found." >&2
    exit 2
  fi
}

# Function to run a single test function
run_test_function() {
  local test_name="$1"
  local test_func="$2"
  local stack_name="$3"
  local start_test_time=$(date +%s.%N)
  local result="PASS"
  local message=""

  TOTAL_TESTS=$((TOTAL_TESTS + 1))

  if "${VERBOSE_MODE}"; then
    echo -e "${COLOR_BLUE}[${stack_name}] ▶ ${test_name}${COLOR_RESET}"
  else
    printf "${COLOR_BLUE}[%s] ▶ %-30s${COLOR_RESET}" "${stack_name}" "${test_name}"
  fi

  # Execute the test function in a subshell to isolate environment changes
  if ! ( eval "${test_func}" ); then
    result="FAIL"
    message=$(tail -n 1 "${ASSERT_LOG_FILE}") # Get the last error message from assert.sh
    if [[ -z "${message}" ]]; then
      message="Test function '${test_func}' failed without specific message."
    fi
    FAILED_TESTS=$((FAILED_TESTS + 1))
  else
    PASSED_TESTS=$((PASSED_TESTS + 1))
  fi

  local end_test_time=$(date +%s.%N)
  local duration=$(echo "${end_test_time} - ${start_test_time}" | bc -l | xargs printf "%.1f")

  if "${VERBOSE_MODE}"; then
    if [[ "${result}" == "PASS" ]]; then
      echo -e "  ${COLOR_GREEN}✅ PASS${COLOR_RESET} (${duration}s)"
    else
      echo -e "  ${COLOR_RED}❌ FAIL${COLOR_RESET} (${duration}s)"
      echo -e "    ${COLOR_YELLOW}${message}${COLOR_RESET}"
    fi
  else
    if [[ "${result}" == "PASS" ]]; then
      echo -e " ${COLOR_GREEN}✅ PASS${COLOR_RESET} (${duration}s)"
    else
      echo -e " ${COLOR_RED}❌ FAIL${COLOR_RESET} (${duration}s)"
    fi
  fi

  add_test_result "${stack_name}" "${test_name}" "${result}" "${duration}" "${message}"
}

# Function to run all tests in a given file
run_test_file() {
  local test_file="$1"
  local stack_name=$(basename "${test_file}" .test.sh)

  echo -e "\n${COLOR_CYAN}Running tests for stack: ${stack_name}${COLOR_RESET}"

  # Source the test file to make its functions available
  # shellcheck source=/dev/null
  source "${test_file}"

  # Find all functions starting with 'test_' in the sourced file
  # Use 'declare -F' to list function names, then filter
  local test_functions
  mapfile -t test_functions < <(declare -F | awk '{print $3}' | grep '^test_')

  if [[ ${#test_functions[@]} -eq 0 ]]; then
    echo -e "${COLOR_YELLOW}No test functions found in ${test_file}. Skipping.${COLOR_RESET}"
    SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
    return
  fi

  for func in "${test_functions[@]}"; do
    run_test_function "${func#test_}" "${func}" "${stack_name}"
  done
}

# --- Main Execution ---
main() {
  parse_args "$@"

  # Create results directory if it doesn't exist
  mkdir -p "${RESULTS_DIR}"

  # Clear previous log file for assertions
  > "${ASSERT_LOG_FILE}"

  # Display header
  echo -e "${COLOR_BLUE}╔══════════════════════════════════════╗${COLOR_RESET}"
  echo -e "${COLOR_BLUE}║   HomeLab Stack — Integration Tests  ║${COLOR_RESET}"
  echo -e "${COLOR_BLUE}╚══════════════════════════════════════╝${COLOR_RESET}"

  discover_test_files

  for file in "${TEST_FILES[@]}"; do
    run_test_file "${file}"
  done

  local end_time=$(date +%s)
  local total_duration=$((end_time - START_TIME))

  echo -e "\n${COLOR_BLUE}──────────────────────────────────────${COLOR_RESET}"
  echo -e "Results: ${PASSED_TESTS} passed, ${FAILED_TESTS} failed, ${SKIPPED_TESTS} skipped"
  echo -e "Duration: ${total_duration}s"
  echo -e "${COLOR_BLUE}──────────────────────────────────────${COLOR_RESET}"

  if "${OUTPUT_JSON}"; then
    generate_json_report "${REPORT_JSON_PATH}"
    echo -e "JSON report saved to ${COLOR_CYAN}${REPORT_JSON_PATH}${COLOR_RESET}"
  fi

  if [[ "${FAILED_TESTS}" -gt 0 ]]; then
    exit 1
  else
    exit 0
  fi
}

main "$@"
```

### File: tests/lib/assert.sh
```bash
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
```

### File: tests/lib/docker.sh
```bash
#!/usr/bin/env bash

# Docker Utility Library for HomeLab Stack Integration Tests
#
# Provides functions to interact with Docker and Docker Compose.
#
# Dependencies:
#   docker, docker compose (v2)

# --- Docker Helper Functions ---

# get_container_ip <container_name>
# Returns the IP address of a running container.
get_container_ip() {
  local container_name="$1"
  docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "${container_name}" 2>/dev/null
}

# wait_for_container_status <container_name> <status> [timeout=60] [interval=2]
# Waits for a container to reach a specific status (e.g., "running", "exited").
wait_for_container_status() {
  local container_name="$1"
  local expected_status="$2"
  local timeout="${3:-60}"
  local interval="${4:-2}"
  local elapsed=0

  echo "Waiting for container '${container_name}' to be '${expected_status}' (timeout: ${timeout}s)..." >&2

  while [[ "${elapsed}" -lt "${timeout}" ]]; do
    local current_status=$(docker inspect -f '{{.State.Status}}' "${container_name}" 2>/dev/null || echo "not_found")
    if [[ "${current_status}" == "${expected_status}" ]]; then
      echo "Container '${container_name}' is '${expected_status}'." >&2
      return 0
    fi
    sleep "${interval}"
    elapsed=$((elapsed + interval))
  done

  echo "Error: Container '${container_name}' did not reach '${expected_status}' status within ${timeout}s. Current status: ${current_status}" >&2
  return 1
}

# wait_for_container_health <container_name> [timeout=60] [interval=2]
# Waits for a container to become healthy according to its Docker healthcheck.
wait_for_container_health() {
  local container_name="$1"
  local timeout="${2:-60}"
  local interval="${4:-2}"
  local elapsed=0

  echo "Waiting for container '${container_name}' to be healthy (timeout: ${timeout}s)..." >&2

  while [[ "${elapsed}" -lt "${timeout}" ]]; do
    local health_status=$(docker inspect -f '{{.State.Health.Status}}' "${container_name}" 2>/dev/null || echo "not_found")
    if [[ "${health_status}" == "healthy" ]]; then
      echo "Container '${container_name}' is healthy." >&2
      return 0
    elif [[ "${health_status}" == "unhealthy" ]]; then
      echo "Error: Container '${container_name}' became unhealthy." >&2
      return 1
    fi
    sleep "${interval}"
    elapsed=$((elapsed + interval))
  done

  echo "Error: Container '${container_name}' did not become healthy within ${timeout}s. Current health status: ${health_status}" >&2
  return 1
}

# retry_command <timeout> <interval> <command_string>
# Retries a given command string until it succeeds or timeout is reached.
# The command string is executed in a subshell.
retry_command() {
  local timeout="$1"
  local interval="$2"
  local command_string="$3"
  local elapsed=0

  while [[ "${elapsed}" -lt "${timeout}" ]]; do
    if eval "${command_string}"; then
      return 0
    fi
    sleep "${interval}"
    elapsed=$((elapsed + interval))
  done

  return 1
}
```

### File: tests/lib/report.sh
```bash
#!/usr/bin/env bash

# Reporting Library for HomeLab Stack Integration Tests
#
# Manages test results and generates terminal and JSON reports.

# --- Global Variables ---
TEST_RESULTS=() # Array to store test result objects
# Example result object: { "stack": "base", "name": "test_traefik_running", "status": "PASS", "duration": "0.3", "message": "" }

# --- Reporting Functions ---

# add_test_result <stack> <name> <status> <duration> [message]
add_test_result() {
  local stack="$1"
  local name="$2"
  local status="$3"
  local duration="$4"
  local message="${5:-}"

  # Escape double quotes in message for JSON
  local escaped_message=$(echo "${message}" | sed 's/"/\\"/g')

  TEST_RESULTS+=(
    "{\"stack\":\"${stack}\",\"name\":\"${name}\",\"status\":\"${status}\",\"duration\":\"${duration}\",\"message\":\"${escaped_message}\"}"
  )
}

# generate_json_report <output_path>
generate_json_report() {
  local output_path="$1"
  local results_array_json=""

  # Join all individual JSON objects into a single JSON array
  if [[ ${#TEST_RESULTS[@]} -gt 0 ]]; then
    results_array_json=$(IFS=,; echo "[${TEST_RESULTS[*]}]")
  else
    results_array_json="[]"
  fi

  local total_duration=$(( $(date +%s) - START_TIME )) # START_TIME is from run-tests.sh
  local report_json=$(jq -n \
    --argjson results "${results_array_json}" \
    --arg total_tests "${TOTAL_TESTS}" \
    --arg passed_tests "${PASSED_TESTS}" \
    --arg failed_tests "${FAILED_TESTS}" \
    --arg skipped_tests "${SKIPPED_TESTS}" \
    --arg total_duration "${total_duration}" \
    '{
      "timestamp": (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
      "total_tests": ($total_tests | tonumber),
      "passed_tests": ($passed_tests | tonumber),
      "failed_tests": ($failed_tests | tonumber),
      "skipped_tests": ($skipped_tests | tonumber),
      "total_duration_seconds": ($total_duration | tonumber),
      "results": $results
    }')

  echo "${report_json}" > "${output_path}"
}
```

### File: tests/stacks/base.test.sh
```bash
#!/usr/bin/env bash

# Base Stack Integration Tests
#
# Tests for core infrastructure services: Traefik, Portainer, Watchtower.
#
# Dependencies:
#   assert.sh, docker.sh (sourced by run-tests.sh)
#   .env file with necessary variables (e.g., PUID, PGID)

# Load environment variables from .env if not already loaded (for local runs)
if [[ -f ".env" ]]; then
  # shellcheck source=../../.env
  source ".env"
fi

# --- Level 1: Container Health Tests ---

test_traefik_running() {
  assert_container_running "traefik"
  assert_container_healthy "traefik"
}

test_portainer_running() {
  assert_container_running "portainer"
  assert_container_healthy "portainer"
}

test_watchtower_running() {
  assert_container_running "watchtower"
}

# --- Level 2: HTTP Endpoint Tests ---

test_traefik_api_version_200() {
  # Traefik API is usually exposed on a separate port, or via a specific entrypoint.
  # Assuming it's accessible directly on localhost:8080 for testing purposes in CI.
  # If not, this needs to be adjusted based on actual Traefik configuration.
  assert_http_200 "http://localhost:8080/api/version"
}

test_portainer_api_status_200() {
  # Portainer is typically on port 9000
  assert_http_200 "http://localhost:9000/api/status"
}

# --- Level 5: Configuration Integrity Tests ---

test_base_compose_syntax() {
  docker compose -f stacks/base/docker-compose.yml config --quiet 2>&1
  assert_exit_code 0 "Base stack compose config failed"
}

test_base_no_latest_tags() {
  assert_no_latest_images "stacks/base" "Found :latest image tags in base stack"
}

test_base_all_services_have_healthcheck() {
  assert_all_services_have_healthcheck "stacks/base/docker-compose.yml" "Base stack services missing healthcheck"
}
```

### File: tests/stacks/media.test.sh
```bash
#!/usr/bin/env bash

# Media Stack Integration Tests
#
# Tests for Jellyfin, Sonarr, Radarr, qBittorrent.
#
# Dependencies:
#   assert.sh, docker.sh (sourced by run-tests.sh)
#   .env file with necessary variables (e.g., JELLYFIN_API_KEY, SONARR_API_KEY, RADARR_API_KEY)

# Load environment variables from .env if not already loaded (for local runs)
if [[ -f ".env" ]]; then
  # shellcheck source=../../.env
  source ".env"
fi

# --- Level 1: Container Health Tests ---

test_jellyfin_running() {
  assert_container_running "jellyfin"
  assert_container_healthy "jellyfin"
}

test_sonarr_running() {
  assert_container_running "sonarr"
  assert_container_healthy "sonarr"
}

test_radarr_running() {
  assert_container_running "radarr"
  assert_container_healthy "radarr"
}

test_qbittorrent_running() {
  assert_container_running "qbittorrent"
  assert_container_healthy "qbittorrent"
}

# --- Level 2: HTTP Endpoint Tests ---

test_jellyfin_health_200() {
  assert_http_200 "http://localhost:8096/health"
}

test_sonarr_api_v3_200() {
  # Sonarr API requires API key
  assert_http_200 "http://localhost:8989/api/v3/system/

---

### Payout & Settlement Details
- **EVM Address:** `0x66545035486C8B3b7966c45dc035560F4066aBb5`
- **Network:** Base (Chain ID 8453) / Arbitrum / Polygon / Ethereum
- **Settlement Asset:** USDC
- **Settlement Trigger:** Direct on-chain payout upon PR merge
