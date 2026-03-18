#!/usr/bin/env bash
# =============================================================================
# Report Library
# Provides output formatting and summary reporting
# =============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Print section header
print_section() {
  echo -e "\n${BLUE}${BOLD}[$*]${NC}"
}

# Print summary of test results
print_summary() {
  echo ""
  echo -e "${BOLD}========================================${NC}"
  echo -e "  Results: ${GREEN}$PASSED passed${NC} | ${RED}$FAILED failed${NC} | ${YELLOW}$SKIPPED skipped${NC}"
  echo -e "${BOLD}========================================${NC}"

  # Return appropriate exit code
  if [[ $FAILED -eq 0 ]]; then
    echo -e "${GREEN}All tests passed!${NC}"
    return 0
  else
    echo -e "${RED}Some tests failed.${NC}"
    return 1
  fi
}

# Print JSON output (for CI integration)
print_json() {
  local output_file="${1:-test-results.json}"
  cat > "$output_file" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "results": {
    "passed": $PASSED,
    "failed": $FAILED,
    "skipped": $SKIPPED,
    "total": $((PASSED + FAILED + SKIPPED))
  },
  "status": "$([[ $FAILED -eq 0 ]] && echo 'passed' || echo 'failed')"
}
EOF
  echo "Results written to $output_file"
}

# Print test run header
print_header() {
  echo -e "${BOLD}========================================${NC}"
  echo -e "${BOLD}HomeLab Stack Integration Tests${NC}"
  echo -e "${BOLD}========================================${NC}"
  echo -e "Started: $(date)"
  echo ""
}

# Print test run footer
print_footer() {
  echo ""
  echo -e "${BOLD}========================================${NC}"
  echo -e "Completed: $(date)"
  echo -e "${BOLD}========================================${NC}"
}