#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Integration Test Runner
# Runs integration tests for one or all stacks.
#
# Usage:
#   ./tests/run-tests.sh                  # Run all tests
#   ./tests/run-tests.sh --stack sso      # Run SSO tests only
#   ./tests/run-tests.sh --stack base,storage  # Run specific stacks
#   ./tests/run-tests.sh --ci             # CI mode (uses test compose, no domains)
#   ./tests/run-tests.sh --json           # JSON output only
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

# Load .env
if [ -f "$ROOT_DIR/.env" ]; then
  set -a; source "$ROOT_DIR/.env"; set +a
fi

# Parse arguments
MODE="all"
STACK_FILTER=""
CI_MODE=false
JSON_MODE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stack) STACK_FILTER="$2"; MODE="stack"; shift 2 ;;
    --ci) CI_MODE=true; shift ;;
    --json) JSON_MODE=true; shift ;;
    --all) MODE="all"; shift ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

BOLD='\033[1m'; CYAN='\033[0;36m'; RESET='\033[0m'

RESULTS_DIR="${ROOT_DIR}/tests/results"
mkdir -p "$RESULTS_DIR"
RESULTS_FILE="${RESULTS_DIR}/results-$(date +%Y%m%d-%H%M%S).json"
export RESULTS_FILE
echo '{"timestamp":"'"$(date -Iseconds)"'","tests":[' > "$RESULTS_FILE"

# Source assertion library
source "${SCRIPT_DIR}/lib/assert.sh"

# ------------------------------------------------------------------
# Run a test file
# ------------------------------------------------------------------
run_test_file() {
  local file="$1"
  local stack_name
  stack_name=$(basename "$file" .test.sh)

  # Filter if specific stacks requested
  if [ "$MODE" = "stack" ] && [ -n "$STACK_FILTER" ]; then
    if ! echo ",${STACK_FILTER}," | grep -q ",${stack_name},"; then
      return 0
    fi
  fi

  if [ -f "$file" ]; then
    echo -e "\n${BOLD}${CYAN}▶ Running: $stack_name${RESET}"
    bash "$file" 2>&1 || true
  fi
}

# ------------------------------------------------------------------
# Root health checks
# ------------------------------------------------------------------
describe "Environment"
it "Docker is running"; assert_true "docker info &>/dev/null" || fail "Docker daemon not reachable"
it "Required tools present"; { command -v jq &>/dev/null && pass; } || fail "jq not installed"
it "docker-compose available"; { docker compose version &>/dev/null && pass; } || fail "docker compose not available"

# ------------------------------------------------------------------
# Run all stack tests
# ------------------------------------------------------------------
STACKS_DIR="${SCRIPT_DIR}/stacks"
if [ -d "$STACKS_DIR" ]; then
  for test_file in "$STACKS_DIR"/*.test.sh; do
    [ -f "$test_file" ] && run_test_file "$test_file"
  done
else
  echo -e "\n${CYAN}No stack test files found in $STACKS_DIR${RESET}"
fi

# ------------------------------------------------------------------
# Print results
# ------------------------------------------------------------------
# Close JSON array
sed -i '$ s/,$//' "$RESULTS_FILE"
echo ']}' >> "$RESULTS_FILE"

print_summary
EXIT_CODE=$?

if ! $JSON_MODE; then
  echo -e "\nResults saved to: $RESULTS_FILE"
fi

exit $EXIT_CODE