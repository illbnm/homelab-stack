#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Integration Test Runner
#
# Usage:
#   ./tests/run-tests.sh                    # Run all tests
#   ./tests/run-tests.sh --stack base       # Run tests for a specific stack
#   ./tests/run-tests.sh --stack monitoring --stack media
#   ./tests/run-tests.sh --all              # Run all tests (explicit)
#   ./tests/run-tests.sh --e2e              # Run end-to-end tests only
#   ./tests/run-tests.sh --level 1          # Run only Level 1 tests
#   ./tests/run-tests.sh --json report.json # Write JSON report to file
#   ./tests/run-tests.sh --help             # Show this help
# =============================================================================
set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$TESTS_DIR/.."

# Source libraries
source "$TESTS_DIR/lib/assert.sh"
source "$TESTS_DIR/lib/docker.sh"
source "$TESTS_DIR/lib/report.sh"

# Load environment if available
for envfile in "$BASE_DIR/.env" "$BASE_DIR/config/.env"; do
  [[ -f "$envfile" ]] && source "$envfile" && break
done

# Export BASE_DIR and TESTS_DIR for test files
export BASE_DIR TESTS_DIR

# ---------------------------------------------------------------------------
# Available stacks and their test files
# ---------------------------------------------------------------------------
declare -A STACK_TESTS=(
  [base]="$TESTS_DIR/stacks/base.test.sh"
  [media]="$TESTS_DIR/stacks/media.test.sh"
  [storage]="$TESTS_DIR/stacks/storage.test.sh"
  [monitoring]="$TESTS_DIR/stacks/monitoring.test.sh"
  [network]="$TESTS_DIR/stacks/network.test.sh"
  [productivity]="$TESTS_DIR/stacks/productivity.test.sh"
  [ai]="$TESTS_DIR/stacks/ai.test.sh"
  [sso]="$TESTS_DIR/stacks/sso.test.sh"
  [databases]="$TESTS_DIR/stacks/databases.test.sh"
  [notifications]="$TESTS_DIR/stacks/notifications.test.sh"
)

declare -a E2E_TESTS=(
  "$TESTS_DIR/e2e/sso-flow.test.sh"
  "$TESTS_DIR/e2e/backup-restore.test.sh"
)

# Default run order (respects startup dependency order)
STACK_ORDER=(base databases sso monitoring network storage media productivity ai notifications)

# ---------------------------------------------------------------------------
# CLI parsing
# ---------------------------------------------------------------------------
SELECTED_STACKS=()
RUN_E2E=false
RUN_ALL=true
TEST_LEVEL=0  # 0 = all levels
JSON_OUTPUT=""

usage() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --stack <name>   Run tests for a specific stack (repeatable)"
  echo "  --all            Run all stack tests (default)"
  echo "  --e2e            Run end-to-end tests"
  echo "  --level <1-4>    Run only tests at this level"
  echo "  --json <file>    Write JSON report to file"
  echo "  --help           Show this help"
  echo ""
  echo "Available stacks:"
  printf "  %s\n" "${STACK_ORDER[@]}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stack)
      RUN_ALL=false
      SELECTED_STACKS+=("$2")
      shift 2
      ;;
    --all)
      RUN_ALL=true
      shift
      ;;
    --e2e)
      RUN_ALL=false
      RUN_E2E=true
      shift
      ;;
    --level)
      TEST_LEVEL="$2"
      shift 2
      ;;
    --json)
      JSON_OUTPUT="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

# Export test level for test files to use
export TEST_LEVEL

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
preflight() {
  local ok=true

  if ! command -v docker &>/dev/null; then
    echo "ERROR: docker is not installed or not in PATH"
    ok=false
  fi

  if ! docker info &>/dev/null; then
    echo "ERROR: docker daemon is not running"
    ok=false
  fi

  if ! command -v curl &>/dev/null; then
    echo "ERROR: curl is not installed"
    ok=false
  fi

  if ! command -v jq &>/dev/null; then
    echo "WARNING: jq is not installed — JSON assertions will be skipped"
  fi

  if ! command -v nc &>/dev/null; then
    echo "WARNING: nc (netcat) is not installed — port checks will fail"
  fi

  $ok || exit 1
}

# ---------------------------------------------------------------------------
# Run a test file
# ---------------------------------------------------------------------------
run_test_file() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "WARNING: test file not found: $file"
    return
  fi
  source "$file"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  preflight
  report_start

  if $RUN_ALL; then
    # Run all stacks in dependency order
    for stack in "${STACK_ORDER[@]}"; do
      local test_file="${STACK_TESTS[$stack]:-}"
      if [[ -n "$test_file" && -f "$test_file" ]]; then
        run_test_file "$test_file"
      fi
    done
    # Also run e2e tests when running all
    if [[ "$TEST_LEVEL" -eq 0 || "$TEST_LEVEL" -ge 4 ]]; then
      for e2e_file in "${E2E_TESTS[@]}"; do
        if [[ -f "$e2e_file" ]]; then
          run_test_file "$e2e_file"
        fi
      done
    fi
  else
    # Run selected stacks
    for stack in "${SELECTED_STACKS[@]}"; do
      local test_file="${STACK_TESTS[$stack]:-}"
      if [[ -z "$test_file" ]]; then
        echo "ERROR: unknown stack '${stack}'"
        usage
        exit 1
      fi
      run_test_file "$test_file"
    done
    # Run e2e if requested
    if $RUN_E2E; then
      for e2e_file in "${E2E_TESTS[@]}"; do
        if [[ -f "$e2e_file" ]]; then
          run_test_file "$e2e_file"
        fi
      done
    fi
  fi

  report_exit "$JSON_OUTPUT"
}

main
