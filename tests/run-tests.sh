#!/usr/bin/env bash
# =============================================================================
# HomeLab Integration Test Runner
#
# Usage:
#   ./tests/run-tests.sh --all              # Run all stack tests
#   ./tests/run-tests.sh --stack base       # Run tests for a single stack
#   ./tests/run-tests.sh --stack base,media # Run tests for multiple stacks
#   ./tests/run-tests.sh --e2e              # Run E2E tests only
#   ./tests/run-tests.sh --json             # Enable JSON report output
#   ./tests/run-tests.sh --help             # Show help
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export REPO_ROOT="${REPO_ROOT:-$(cd "${SCRIPT_DIR}/.." && pwd)}"
export REPORT_JSON_FILE="${SCRIPT_DIR}/results/report.json"

# shellcheck source=tests/lib/report.sh
source "${SCRIPT_DIR}/lib/report.sh"
# shellcheck source=tests/lib/assert.sh
source "${SCRIPT_DIR}/lib/assert.sh"
# shellcheck source=tests/lib/docker.sh
source "${SCRIPT_DIR}/lib/docker.sh"
# shellcheck source=tests/lib/wait-healthy.sh
source "${SCRIPT_DIR}/lib/wait-healthy.sh"

# ---------------------------------------------------------------------------
# Available stacks and E2E tests
# ---------------------------------------------------------------------------
ALL_STACKS=(
  base
  databases
  sso
  monitoring
  media
  storage
  network
  productivity
  ai
  notifications
)

E2E_TESTS=(
  sso-flow
  backup-restore
)

# ---------------------------------------------------------------------------
# CLI argument parsing
# ---------------------------------------------------------------------------
SELECTED_STACKS=()
RUN_E2E=false
JSON_OUTPUT=false
SHOW_HELP=false

usage() {
  cat <<'USAGE'
HomeLab Integration Test Runner

Usage:
  run-tests.sh [options]

Options:
  --all               Run all stack tests and E2E tests
  --stack <name,...>   Run tests for specific stack(s), comma-separated
  --e2e               Run E2E tests (sso-flow, backup-restore)
  --json              Write JSON report to tests/results/report.json
  --help              Show this help message

Available stacks:
  base, databases, sso, monitoring, media, storage,
  network, productivity, ai, notifications

E2E tests:
  sso-flow, backup-restore

Examples:
  run-tests.sh --all
  run-tests.sh --stack base --json
  run-tests.sh --stack monitoring,media
  run-tests.sh --e2e --json
USAGE
}

while [[ $# -gt 0 ]]; do
  case "${1}" in
    --all)
      SELECTED_STACKS=("${ALL_STACKS[@]}")
      RUN_E2E=true
      shift
      ;;
    --stack)
      if [[ -z "${2:-}" ]]; then
        echo "ERROR: --stack requires a stack name" >&2
        exit 1
      fi
      IFS=',' read -ra stacks <<< "${2}"
      SELECTED_STACKS+=("${stacks[@]}")
      shift 2
      ;;
    --e2e)
      RUN_E2E=true
      shift
      ;;
    --json)
      JSON_OUTPUT=true
      shift
      ;;
    --help|-h)
      SHOW_HELP=true
      shift
      ;;
    *)
      echo "ERROR: unknown option '${1}'" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ "${SHOW_HELP}" == true ]]; then
  usage
  exit 0
fi

if [[ ${#SELECTED_STACKS[@]} -eq 0 ]] && [[ "${RUN_E2E}" == false ]]; then
  echo "ERROR: specify --all, --stack <name>, or --e2e" >&2
  usage
  exit 1
fi

# ---------------------------------------------------------------------------
# Preflight checks
# ---------------------------------------------------------------------------
preflight() {
  local missing=()

  command -v docker >/dev/null 2>&1 || missing+=("docker")
  command -v curl >/dev/null 2>&1   || missing+=("curl")
  command -v jq >/dev/null 2>&1     || missing+=("jq")

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "ERROR: missing required tools: ${missing[*]}" >&2
    exit 1
  fi

  # Verify docker is accessible
  if ! docker info >/dev/null 2>&1; then
    echo "ERROR: cannot connect to Docker daemon" >&2
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Run a stack test file
# ---------------------------------------------------------------------------
run_stack_test() {
  local stack="${1}"
  local test_file="${SCRIPT_DIR}/stacks/${stack}.test.sh"

  if [[ ! -f "${test_file}" ]]; then
    skip_test "${stack}" "all" "test file not found: ${test_file}"
    return 0
  fi

  # Source and run the test function
  # shellcheck source=/dev/null
  source "${test_file}"
  local fn="test_${stack//-/_}"

  if declare -f "${fn}" >/dev/null 2>&1; then
    "${fn}" || true
  else
    echo "WARN: function '${fn}' not found in ${test_file}" >&2
  fi
}

# ---------------------------------------------------------------------------
# Run an E2E test file
# ---------------------------------------------------------------------------
run_e2e_test() {
  local test_name="${1}"
  local test_file="${SCRIPT_DIR}/e2e/${test_name}.test.sh"

  if [[ ! -f "${test_file}" ]]; then
    skip_test "e2e" "${test_name}" "test file not found: ${test_file}"
    return 0
  fi

  # shellcheck source=/dev/null
  source "${test_file}"
  local fn="test_${test_name//-/_}"

  if declare -f "${fn}" >/dev/null 2>&1; then
    "${fn}" || true
  else
    echo "WARN: function '${fn}' not found in ${test_file}" >&2
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  preflight
  report_header "HomeLab Integration Tests"

  # Run selected stack tests
  for stack in "${SELECTED_STACKS[@]}"; do
    run_stack_test "${stack}"
  done

  # Run E2E tests
  if [[ "${RUN_E2E}" == true ]]; then
    for e2e in "${E2E_TESTS[@]}"; do
      run_e2e_test "${e2e}"
    done
  fi

  report_footer

  # JSON output
  if [[ "${JSON_OUTPUT}" == true ]]; then
    report_json_write "${REPORT_JSON_FILE}"
  fi

  # Exit with failure if any tests failed
  if [[ ${_REPORT_TOTAL_FAIL} -gt 0 ]]; then
    exit 1
  fi
}

main
