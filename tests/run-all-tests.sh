#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack - Master Test Runner
# Runs all test suites and generates summary report
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$SCRIPT_DIR/.."

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

TOTAL_PASSED=0
TOTAL_FAILED=0
TOTAL_SKIPPED=0
START_TIME=$(date +%s)

log_info()    { echo -e "${BLUE}$*${NC}"; }
log_success() { echo -e "${GREEN}$*${NC}"; }
log_warning() { echo -e "${YELLOW}$*${NC}"; }
log_error()   { echo -e "${RED}$*${NC}"; }

# -----------------------------------------------------------------------------
# Run Test Suite
# -----------------------------------------------------------------------------
run_test_suite() {
  local name=$1
  local script=$2
  
  echo ""
  echo -e "${BOLD}========================================${NC}"
  echo -e "${BOLD}  Running: $name${NC}"
  echo -e "${BOLD}========================================${NC}"
  
  if [[ ! -f "$script" ]]; then
    log_error "Test script not found: $script"
    return 1
  fi
  
  chmod +x "$script"
  
  local start_time=$(date +%s)
  
  # Run test and capture output
  local output
  local exit_code
  output=$("$script" 2>&1) || exit_code=$?
  
  local end_time=$(date +%s)
  local duration=$((end_time - start_time))
  
  echo "$output"
  
  # Parse results from output
  local passed failed skipped
  passed=$(echo "$output" | grep -oP '\d+(?= passed)' | tail -1 || echo 0)
  failed=$(echo "$output" | grep -oP '\d+(?= failed)' | tail -1 || echo 0)
  skipped=$(echo "$output" | grep -oP '\d+(?= skipped)' | tail -1 || echo 0)
  
  # Default values if parsing failed
  passed=${passed:-0}
  failed=${failed:-0}
  skipped=${skipped:-0}
  
  TOTAL_PASSED=$((TOTAL_PASSED + passed))
  TOTAL_FAILED=$((TOTAL_FAILED + failed))
  TOTAL_SKIPPED=$((TOTAL_SKIPPED + skipped))
  
  echo ""
  log_info "Duration: ${duration}s"
  
  if [[ $failed -gt 0 ]]; then
    log_error "❌ $name: $failed test(s) failed"
    return 1
  else
    log_success "✅ $name: All tests passed"
    return 0
  fi
}

# -----------------------------------------------------------------------------
# Pre-flight Checks
# -----------------------------------------------------------------------------
preflight_checks() {
  echo -e "${BOLD}========================================${NC}"
  echo -e "${BOLD}  Pre-flight Checks${NC}"
  echo -e "${BOLD}========================================${NC}"
  
  local errors=0
  
  # Check Docker
  if command -v docker &>/dev/null; then
    log_success "✓ Docker installed: $(docker --version)"
  else
    log_error "✗ Docker not installed"
    ((errors++))
  fi
  
  # Check Docker Compose
  if command -v docker compose &>/dev/null; then
    log_success "✓ Docker Compose installed"
  else
    log_error "✗ Docker Compose not installed"
    ((errors++))
  fi
  
  # Check Docker daemon
  if docker ps &>/dev/null; then
    log_success "✓ Docker daemon running"
  else
    log_warning "⚠ Docker daemon not accessible (integration tests will skip)"
  fi
  
  # Check test scripts exist
  local required_scripts=(
    "tests/unit/test-config-validation.sh"
    "tests/integration/test-services.sh"
    "tests/e2e/test-deployment.sh"
  )
  
  for script in "${required_scripts[@]}"; do
    if [[ -f "$BASE_DIR/$script" ]]; then
      log_success "✓ Test script exists: $script"
    else
      log_error "✗ Test script missing: $script"
      ((errors++))
    fi
  done
  
  echo ""
  
  if [[ $errors -gt 0 ]]; then
    log_error "Pre-flight checks failed with $errors error(s)"
    return 1
  else
    log_success "Pre-flight checks passed"
    return 0
  fi
}

# -----------------------------------------------------------------------------
# Generate Report
# -----------------------------------------------------------------------------
generate_report() {
  local end_time=$(date +%s)
  local total_duration=$((end_time - START_TIME))
  
  echo ""
  echo -e "${BOLD}========================================${NC}"
  echo -e "${BOLD}  Test Summary Report${NC}"
  echo -e "${BOLD}========================================${NC}"
  echo ""
  echo "  Total Duration: ${total_duration}s"
  echo ""
  echo -e "  ${GREEN}Passed${NC}:  $TOTAL_PASSED"
  echo -e "  ${RED}Failed${NC}:  $TOTAL_FAILED"
  echo -e "  ${YELLOW}Skipped${NC}: $TOTAL_SKIPPED"
  echo ""
  
  local total=$((TOTAL_PASSED + TOTAL_FAILED + TOTAL_SKIPPED))
  local pass_rate=0
  if [[ $total -gt 0 ]]; then
    pass_rate=$((TOTAL_PASSED * 100 / total))
  fi
  
  echo "  Pass Rate: ${pass_rate}%"
  echo ""
  
  if [[ $TOTAL_FAILED -gt 0 ]]; then
    echo -e "${RED}❌ OVERALL: FAILED${NC}"
    return 1
  else
    echo -e "${GREEN}✅ OVERALL: PASSED${NC}"
    return 0
  fi
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
  echo -e "${BOLD}========================================${NC}"
  echo -e "${BOLD}  HomeLab Stack - Test Suite${NC}"
  echo -e "${BOLD}========================================${NC}"
  echo ""
  
  cd "$BASE_DIR"
  
  # Parse arguments
  local run_unit=true
  local run_integration=true
  local run_e2e=false
  local run_preflight=true
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      --unit-only)
        run_integration=false
        run_e2e=false
        shift
        ;;
      --integration-only)
        run_unit=false
        run_e2e=false
        shift
        ;;
      --e2e)
        run_e2e=true
        shift
        ;;
      --no-preflight)
        run_preflight=false
        shift
        ;;
      --help)
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --unit-only       Run only unit tests"
        echo "  --integration-only Run only integration tests"
        echo "  --e2e            Include E2E tests (requires sudo)"
        echo "  --no-preflight   Skip pre-flight checks"
        echo "  --help           Show this help"
        exit 0
        ;;
      *)
        log_error "Unknown option: $1"
        exit 1
        ;;
    esac
  done
  
  # Run pre-flight checks
  if [[ "$run_preflight" == true ]]; then
    if ! preflight_checks; then
      exit 1
    fi
  fi
  
  # Run unit tests
  if [[ "$run_unit" == true ]]; then
    run_test_suite "Unit Tests" "$BASE_DIR/tests/unit/test-config-validation.sh" || true
  fi
  
  # Run integration tests
  if [[ "$run_integration" == true ]]; then
    run_test_suite "Integration Tests" "$BASE_DIR/tests/integration/test-services.sh" || true
  fi
  
  # Run E2E tests (optional)
  if [[ "$run_e2e" == true ]]; then
    run_test_suite "E2E Tests" "$BASE_DIR/tests/e2e/test-deployment.sh" || true
  fi
  
  # Generate summary report
  generate_report
  exit_code=$?
  
  echo ""
  echo -e "${BOLD}========================================${NC}"
  
  exit $exit_code
}

main "$@"
