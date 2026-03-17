#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Test Report Engine
# =============================================================================
# Handles test result recording, terminal color output, and JSON report
# generation.
#
# Usage:
#   source tests/lib/report.sh
#   report_init
#   ... run tests ...
#   report_summary
# =============================================================================

# Guard against double-sourcing
[[ -n "${__REPORT_SH_LOADED:-}" ]] && return 0
readonly __REPORT_SH_LOADED=1

# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------
readonly _CLR_RED='\033[0;31m'
readonly _CLR_GREEN='\033[0;32m'
readonly _CLR_YELLOW='\033[1;33m'
readonly _CLR_BLUE='\033[0;34m'
readonly _CLR_CYAN='\033[0;36m'
readonly _CLR_BOLD='\033[1m'
readonly _CLR_DIM='\033[2m'
readonly _CLR_NC='\033[0m'

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
_PASS_COUNT=0
_FAIL_COUNT=0
_SKIP_COUNT=0
_TOTAL_COUNT=0
_START_TIME=0
_RESULTS_JSON="[]"
_REPORT_DIR=""
_JSON_OUTPUT=false

# Current test context (set by the test runner)
CURRENT_TEST_NAME=""
CURRENT_STACK=""

# ---------------------------------------------------------------------------
# Initialization
# ---------------------------------------------------------------------------

# report_init [results_dir]
report_init() {
  _REPORT_DIR="${1:-tests/results}"
  _PASS_COUNT=0
  _FAIL_COUNT=0
  _SKIP_COUNT=0
  _TOTAL_COUNT=0
  _START_TIME=$(date +%s)
  _RESULTS_JSON="[]"

  mkdir -p "${_REPORT_DIR}"

  # Banner
  echo ""
  echo -e "${_CLR_CYAN}╔══════════════════════════════════════╗${_CLR_NC}"
  echo -e "${_CLR_CYAN}║${_CLR_BOLD}   HomeLab Stack — Integration Tests  ${_CLR_NC}${_CLR_CYAN}║${_CLR_NC}"
  echo -e "${_CLR_CYAN}╚══════════════════════════════════════╝${_CLR_NC}"
  echo ""
}

# report_set_json_output <true|false>
report_set_json_output() {
  _JSON_OUTPUT="${1:-false}"
}

# ---------------------------------------------------------------------------
# Recording results
# ---------------------------------------------------------------------------

# _record_result <status> <test_name> <message> <stack>
# Called by assertions in assert.sh.
_record_result() {
  local status="$1"
  local test_name="$2"
  local message="$3"
  local stack="${4:-unknown}"
  local duration=""

  _TOTAL_COUNT=$((_TOTAL_COUNT + 1))

  # Calculate per-test duration if _TEST_START is set
  if [[ -n "${_TEST_START:-}" ]]; then
    local now
    now=$(date +%s)
    duration="$(( now - _TEST_START ))s"
  fi

  case "${status}" in
    PASS)
      _PASS_COUNT=$((_PASS_COUNT + 1))
      echo -e "${_CLR_DIM}[${stack}]${_CLR_NC} ▶ ${test_name}          ${_CLR_GREEN}✅ PASS${_CLR_NC} ${_CLR_DIM}(${duration:-?})${_CLR_NC}"
      ;;
    FAIL)
      _FAIL_COUNT=$((_FAIL_COUNT + 1))
      echo -e "${_CLR_DIM}[${stack}]${_CLR_NC} ▶ ${test_name}          ${_CLR_RED}❌ FAIL${_CLR_NC} ${_CLR_DIM}(${duration:-?})${_CLR_NC}"
      echo -e "       ${_CLR_RED}${message}${_CLR_NC}"
      ;;
    SKIP)
      _SKIP_COUNT=$((_SKIP_COUNT + 1))
      echo -e "${_CLR_DIM}[${stack}]${_CLR_NC} ▶ ${test_name}          ${_CLR_YELLOW}⏭ SKIP${_CLR_NC} ${_CLR_DIM}(${duration:-?})${_CLR_NC}"
      if [[ -n "${message}" ]]; then
        echo -e "       ${_CLR_YELLOW}${message}${_CLR_NC}"
      fi
      ;;
  esac

  # Append to JSON results array (escape special characters for valid JSON)
  local safe_msg="${message//\\/\\\\}"  # backslashes first
  safe_msg="${safe_msg//\"/\\\"}"        # double quotes
  safe_msg="${safe_msg//$'\n'/\\n}"      # newlines
  safe_msg="${safe_msg//$'\r'/\\r}"      # carriage returns
  safe_msg="${safe_msg//$'\t'/\\t}"      # tabs

  local json_entry
  json_entry=$(printf '{"stack":"%s","test":"%s","status":"%s","message":"%s","duration":"%s"}' \
    "${stack}" "${test_name}" "${status}" "${safe_msg}" "${duration:-0s}")

  if [[ "${_RESULTS_JSON}" == "[]" ]]; then
    _RESULTS_JSON="[${json_entry}]"
  else
    _RESULTS_JSON="${_RESULTS_JSON%]},${json_entry}]"
  fi
}

# ---------------------------------------------------------------------------
# Stack section headers
# ---------------------------------------------------------------------------

# report_stack_start <stack_name>
report_stack_start() {
  local stack="$1"
  CURRENT_STACK="${stack}"
  echo ""
  echo -e "${_CLR_BLUE}${_CLR_BOLD}--- ${stack} ---${_CLR_NC}"
}

# report_test_start <test_name>
# Call before each test function to set context and timer.
report_test_start() {
  CURRENT_TEST_NAME="$1"
  _TEST_START=$(date +%s)
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

# report_summary
# Prints the final summary and writes the JSON report.
report_summary() {
  local end_time
  end_time=$(date +%s)
  local total_duration=$(( end_time - _START_TIME ))

  echo ""
  echo -e "${_CLR_DIM}──────────────────────────────────────${_CLR_NC}"
  echo -e "Results: ${_CLR_GREEN}${_PASS_COUNT} passed${_CLR_NC}, ${_CLR_RED}${_FAIL_COUNT} failed${_CLR_NC}, ${_CLR_YELLOW}${_SKIP_COUNT} skipped${_CLR_NC}"
  echo -e "Duration: ${total_duration}s"
  echo -e "${_CLR_DIM}──────────────────────────────────────${_CLR_NC}"
  echo ""

  # Write JSON report (always write if --json was passed, or if results dir exists)
  if [[ "${_JSON_OUTPUT}" == true ]]; then
    _write_json_report "${total_duration}"
  fi

  # Return non-zero if any tests failed
  if [[ "${_FAIL_COUNT}" -gt 0 ]]; then
    echo -e "${_CLR_RED}${_CLR_BOLD}Some tests failed!${_CLR_NC}"
    return 1
  else
    echo -e "${_CLR_GREEN}${_CLR_BOLD}All tests passed!${_CLR_NC}"
    return 0
  fi
}

# _write_json_report <total_duration>
_write_json_report() {
  local total_duration="$1"
  local report_file="${_REPORT_DIR}/report.json"
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%S")

  cat > "${report_file}" <<EOF
{
  "timestamp": "${timestamp}",
  "duration_seconds": ${total_duration},
  "summary": {
    "total": ${_TOTAL_COUNT},
    "passed": ${_PASS_COUNT},
    "failed": ${_FAIL_COUNT},
    "skipped": ${_SKIP_COUNT}
  },
  "results": ${_RESULTS_JSON}
}
EOF

  echo -e "${_CLR_DIM}JSON report: ${report_file}${_CLR_NC}"
}

# ---------------------------------------------------------------------------
# Getters for CI scripts
# ---------------------------------------------------------------------------

report_pass_count() { echo "${_PASS_COUNT}"; }
report_fail_count() { echo "${_FAIL_COUNT}"; }
report_skip_count() { echo "${_SKIP_COUNT}"; }
report_total_count() { echo "${_TOTAL_COUNT}"; }
