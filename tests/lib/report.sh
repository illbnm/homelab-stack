#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Test Report Library
# Generates colored terminal summaries and JSON reports.
# =============================================================================

# Requires assert.sh to be sourced first (uses TEST_PASSED, TEST_FAILED, etc.)

readonly _BOLD='\033[1m'
readonly _BLUE='\033[0;34m'
readonly _CYAN='\033[0;36m'
readonly _R_NC='\033[0m'

# Track which suite is currently running
declare -g CURRENT_SUITE=""
declare -g SUITE_RESULTS="[]"
declare -g REPORT_START_TIME=""

# ---------------------------------------------------------------------------
# Suite lifecycle
# ---------------------------------------------------------------------------

# report_start
# Call at the beginning of a test run.
report_start() {
  REPORT_START_TIME=$(date +%s)
  SUITE_RESULTS="[]"
  echo ""
  echo -e "${_BOLD}╔══════════════════════════════════════════════════════════════╗${_R_NC}"
  echo -e "${_BOLD}║          HomeLab Stack — Integration Test Suite             ║${_R_NC}"
  echo -e "${_BOLD}╚══════════════════════════════════════════════════════════════╝${_R_NC}"
  echo -e "  Started at: $(date '+%Y-%m-%d %H:%M:%S')"
  echo ""
}

# test_group NAME
# Prints a group/section header for a set of related tests.
test_group() {
  CURRENT_SUITE="$1"
  echo ""
  echo -e "${_BLUE}${_BOLD}[$1]${_R_NC}"
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

# report_summary
# Prints the final test summary.
report_summary() {
  local end_time duration
  end_time=$(date +%s)
  duration=$(( end_time - ${REPORT_START_TIME:-$end_time} ))
  local total=$(( TEST_PASSED + TEST_FAILED + TEST_SKIPPED ))

  echo ""
  echo -e "${_BOLD}══════════════════════════════════════════════════════════════${_R_NC}"
  echo -e "  ${_BOLD}Test Results${_R_NC}"
  echo -e "${_BOLD}══════════════════════════════════════════════════════════════${_R_NC}"
  echo -e "  Total:   ${total}"
  echo -e "  ${_GREEN}Passed:  ${TEST_PASSED}${_R_NC}"
  echo -e "  ${_RED}Failed:  ${TEST_FAILED}${_R_NC}"
  echo -e "  ${_YELLOW}Skipped: ${TEST_SKIPPED}${_R_NC}"
  echo -e "  Duration: ${duration}s"
  echo -e "${_BOLD}══════════════════════════════════════════════════════════════${_R_NC}"
  echo ""

  if [[ "$TEST_FAILED" -eq 0 ]]; then
    echo -e "  ${_GREEN}${_BOLD}All tests passed!${_R_NC}"
  else
    echo -e "  ${_RED}${_BOLD}${TEST_FAILED} test(s) failed.${_R_NC}"
  fi
  echo ""
}

# ---------------------------------------------------------------------------
# JSON report
# ---------------------------------------------------------------------------

# report_json [OUTPUT_FILE]
# Writes test results as JSON. Outputs to stdout if no file specified.
report_json() {
  local output_file="${1:-}"
  local end_time duration
  end_time=$(date +%s)
  duration=$(( end_time - ${REPORT_START_TIME:-$end_time} ))
  local total=$(( TEST_PASSED + TEST_FAILED + TEST_SKIPPED ))

  local json
  json=$(cat <<EOJSON
{
  "timestamp": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
  "duration_seconds": ${duration},
  "summary": {
    "total": ${total},
    "passed": ${TEST_PASSED},
    "failed": ${TEST_FAILED},
    "skipped": ${TEST_SKIPPED}
  },
  "success": $([ "$TEST_FAILED" -eq 0 ] && echo "true" || echo "false"),
  "results": ${TEST_RESULTS_JSON}
}
EOJSON
)

  if [[ -n "$output_file" ]]; then
    echo "$json" > "$output_file"
    echo -e "  ${_CYAN}JSON report written to: ${output_file}${_R_NC}"
  else
    echo "$json"
  fi
}

# ---------------------------------------------------------------------------
# Exit helper
# ---------------------------------------------------------------------------

# report_exit
# Prints summary, optionally writes JSON, and exits with appropriate code.
report_exit() {
  local json_file="${1:-}"
  report_summary
  if [[ -n "$json_file" ]]; then
    report_json "$json_file"
  fi
  [[ "$TEST_FAILED" -eq 0 ]] && exit 0 || exit 1
}
