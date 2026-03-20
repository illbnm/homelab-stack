#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Test Report Generator
# Produces colored terminal summary and JSON report from test results.
# =============================================================================

# Colors
_R_RED='\033[0;31m'
_R_GREEN='\033[0;32m'
_R_YELLOW='\033[1;33m'
_R_BLUE='\033[0;34m'
_R_BOLD='\033[1m'
_R_NC='\033[0m'

: "${TEST_RESULTS_FILE:=/tmp/homelab-test-results.json}"
: "${TEST_REPORT_JSON:=/tmp/homelab-test-report.json}"

# ---------------------------------------------------------------------------
# Group header for terminal output
# ---------------------------------------------------------------------------
log_group() {
  echo -e "\n${_R_BLUE}${_R_BOLD}[$*]${_R_NC}"
}

# ---------------------------------------------------------------------------
# Terminal summary
# ---------------------------------------------------------------------------
print_summary() {
  local passed="${TEST_PASSED:-0}"
  local failed="${TEST_FAILED:-0}"
  local skipped="${TEST_SKIPPED:-0}"
  local total=$((passed + failed + skipped))
  local duration="${1:-0}"

  echo ""
  echo -e "${_R_BOLD}════════════════════════════════════════════════════════════${_R_NC}"
  echo -e "  ${_R_BOLD}HomeLab Stack Integration Test Results${_R_NC}"
  echo -e "${_R_BOLD}════════════════════════════════════════════════════════════${_R_NC}"
  echo -e "  Total:   ${_R_BOLD}$total${_R_NC}"
  echo -e "  Passed:  ${_R_GREEN}$passed${_R_NC}"
  echo -e "  Failed:  ${_R_RED}$failed${_R_NC}"
  echo -e "  Skipped: ${_R_YELLOW}$skipped${_R_NC}"
  echo -e "  Duration: ${duration}s"
  echo -e "${_R_BOLD}════════════════════════════════════════════════════════════${_R_NC}"

  if [[ "$failed" -eq 0 ]]; then
    echo -e "  ${_R_GREEN}${_R_BOLD}ALL TESTS PASSED${_R_NC}"
  else
    echo -e "  ${_R_RED}${_R_BOLD}$failed TEST(S) FAILED${_R_NC}"
  fi
  echo -e "${_R_BOLD}════════════════════════════════════════════════════════════${_R_NC}"
}

# ---------------------------------------------------------------------------
# JSON report generation
# ---------------------------------------------------------------------------
generate_json_report() {
  local passed="${TEST_PASSED:-0}"
  local failed="${TEST_FAILED:-0}"
  local skipped="${TEST_SKIPPED:-0}"
  local total=$((passed + failed + skipped))
  local duration="${1:-0}"
  local stack_filter="${2:-all}"

  # Build the JSON report
  local results_array="[]"
  if [[ -f "$TEST_RESULTS_FILE" ]]; then
    results_array=$(cat "$TEST_RESULTS_FILE" | jq -s '.' 2>/dev/null || echo "[]")
  fi

  cat > "$TEST_REPORT_JSON" <<JSONEOF
{
  "summary": {
    "total": $total,
    "passed": $passed,
    "failed": $failed,
    "skipped": $skipped,
    "duration_seconds": $duration,
    "stack_filter": "$stack_filter",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "success": $([ "$failed" -eq 0 ] && echo true || echo false)
  },
  "results": $results_array
}
JSONEOF

  echo -e "\n  JSON report: ${_R_BOLD}$TEST_REPORT_JSON${_R_NC}"
}

# ---------------------------------------------------------------------------
# Print failures only (for CI)
# ---------------------------------------------------------------------------
print_failures() {
  if [[ ! -f "$TEST_RESULTS_FILE" ]]; then
    return
  fi

  local failures
  failures=$(jq -r 'select(.status == "fail") | "  \(.name): \(.message)"' "$TEST_RESULTS_FILE" 2>/dev/null)
  if [[ -n "$failures" ]]; then
    echo -e "\n${_R_RED}${_R_BOLD}Failed tests:${_R_NC}"
    echo "$failures"
  fi
}

# ---------------------------------------------------------------------------
# Init / cleanup results file
# ---------------------------------------------------------------------------
init_results() {
  : > "$TEST_RESULTS_FILE"
}
