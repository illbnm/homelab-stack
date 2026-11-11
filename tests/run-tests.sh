#!/usr/bin/env bash
# ==============================================================================
# tests/run-tests.sh — Unified Test Runner for Homelab Stack
# Supports: --stack <name>, --all, --e2e, --static, --json <file>, --help
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$ROOT_DIR"

# shellcheck source=tests/lib/assert.sh
source "${SCRIPT_DIR}/lib/assert.sh"
# shellcheck source=tests/lib/docker.sh
source "${SCRIPT_DIR}/lib/docker.sh"
# shellcheck source=tests/lib/wait-healthy.sh
source "${SCRIPT_DIR}/lib/wait-healthy.sh"
# shellcheck source=tests/lib/report.sh
source "${SCRIPT_DIR}/lib/report.sh"

TARGET_STACK=""
RUN_ALL=false
RUN_E2E=false
JSON_REPORT=""
export HOMELAB_TEST_STATIC="${HOMELAB_TEST_STATIC:-true}"

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --stack <name>    Run tests for a single stack (base, sso, monitoring, media, photos, cloud, git, ai, network, security)
  --all             Run all stack and E2E tests
  --e2e             Run E2E test suites (sso-flow, backup-restore)
  --live            Run against live Docker containers (disables static mode)
  --static          Run static config/compose/assertion validation (default in CI without Docker daemon)
  --json <path>     Write JSON test report to <path>
  --help            Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stack)
      TARGET_STACK="$2"
      shift 2
      ;;
    --all)
      RUN_ALL=true
      shift
      ;;
    --e2e)
      RUN_E2E=true
      shift
      ;;
    --live)
      export HOMELAB_TEST_STATIC=false
      shift
      ;;
    --static)
      export HOMELAB_TEST_STATIC=true
      shift
      ;;
    --json)
      JSON_REPORT="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "[ERROR] Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$TARGET_STACK" ]] && [[ "$RUN_ALL" == "false" ]] && [[ "$RUN_E2E" == "false" ]]; then
  RUN_ALL=true
fi

run_stack_test() {
  local stack="$1"
  local test_script="${SCRIPT_DIR}/stacks/${stack}.test.sh"
  if [[ ! -f "$test_script" ]]; then
    echo "[ERROR] Stack test not found: ${test_script}" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi
  echo ">>> Running stack test: ${stack}"
  # shellcheck disable=SC1090
  source "$test_script"
}

if [[ -n "$TARGET_STACK" ]]; then
  run_stack_test "$TARGET_STACK"
fi

if [[ "$RUN_ALL" == "true" ]]; then
  for stack in base sso monitoring media photos cloud git ai network security; do
    if [[ -f "${SCRIPT_DIR}/stacks/${stack}.test.sh" ]]; then
      run_stack_test "$stack"
    fi
  done
  RUN_E2E=true
fi

if [[ "$RUN_E2E" == "true" ]]; then
  for e2e_script in "${SCRIPT_DIR}"/e2e/*.test.sh; do
    if [[ -f "$e2e_script" ]]; then
      echo ">>> Running E2E test: $(basename "$e2e_script")"
      # shellcheck disable=SC1090
      source "$e2e_script"
    fi
  done
fi

print_test_summary
if [[ -n "$JSON_REPORT" ]]; then
  write_json_report "$JSON_REPORT"
fi

[[ "${TESTS_FAILED:-0}" -eq 0 ]]
