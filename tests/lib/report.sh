#!/usr/bin/env bash
# =============================================================================
# HomeLab Integration Tests — Report Generator
#
# Handles terminal colored output and JSON report generation.
# =============================================================================

# Colors (disable if not a terminal)
if [[ -t 1 ]]; then
  _CLR_GREEN='\033[0;32m'
  _CLR_RED='\033[0;31m'
  _CLR_YELLOW='\033[0;33m'
  _CLR_BLUE='\033[0;34m'
  _CLR_CYAN='\033[0;36m'
  _CLR_BOLD='\033[1m'
  _CLR_RESET='\033[0m'
else
  _CLR_GREEN=''
  _CLR_RED=''
  _CLR_YELLOW=''
  _CLR_BLUE=''
  _CLR_CYAN=''
  _CLR_BOLD=''
  _CLR_RESET=''
fi

# JSON results accumulator
_JSON_RESULTS="[]"
_SUITE_START_TIME=""

# ---------------------------------------------------------------------------
# report_header
# Print the test suite header.
# ---------------------------------------------------------------------------
report_header() {
  _SUITE_START_TIME=$(date +%s)
  echo ""
  echo -e "${_CLR_CYAN}╔══════════════════════════════════════╗${_CLR_RESET}"
  echo -e "${_CLR_CYAN}║   HomeLab Stack — Integration Tests  ║${_CLR_RESET}"
  echo -e "${_CLR_CYAN}╚══════════════════════════════════════╝${_CLR_RESET}"
  echo ""
}

# ---------------------------------------------------------------------------
# report_stack_header <stack_name>
# Print a stack section header.
# ---------------------------------------------------------------------------
report_stack_header() {
  local stack="$1"
  echo ""
  echo -e "${_CLR_BOLD}── ${stack} ──${_CLR_RESET}"
}

# ---------------------------------------------------------------------------
# _report_result <status> <stack> <test_name> <duration> <message>
# Report a single test result (called by assert functions).
# ---------------------------------------------------------------------------
_report_result() {
  local status="$1"
  local stack="$2"
  local test_name="$3"
  local duration="$4"
  local message="$5"

  local icon=""
  local color=""

  case "${status}" in
    PASS)
      icon="✅"
      color="${_CLR_GREEN}"
      ;;
    FAIL)
      icon="❌"
      color="${_CLR_RED}"
      ;;
    SKIP)
      icon="⏭️ "
      color="${_CLR_YELLOW}"
      ;;
  esac

  # Terminal output
  printf "[%s] ▶ %-30s %b%s %s (%ss)%b\n" \
    "${stack}" "${test_name}" "${color}" "${icon}" "${status}" "${duration}" "${_CLR_RESET}"

  if [[ -n "${message}" && "${status}" != "PASS" ]]; then
    printf "       %b%s%b\n" "${color}" "${message}" "${_CLR_RESET}"
  fi

  # Append to JSON results
  local json_entry
  json_entry=$(jq -n \
    --arg stack "${stack}" \
    --arg test "${test_name}" \
    --arg status "${status}" \
    --arg duration "${duration}" \
    --arg message "${message}" \
    --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{stack: $stack, test: $test, status: $status, duration: ($duration | tonumber), message: $message, timestamp: $timestamp}' 2>/dev/null)

  _JSON_RESULTS=$(echo "${_JSON_RESULTS}" | jq ". + [${json_entry}]" 2>/dev/null)
}

# ---------------------------------------------------------------------------
# report_summary
# Print the final summary and write JSON report.
# ---------------------------------------------------------------------------
report_summary() {
  local total=$((_TESTS_PASSED + _TESTS_FAILED + _TESTS_SKIPPED))
  local suite_duration=0

  if [[ -n "${_SUITE_START_TIME}" ]]; then
    suite_duration=$(( $(date +%s) - _SUITE_START_TIME ))
  fi

  echo ""
  echo -e "${_CLR_CYAN}──────────────────────────────────────${_CLR_RESET}"

  if [[ ${_TESTS_FAILED} -eq 0 ]]; then
    echo -e "${_CLR_GREEN}${_CLR_BOLD}Results: ${_TESTS_PASSED} passed, ${_TESTS_FAILED} failed, ${_TESTS_SKIPPED} skipped${_CLR_RESET}"
  else
    echo -e "${_CLR_RED}${_CLR_BOLD}Results: ${_TESTS_PASSED} passed, ${_TESTS_FAILED} failed, ${_TESTS_SKIPPED} skipped${_CLR_RESET}"
  fi

  echo -e "Duration: ${suite_duration}s"
  echo -e "${_CLR_CYAN}──────────────────────────────────────${_CLR_RESET}"
  echo ""

  # Write JSON report
  local report_dir
  report_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../results" 2>/dev/null && pwd)" || report_dir="/tmp"
  mkdir -p "${report_dir}" 2>/dev/null || true

  local report_file="${report_dir}/report.json"

  jq -n \
    --arg date "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --argjson passed "${_TESTS_PASSED}" \
    --argjson failed "${_TESTS_FAILED}" \
    --argjson skipped "${_TESTS_SKIPPED}" \
    --argjson total "${total}" \
    --argjson duration "${suite_duration}" \
    --argjson results "${_JSON_RESULTS}" \
    '{
      date: $date,
      summary: {
        total: $total,
        passed: $passed,
        failed: $failed,
        skipped: $skipped,
        duration_seconds: $duration,
        success: ($failed == 0)
      },
      results: $results
    }' > "${report_file}" 2>/dev/null

  echo "JSON report: ${report_file}"

  # Return exit code based on failures
  if [[ ${_TESTS_FAILED} -gt 0 ]]; then
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------------------
# reset_counters
# Reset all test counters (for running multiple stacks).
# ---------------------------------------------------------------------------
reset_counters() {
  _TESTS_PASSED=0
  _TESTS_FAILED=0
  _TESTS_SKIPPED=0
  _JSON_RESULTS="[]"
}
