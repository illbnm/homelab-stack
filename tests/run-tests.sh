#!/usr/bin/env bash
# =============================================================================
# run-tests.sh — HomeLab Stack Integration Test Runner
# =============================================================================
# Usage:
#   ./tests/run-tests.sh [--stack NAME] [--all] [--json] [--verbose] [--help]
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.."; pwd)"
ENV_FILE="$BASE_DIR/config/.env"
[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"

# Source libraries
source "$SCRIPT_DIR/lib/report.sh"
source "$SCRIPT_DIR/lib/assert.sh"
source "$SCRIPT_DIR/lib/docker.sh"

# Defaults
TARGET_STACK=""
JSON_REPORT=0
VERBOSE=0
TEST_TOTAL_START=$(date +%s)

# ---- Parse arguments ----
while [[ $# -gt 0 ]]; do
  case "$1" in
    --stack)  TARGET_STACK="$2"; shift 2 ;;
    --all)    TARGET_STACK="__all__"; shift ;;
    --json)   JSON_REPORT=1; shift ;;
    --verbose|-v) VERBOSE=1; shift ;;
    --help|-h)
      cat <<HELP
HomeLab Stack — Integration Tests

Usage:
  $(basename "$0") [OPTIONS]

Options:
  --stack NAME    Run tests for a specific stack
  --all           Run all stack tests
  --json          Output JSON report to tests/results/report.json
  --verbose, -v   Verbose output
  --help, -h      Show this help

Available stacks:
  base, databases, media, monitoring, network, productivity,
  sso, storage, ai, home-automation, notifications, dashboard

Examples:
  $(basename "$0") --stack base
  $(basename "$0") --all --json
  $(basename "$0") --stack monitoring --verbose
HELP
      exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ---- Header ----
echo -e "\n${BOLD}${BLUE}╔══════════════════════════════════════╗${NC}"
echo -e "${BOLD}${BLUE}║  HomeLab Stack — Integration Tests    ║${NC}"
echo -e "${BOLD}${BLUE}╚══════════════════════════════════════╝${NC}"

# ---- Prerequisite check ----
TEST_STACK="__prereq__"
TEST_CURRENT=""
if ! check_docker; then
  echo -e "${RED}✗ Docker daemon is not running${NC}"
  exit 1
fi
test_start "Docker daemon running"; test_pass
echo ""

if [[ "$JSON_REPORT" -eq 1 ]]; then
  json_init "$BASE_DIR/tests/results/report.json"
fi

# ---- Stack mapping ----
declare -A STACK_TESTS
STACK_TESTS[base]="$SCRIPT_DIR/stacks/base.test.sh"
STACK_TESTS[media]="$SCRIPT_DIR/stacks/media.test.sh"
STACK_TESTS[monitoring]="$SCRIPT_DIR/stacks/monitoring.test.sh"
STACK_TESTS[sso]="$SCRIPT_DIR/stacks/sso.test.sh"
STACK_TESTS[databases]="$SCRIPT_DIR/stacks/databases.test.sh"
STACK_TESTS[network]="$SCRIPT_DIR/stacks/network.test.sh"
STACK_TESTS[productivity]="$SCRIPT_DIR/stacks/productivity.test.sh"
STACK_TESTS[storage]="$SCRIPT_DIR/stacks/storage.test.sh"
STACK_TESTS[ai]="$SCRIPT_DIR/stacks/ai.test.sh"
STACK_TESTS[home-automation]="$SCRIPT_DIR/stacks/home-automation.test.sh"
STACK_TESTS[notifications]="$SCRIPT_DIR/stacks/notifications.test.sh"
STACK_TESTS[dashboard]="$SCRIPT_DIR/stacks/dashboard.test.sh"

# ---- Determine which stacks to run ----
if [[ "$TARGET_STACK" == "__all__" ]]; then
  RUN_STACKS=("${!STACK_TESTS[@]}")
elif [[ -n "$TARGET_STACK" ]]; then
  if [[ -v "STACK_TESTS[$TARGET_STACK]" ]]; then
    RUN_STACKS=("$TARGET_STACK")
  else
    echo -e "${RED}Unknown stack: $TARGET_STACK${NC}"
    echo "Available: ${!STACK_TESTS[*]}"
    exit 1
  fi
else
  # Default: run all
  RUN_STACKS=("${!STACK_TESTS[@]}")
fi

# ---- Run tests ----
for stack in "${RUN_STACKS[@]}"; do
  test_file="${STACK_TESTS[$stack]}"
  if [[ ! -f "$test_file" ]]; then
    echo -e "${YELLOW}~ Skipping $stack (no test file)${NC}"
    REPORT_RESULTS+=("SKIP|$stack||0ms|test file not found")
    continue
  fi

  echo -e "${BOLD}${BLUE}[$stack]${NC}"
  TEST_STACK="$stack"

  # Source test file and run all test_* functions
  (
    set +e
    source "$test_file" 2>/dev/null
    # Collect and call test_* functions
    while IFS= read -r fn; do
      "$fn" 2>/dev/null || true
    done < <(declare -F | awk '/^declare -f test_/ {print $3}')
  )
done

# ---- Summary ----
TEST_TOTAL_END=$(date +%s)
TEST_TOTAL_DUR=$(( TEST_TOTAL_END - TEST_TOTAL_START ))

print_summary

if [[ "$JSON_REPORT" -eq 1 ]] && command -v jq &>/dev/null; then
  jq ".summary.duration = ${TEST_TOTAL_DUR}" "$BASE_DIR/tests/results/report.json" \
    > "${BASE_DIR/tests/results/report.json}.tmp" \
    && mv "${BASE_DIR/tests/results/report.json}.tmp" "$BASE_DIR/tests/results/report.json"
  echo -e "${DIM}JSON report: $BASE_DIR/tests/results/report.json${NC}"
fi

# ---- Exit ----
failed_count=0
for r in "${REPORT_RESULTS[@]}"; do
  [[ "$r" == FAIL* ]] && ((failed_count++))
done
[[ "$failed_count" -eq 0 ]] && exit 0 || exit 1
