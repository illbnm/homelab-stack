#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Integration Test Runner
# =============================================================================
# Main entry point for running integration tests.
#
# Usage:
#   ./tests/run-tests.sh --all                  # Run all stack tests
#   ./tests/run-tests.sh --stack base           # Run tests for a specific stack
#   ./tests/run-tests.sh --stack base,media     # Run tests for multiple stacks
#   ./tests/run-tests.sh --e2e                  # Run end-to-end tests
#   ./tests/run-tests.sh --config               # Run configuration integrity tests only
#   ./tests/run-tests.sh --json                 # Enable JSON report output
#   ./tests/run-tests.sh --help                 # Show help
#
# Dependencies: curl, jq, docker, docker compose (v2)
# =============================================================================
set -euo pipefail
IFS=$'\n\t'

# ---------------------------------------------------------------------------
# Resolve paths
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# ---------------------------------------------------------------------------
# Source libraries
# ---------------------------------------------------------------------------
# shellcheck source=lib/report.sh
source "${SCRIPT_DIR}/lib/report.sh"
# shellcheck source=lib/assert.sh
source "${SCRIPT_DIR}/lib/assert.sh"
# shellcheck source=lib/docker.sh
source "${SCRIPT_DIR}/lib/docker.sh"

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
readonly VERSION="1.0.0"
readonly AVAILABLE_STACKS="base media storage monitoring network productivity ai sso databases notifications"
readonly RESULTS_DIR="${SCRIPT_DIR}/results"

# ---------------------------------------------------------------------------
# CLI state
# ---------------------------------------------------------------------------
RUN_ALL=false
RUN_E2E=false
RUN_CONFIG=false
JSON_OUTPUT=false
SELECTED_STACKS=()
VERBOSE=false

# ---------------------------------------------------------------------------
# Usage / help
# ---------------------------------------------------------------------------
show_help() {
  cat <<EOF
HomeLab Stack — Integration Test Runner v${VERSION}

USAGE:
  ./tests/run-tests.sh [OPTIONS]

OPTIONS:
  --all                 Run tests for ALL implemented stacks
  --stack <name>        Run tests for a specific stack (comma-separated for multiple)
                        Available stacks: ${AVAILABLE_STACKS}
  --e2e                 Run end-to-end tests (SSO flow, backup-restore)
  --config              Run configuration integrity tests only
  --json                Generate JSON report to tests/results/report.json
  --verbose             Show verbose output (debug info)
  --help, -h            Show this help message
  --version, -v         Show version

EXAMPLES:
  # Run all tests
  ./tests/run-tests.sh --all

  # Test only the base stack
  ./tests/run-tests.sh --stack base

  # Test base and databases stacks with JSON report
  ./tests/run-tests.sh --stack base,databases --json

  # Run only configuration integrity checks
  ./tests/run-tests.sh --config

  # Run everything including E2E
  ./tests/run-tests.sh --all --e2e --json

DEPENDENCIES:
  Required: curl, jq, docker, docker compose (v2)
  All tests are pure bash — no additional frameworks needed.

EXIT CODES:
  0   All tests passed
  1   One or more tests failed
  2   Invalid arguments or missing dependencies
EOF
}

show_version() {
  echo "HomeLab Stack Test Runner v${VERSION}"
}

# ---------------------------------------------------------------------------
# Dependency checks
# ---------------------------------------------------------------------------
check_dependencies() {
  local missing=()

  for cmd in curl jq docker; do
    if ! command -v "${cmd}" &>/dev/null; then
      missing+=("${cmd}")
    fi
  done

  # Check docker compose v2
  if ! docker compose version &>/dev/null; then
    missing+=("docker-compose-v2")
  fi

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo -e "${_CLR_RED}[ERROR]${_CLR_NC} Missing required dependencies: ${missing[*]}"
    echo "Install them before running tests."
    exit 2
  fi
}

# ---------------------------------------------------------------------------
# Source .env
# ---------------------------------------------------------------------------
load_env() {
  if [[ -f "${PROJECT_ROOT}/.env" ]]; then
    set -a
    # shellcheck source=/dev/null
    source "${PROJECT_ROOT}/.env"
    set +a
  elif [[ -f "${PROJECT_ROOT}/.env.example" ]]; then
    echo -e "${_CLR_YELLOW}[WARN]${_CLR_NC} No .env found, using .env.example"
    set -a
    # shellcheck source=/dev/null
    source "${PROJECT_ROOT}/.env.example"
    set +a
  fi
}

# ---------------------------------------------------------------------------
# Run a test file
# ---------------------------------------------------------------------------
run_test_file() {
  local test_file="$1"
  local stack_name="$2"

  if [[ ! -f "${test_file}" ]]; then
    echo -e "${_CLR_YELLOW}[WARN]${_CLR_NC} Test file not found: ${test_file} — skipping"
    return 0
  fi

  report_stack_start "${stack_name}"

  # Capture functions before sourcing to detect new test_ functions
  local before_funcs
  before_funcs=$(declare -F | awk '{print $3}' | grep "^test_" | sort || true)

  # Source the test file (it defines test_* functions)
  # shellcheck source=/dev/null
  source "${test_file}"

  # Discover only NEW test_* functions from this file
  local after_funcs
  after_funcs=$(declare -F | awk '{print $3}' | grep "^test_" | sort || true)

  local test_functions
  if [[ -z "${before_funcs}" ]]; then
    test_functions="${after_funcs}"
  else
    test_functions=$(comm -13 <(echo "${before_funcs}") <(echo "${after_funcs}") || true)
  fi

  for func in ${test_functions}; do
    report_test_start "${func}"

    # Run the test function, capture failures without exiting
    if "${func}"; then
      : # pass — result already recorded by assert
    else
      : # fail — result already recorded by assert
    fi

    # Unset the function so it doesn't carry over to the next test file
    unset -f "${func}" 2>/dev/null || true
  done
}

# ---------------------------------------------------------------------------
# Run configuration integrity tests (always available)
# ---------------------------------------------------------------------------
run_config_tests() {
  report_stack_start "config"

  # Test: all compose files have valid syntax
  report_test_start "compose_syntax"
  local compose_files
  compose_files=$(find "${PROJECT_ROOT}/stacks" -name 'docker-compose.yml' -o -name 'docker-compose.*.yml' 2>/dev/null || echo "")

  if [[ -z "${compose_files}" ]]; then
    CURRENT_TEST_NAME="compose_syntax"
    CURRENT_STACK="config"
    _assert_skip "No compose files found in stacks/"
  else
    local all_valid=true
    while IFS= read -r f; do
      if [[ -n "${f}" ]]; then
        CURRENT_TEST_NAME="compose_syntax($(basename "$(dirname "${f}")"))"
        CURRENT_STACK="config"
        if docker compose -f "${f}" config --quiet 2>/dev/null; then
          _assert_pass "Compose config valid"
        else
          _assert_fail "Compose file has invalid syntax: ${f}"
          all_valid=false
        fi
      fi
    done <<< "${compose_files}"
  fi

  # Test: no :latest image tags
  report_test_start "no_latest_tags"
  CURRENT_TEST_NAME="no_latest_tags"
  CURRENT_STACK="config"
  local latest_count
  latest_count=$(grep -r 'image:.*:latest$' "${PROJECT_ROOT}/stacks/" --include='*.yml' --include='*.yaml' 2>/dev/null | wc -l || echo "0")
  latest_count=$(echo "${latest_count}" | tr -d '[:space:]')

  if [[ "${latest_count}" -eq 0 ]]; then
    _assert_pass "No ':latest' image tags found"
  else
    local offenders
    offenders=$(grep -r 'image:.*:latest$' "${PROJECT_ROOT}/stacks/" --include='*.yml' --include='*.yaml' 2>/dev/null || true)
    _assert_fail "Found ${latest_count} ':latest' image tags:\n${offenders}"
  fi

  # Test: all services have healthcheck
  report_test_start "all_healthchecks"
  compose_files=$(find "${PROJECT_ROOT}/stacks" -name 'docker-compose.yml' 2>/dev/null || echo "")

  if [[ -z "${compose_files}" ]]; then
    CURRENT_TEST_NAME="all_healthchecks"
    CURRENT_STACK="config"
    _assert_skip "No compose files found"
  else
    while IFS= read -r f; do
      if [[ -n "${f}" ]]; then
        CURRENT_TEST_NAME="healthcheck($(basename "$(dirname "${f}")"))"
        CURRENT_STACK="config"
        assert_all_services_have_healthcheck "${f}" || true
      fi
    done <<< "${compose_files}"
  fi

  # Test: no hardcoded passwords in compose files
  report_test_start "no_hardcoded_passwords"
  CURRENT_TEST_NAME="no_hardcoded_passwords"
  CURRENT_STACK="config"
  local hardcoded_count
  hardcoded_count=$(grep -rE '(password|PASSWORD|secret|SECRET)\s*[:=]\s*["\x27]?[a-zA-Z0-9]{8,}["\x27]?' \
    "${PROJECT_ROOT}/stacks/" --include='*.yml' --include='*.yaml' \
    2>/dev/null | grep -v '\${' | grep -v 'example' | grep -v '#' | wc -l || echo "0")
  hardcoded_count=$(echo "${hardcoded_count}" | tr -d '[:space:]')

  if [[ "${hardcoded_count}" -eq 0 ]]; then
    _assert_pass "No hardcoded passwords detected"
  else
    _assert_fail "Possible hardcoded passwords found (${hardcoded_count} occurrences)"
  fi

  # Test: .env.example exists for stacks that have docker-compose.yml
  report_test_start "env_example_exists"
  compose_files=$(find "${PROJECT_ROOT}/stacks" -name 'docker-compose.yml' 2>/dev/null || echo "")

  while IFS= read -r f; do
    if [[ -n "${f}" ]]; then
      local stack_dir
      stack_dir=$(dirname "${f}")
      local stack_name
      stack_name=$(basename "${stack_dir}")
      CURRENT_TEST_NAME="env_example(${stack_name})"
      CURRENT_STACK="config"

      if [[ -f "${stack_dir}/.env.example" ]] || [[ -f "${PROJECT_ROOT}/.env.example" ]]; then
        _assert_pass ".env.example found"
      else
        _assert_fail "No .env.example found for stack '${stack_name}'"
      fi
    fi
  done <<< "${compose_files}"

  # =========================================================================
  # China Network Compatibility Tests (Level 2)
  # =========================================================================

  # Test: CN image replacement script (dry-run)
  report_test_start "cn_image_replacement"
  CURRENT_TEST_NAME="cn_image_replacement"
  CURRENT_STACK="config"

  local localize_script="${PROJECT_ROOT}/scripts/localize-images.sh"
  if [[ -f "${localize_script}" ]]; then
    local cn_rc=0
    bash "${localize_script}" --cn --dry-run &>/dev/null || cn_rc=$?
    assert_exit_code "${cn_rc}" 0 "localize-images.sh --cn --dry-run should succeed"

    if [[ "${cn_rc}" -eq 0 ]]; then
      assert_no_gcr_images "${PROJECT_ROOT}/stacks/"
    fi

    # Restore to original state
    bash "${localize_script}" --restore &>/dev/null || true
  else
    _assert_skip "localize-images.sh not found — CN image replacement test skipped"
  fi

  # Test: Docker mirror config script (dry-run)
  report_test_start "docker_mirror_config"
  CURRENT_TEST_NAME="docker_mirror_config"
  CURRENT_STACK="config"

  local mirror_script="${PROJECT_ROOT}/scripts/setup-cn-mirrors.sh"
  if [[ -f "${mirror_script}" ]]; then
    local mirror_rc=0
    bash "${mirror_script}" --dry-run &>/dev/null || mirror_rc=$?

    if [[ "${mirror_rc}" -eq 0 ]]; then
      if [[ -f "/tmp/daemon.json.test" ]]; then
        assert_file_contains "/tmp/daemon.json.test" "registry-mirrors"
        rm -f "/tmp/daemon.json.test" 2>/dev/null || true
      else
        _assert_skip "daemon.json.test not generated (dry-run may use different path)"
      fi
    else
      _assert_fail "setup-cn-mirrors.sh --dry-run failed (exit code: ${mirror_rc})"
    fi
  else
    _assert_skip "setup-cn-mirrors.sh not found — CN mirror config test skipped"
  fi

  # Test: No GCR images that would be blocked in China
  report_test_start "no_gcr_images"
  CURRENT_TEST_NAME="no_gcr_images"
  CURRENT_STACK="config"
  if [[ -d "${PROJECT_ROOT}/stacks" ]]; then
    assert_no_gcr_images "${PROJECT_ROOT}/stacks/"
  else
    _assert_skip "stacks/ directory not found"
  fi
}

# ---------------------------------------------------------------------------
# Parse CLI arguments
# ---------------------------------------------------------------------------
parse_args() {
  if [[ $# -eq 0 ]]; then
    show_help
    exit 0
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --all)
        RUN_ALL=true
        shift
        ;;
      --stack)
        if [[ -z "${2:-}" ]]; then
          echo -e "${_CLR_RED}[ERROR]${_CLR_NC} --stack requires a stack name"
          exit 2
        fi
        IFS=',' read -ra stacks <<< "$2"
        for s in "${stacks[@]}"; do
          s=$(echo "${s}" | tr -d '[:space:]')
          if echo "${AVAILABLE_STACKS}" | grep -qw "${s}"; then
            SELECTED_STACKS+=("${s}")
          else
            echo -e "${_CLR_RED}[ERROR]${_CLR_NC} Unknown stack: '${s}'"
            echo "Available stacks: ${AVAILABLE_STACKS}"
            exit 2
          fi
        done
        shift 2
        ;;
      --e2e)
        RUN_E2E=true
        shift
        ;;
      --config)
        RUN_CONFIG=true
        shift
        ;;
      --json)
        JSON_OUTPUT=true
        shift
        ;;
      --verbose)
        VERBOSE=true
        shift
        ;;
      --help|-h)
        show_help
        exit 0
        ;;
      --version|-v)
        show_version
        exit 0
        ;;
      *)
        echo -e "${_CLR_RED}[ERROR]${_CLR_NC} Unknown option: $1"
        echo "Run './tests/run-tests.sh --help' for usage"
        exit 2
        ;;
    esac
  done
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  parse_args "$@"
  check_dependencies
  load_env

  # Initialize report
  report_init "${RESULTS_DIR}"
  report_set_json_output "${JSON_OUTPUT}"

  # Always run config tests if --config or --all
  if [[ "${RUN_CONFIG}" == true ]] || [[ "${RUN_ALL}" == true ]]; then
    run_config_tests
  fi

  # Determine which stacks to test
  local stacks_to_test=()

  if [[ "${RUN_ALL}" == true ]]; then
    # AVAILABLE_STACKS is space-separated; override IFS for read since global IFS is \n\t
    IFS=' ' read -ra stacks_to_test <<< "${AVAILABLE_STACKS}"
  else
    stacks_to_test=("${SELECTED_STACKS[@]+"${SELECTED_STACKS[@]}"}")
  fi

  # Run stack tests
  for stack in ${stacks_to_test[@]+"${stacks_to_test[@]}"}; do
    local test_file="${SCRIPT_DIR}/stacks/${stack}.test.sh"
    run_test_file "${test_file}" "${stack}"
  done

  # Run E2E tests if requested
  if [[ "${RUN_E2E}" == true ]]; then
    local e2e_dir="${SCRIPT_DIR}/e2e"
    if [[ -d "${e2e_dir}" ]]; then
      for test_file in "${e2e_dir}"/*.test.sh; do
        if [[ -f "${test_file}" ]]; then
          local e2e_name
          e2e_name=$(basename "${test_file}" .test.sh)
          run_test_file "${test_file}" "e2e/${e2e_name}"
        fi
      done
    fi
  fi

  # Print summary (returns non-zero if there are failures)
  report_summary
}

main "$@"
