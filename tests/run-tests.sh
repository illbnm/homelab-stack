#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Integration Test Runner
# Usage: ./tests/run-tests.sh [--stack <name>] [--all] [--e2e] [--json] [--help]
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# Source libraries
source "$SCRIPT_DIR/lib/assert.sh"
source "$SCRIPT_DIR/lib/docker.sh"
source "$SCRIPT_DIR/lib/report.sh"

# Defaults
TARGET_STACK=""
RUN_ALL=false
RUN_E2E=false
JSON_OUTPUT=false
RESULTS_DIR="$SCRIPT_DIR/results"

usage() {
  cat <<EOF
HomeLab Stack Integration Tests

Usage: $(basename "$0") [OPTIONS]

Options:
  --stack <name>   Run tests for a specific stack
  --all            Run all stack tests
  --e2e            Run end-to-end tests (SSO flow)
  --json           Output JSON report
  --help           Show this help

Available stacks:
  base, media, storage, monitoring, network, productivity,
  ai, sso, databases, notifications

Examples:
  $(basename "$0") --stack base
  $(basename "$0") --all
  $(basename "$0") --all --e2e --json
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --stack) TARGET_STACK="$2"; shift 2 ;;
    --all) RUN_ALL=true; shift ;;
    --e2e) RUN_E2E=true; shift ;;
    --json) JSON_OUTPUT=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

if [[ -z "$TARGET_STACK" ]] && [[ "$RUN_ALL" == "false" ]] && [[ "$RUN_E2E" == "false" ]]; then
  usage
  exit 1
fi

# Pre-flight: check Docker is available
if ! docker_is_running; then
  echo -e "${RED}ERROR: Docker is not running${NC}"
  exit 1
fi

# Header
echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║   HomeLab Stack — Integration Tests     ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════╝${NC}"
echo ""

report_init

run_stack_tests() {
  local stack="$1"
  local test_file="$SCRIPT_DIR/stacks/${stack}.test.sh"

  if [[ ! -f "$test_file" ]]; then
    echo -e "${YELLOW}  No tests for stack: $stack${NC}"
    return
  fi

  echo ""
  echo -e "${BLUE}${BOLD}━━━ [$stack] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  report_stack_begin "$stack"
  source "$test_file"
  report_stack_end "$stack"
}

run_e2e_tests() {
  echo ""
  echo -e "${BLUE}${BOLD}━━━ [E2E Tests] ━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  for e2e_file in "$SCRIPT_DIR"/e2e/*.test.sh; do
    [[ -f "$e2e_file" ]] || continue
    local name
    name=$(basename "$e2e_file" .test.sh)
    report_stack_begin "e2e-$name"
    source "$e2e_file"
    report_stack_end "e2e-$name"
  done
}

if [[ "$RUN_ALL" == "true" ]]; then
  for test_file in "$SCRIPT_DIR"/stacks/*.test.sh; do
    [[ -f "$test_file" ]] || continue
    stack_name=$(basename "$test_file" .test.sh)
    run_stack_tests "$stack_name"
  done
elif [[ -n "$TARGET_STACK" ]]; then
  run_stack_tests "$TARGET_STACK"
fi

if [[ "$RUN_E2E" == "true" ]]; then
  run_e2e_tests
fi

report_summary

if [[ "$JSON_OUTPUT" == "true" ]]; then
  mkdir -p "$RESULTS_DIR"
  report_json > "$RESULTS_DIR/report.json"
  echo -e "\n${GREEN}JSON report written to: $RESULTS_DIR/report.json${NC}"
fi

[[ $FAILED -eq 0 ]] && exit 0 || exit 1
