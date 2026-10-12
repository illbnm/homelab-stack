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
