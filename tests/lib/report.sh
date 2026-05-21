#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Test Report Generator
# =============================================================================
# Outputs results as JSON file + terminal summary.

set -uo pipefail

# Load assert if not already loaded
[[ -z "${_A_NC:-}" ]] && source "$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)/assert.sh"

readonly _R_RED='\033[0;31m'; _R_GREEN='\033[0;32m'; _R_YELLOW='\033[1;33m'
readonly _R_BOLD='\033[1m'; _R_NC='\033[0m'; _R_DIM='\033[2m'

_REPORT_DIR=""
_REPORT_FILE=""
_START_TIME=0

# ---------------------------------------------------------------------------
# Init / Finish
# ---------------------------------------------------------------------------
report_init() {
  _REPORT_DIR="${1:-.}"
  _START_TIME=$(date +%s)
  mkdir -p "$_REPORT_DIR"
  _REPORT_FILE="${_REPORT_DIR}/test-results-$(date +%Y%m%d-%H%M%S).json"
  echo -e "${_R_BOLD}═══════════════════════════════════════════════════${_R_NC}"
  echo -e "${_R_BOLD}  HomeLab Stack — Integration Test Suite${_R_NC}"
  echo -e "${_R_DIM}  $(date '+%Y-%m-%d %H:%M:%S %Z')${_R_NC}"
  echo -e "${_R_BOLD}═══════════════════════════════════════════════════${_R_NC}"
}

report_finish() {
  local end_time
  end_time=$(date +%s)
  local duration=$(( end_time - _START_TIME ))

  local total=$(( _TESTS_PASSED + _TESTS_FAILED + _TESTS_SKIPPED ))

  echo -e "\n${_R_BOLD}═══════════════════════════════════════════════════${_R_NC}"
  echo -e "${_R_BOLD}  Results${_R_NC}"
  echo -e "${_R_BOLD}═══════════════════════════════════════════════════${_R_NC}"
  echo -e "  ${_R_GREEN}✓ Passed:  ${_TESTS_PASSED}${_R_NC}"
  echo -e "  ${_R_RED}✗ Failed:  ${_TESTS_FAILED}${_R_NC}"
  echo -e "  ${_R_YELLOW}~ Skipped: ${_TESTS_SKIPPED}${_R_NC}"
  echo -e "  ${_R_DIM}  Total:   ${total}${_R_NC}"
  echo -e "  ${_R_DIM}  Time:    ${duration}s${_R_NC}"
  echo -e "${_R_BOLD}═══════════════════════════════════════════════════${_R_NC}"

  # Write JSON report
  local json
  json=$(cat <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "duration_seconds": ${duration},
  "summary": {
    "total": ${total},
    "passed": ${_TESTS_PASSED},
    "failed": ${_TESTS_FAILED},
    "skipped": ${_TESTS_SKIPPED}
  },
  "results": $(get_json_results)
}
EOF
)
  echo "$json" > "$_REPORT_FILE"
  echo -e "\n  ${_R_DIM}JSON report: ${_REPORT_FILE}${_R_NC}"

  # Exit code
  if [[ "$_TESTS_FAILED" -gt 0 ]]; then
    echo -e "\n  ${_R_RED}${_R_BOLD}FAILED${_R_NC} — ${_TESTS_FAILED} test(s) failed\n"
    return 1
  else
    echo -e "\n  ${_R_GREEN}${_R_BOLD}ALL PASSED${_R_NC}\n"
    return 0
  fi
}

# ---------------------------------------------------------------------------
# Stack filter
# ---------------------------------------------------------------------------
# Usage: should_run_stack "base" -- returns 0 if this stack should run
should_run_stack() {
  local stack="$1"
  # If _RUN_STACKS is empty or "all", run everything
  if [[ -z "${_RUN_STACKS:-}" || "${_RUN_STACKS}" == "all" ]]; then
    return 0
  fi
  # Check if stack is in the comma-separated list
  echo ",${_RUN_STACKS}," | grep -qi ",${stack},"
}
