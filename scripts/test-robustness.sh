#!/usr/bin/env bash
# =============================================================================
# test-robustness.sh — Test Robustness Features
# =============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.."; pwd)"

PASS=0
FAIL=0

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_test()  { echo -e "\n${BLUE}${BOLD}TEST:${NC} $*"; }
log_pass()  { echo -e "${GREEN}✓ PASS${NC} $*"; ((PASS++)); }
log_fail()  { echo -e "${RED}✗ FAIL${NC} $*"; ((FAIL++)); }

# Test script exists and is executable
test_script_exists() {
  local script="$1"
  local script_path="$PROJECT_ROOT/$script"

  if [[ -x "$script_path" ]]; then
    log_pass "Script exists and is executable: $script"
    return 0
  else
    log_fail "Script missing or not executable: $script"
    return 1
  fi
}

# Main test suite
main() {
  echo
  echo -e "${BOLD}══════════════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}     Robustness Scripts Test Suite${NC}"
  echo -e "${BOLD}══════════════════════════════════════════════════════════${NC}"
  echo

  # Define all scripts to test
  local scripts=(
    "scripts/setup-cn-mirrors.sh"
    "scripts/localize-images.sh"
    "scripts/check-connectivity.sh"
    "scripts/wait-healthy.sh"
    "scripts/diagnose.sh"
    "scripts/setup-pkg-mirrors.sh"
  )

  # Test each script
  for script in "${scripts[@]}"; do
    log_test "Testing: $script"
    test_script_exists "$script"
  done

  # Test config file
  log_test "Testing: config/cn-mirrors.yml"
  if [[ -f "$PROJECT_ROOT/config/cn-mirrors.yml" ]]; then
    log_pass "Config file exists: config/cn-mirrors.yml"
  else
    log_fail "Config file missing: config/cn-mirrors.yml"
  fi

  # Summary
  echo
  echo -e "${BOLD}══════════════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}     Test Results Summary${NC}"
  echo -e "${BOLD}══════════════════════════════════════════════════════════${NC}"
  echo
  echo -e "  ${GREEN}PASSED: $PASS${NC}"
  echo -e "  ${RED}FAILED: $FAIL${NC}"
  echo

  if [[ $FAIL -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}✓ All tests passed!${NC}"
    exit 0
  else
    echo -e "${RED}${BOLD}✗ Some tests failed${NC}"
    exit 1
  fi
}

main "$@"
