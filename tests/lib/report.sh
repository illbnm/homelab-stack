#!/usr/bin/env bash
# =============================================================================
# report.sh — Test result reporting (JSON + colored terminal output)
# =============================================================================

# Colors
_RED='\033[0;31m'
_GREEN='\033[0;32m'
_YELLOW='\033[1;33m'
_BLUE='\033[0;34m'
_CYAN='\033[0;36m'
_BOLD='\033[1m'
_DIM='\033[2m'
_NC='\033[0m'

# Counters
_TOTAL_PASSED=0
_TOTAL_FAILED=0
_TOTAL_SKIPPED=0
_CURRENT_SUITE=""
_SUITE_PASSED=0
_SUITE_FAILED=0
_SUITE_SKIPPED=0

# JSON results accumulator
_JSON_RESULTS="[]"
_JSON_SUITES="[]"

# Start a test suite (group)
# Usage: test_suite "suite_name"
test_suite() {
  # Save previous suite results if any
  if [[ -n "$_CURRENT_SUITE" ]]; then
    _save_suite_json
  fi
  _CURRENT_SUITE="$1"
  _SUITE_PASSED=0
  _SUITE_FAILED=0
  _SUITE_SKIPPED=0
  echo ""
  echo -e "${_BLUE}${_BOLD}━━━ $1 ━━━${_NC}"
}

# Record a passing test
# Usage: test_pass "description"
test_pass() {
  local desc="$1"
  echo -e "  ${_GREEN}✓${_NC} $desc"
  ((_TOTAL_PASSED++))
  ((_SUITE_PASSED++))
  _add_result "pass" "$_CURRENT_SUITE" "$desc" ""
}

# Record a failing test
# Usage: test_fail "description" "reason"
test_fail() {
  local desc="$1" reason="${2:-}"
  if [[ -n "$reason" ]]; then
    echo -e "  ${_RED}✗${_NC} $desc ${_DIM}($reason)${_NC}"
  else
    echo -e "  ${_RED}✗${_NC} $desc"
  fi
  ((_TOTAL_FAILED++))
  ((_SUITE_FAILED++))
  _add_result "fail" "$_CURRENT_SUITE" "$desc" "$reason"
}

# Record a skipped test
# Usage: test_skip "description" "reason"
test_skip() {
  local desc="$1" reason="${2:-not available}"
  echo -e "  ${_YELLOW}○${_NC} $desc ${_DIM}($reason)${_NC}"
  ((_TOTAL_SKIPPED++))
  ((_SUITE_SKIPPED++))
  _add_result "skip" "$_CURRENT_SUITE" "$desc" "$reason"
}

# Print the final summary
# Usage: test_summary
test_summary() {
  # Save last suite
  if [[ -n "$_CURRENT_SUITE" ]]; then
    _save_suite_json
  fi

  local total=$((_TOTAL_PASSED + _TOTAL_FAILED + _TOTAL_SKIPPED))

  echo ""
  echo -e "${_BOLD}════════════════════════════════════════${_NC}"
  echo -e "  ${_BOLD}Test Results${_NC}"
  echo -e "${_BOLD}════════════════════════════════════════${_NC}"
  echo -e "  ${_GREEN}Passed:${_NC}  $_TOTAL_PASSED"
  echo -e "  ${_RED}Failed:${_NC}  $_TOTAL_FAILED"
  echo -e "  ${_YELLOW}Skipped:${_NC} $_TOTAL_SKIPPED"
  echo -e "  ${_CYAN}Total:${_NC}   $total"
  echo -e "${_BOLD}════════════════════════════════════════${_NC}"

  if [[ $_TOTAL_FAILED -eq 0 ]]; then
    echo -e "  ${_GREEN}${_BOLD}ALL TESTS PASSED${_NC}"
  else
    echo -e "  ${_RED}${_BOLD}$_TOTAL_FAILED TEST(S) FAILED${_NC}"
  fi
  echo -e "${_BOLD}════════════════════════════════════════${_NC}"
}

# Write JSON report to file
# Usage: test_report_json "output_file"
test_report_json() {
  local output="${1:-test-results.json}"

  # Save last suite if not already saved
  if [[ -n "$_CURRENT_SUITE" ]]; then
    _save_suite_json
    _CURRENT_SUITE=""
  fi

  local total=$((_TOTAL_PASSED + _TOTAL_FAILED + _TOTAL_SKIPPED))

  if command -v jq &>/dev/null; then
    jq -n \
      --argjson passed "$_TOTAL_PASSED" \
      --argjson failed "$_TOTAL_FAILED" \
      --argjson skipped "$_TOTAL_SKIPPED" \
      --argjson total "$total" \
      --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      --argjson suites "$_JSON_SUITES" \
      --argjson results "$_JSON_RESULTS" \
      '{
        timestamp: $timestamp,
        summary: { total: $total, passed: $passed, failed: $failed, skipped: $skipped },
        suites: $suites,
        results: $results
      }' > "$output"
  else
    # Fallback: write JSON manually without jq
    cat > "$output" <<ENDJSON
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "summary": {
    "total": $total,
    "passed": $_TOTAL_PASSED,
    "failed": $_TOTAL_FAILED,
    "skipped": $_TOTAL_SKIPPED
  }
}
ENDJSON
  fi

  echo -e "\n  ${_DIM}JSON report: $output${_NC}"
}

# Internal: add a result to the JSON accumulator
_add_result() {
  local status="$1" suite="$2" desc="$3" reason="$4"
  if command -v jq &>/dev/null; then
    _JSON_RESULTS=$(echo "$_JSON_RESULTS" | jq \
      --arg status "$status" \
      --arg suite "$suite" \
      --arg desc "$desc" \
      --arg reason "$reason" \
      '. + [{ status: $status, suite: $suite, test: $desc, reason: $reason }]')
  fi
}

# Internal: save suite summary to JSON
_save_suite_json() {
  if command -v jq &>/dev/null; then
    _JSON_SUITES=$(echo "$_JSON_SUITES" | jq \
      --arg name "$_CURRENT_SUITE" \
      --argjson passed "$_SUITE_PASSED" \
      --argjson failed "$_SUITE_FAILED" \
      --argjson skipped "$_SUITE_SKIPPED" \
      '. + [{ name: $name, passed: $passed, failed: $failed, skipped: $skipped }]')
  fi
}
