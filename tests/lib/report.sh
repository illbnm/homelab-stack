#!/usr/bin/env bash
# =============================================================================
# report.sh — Test result reporting (terminal + JSON)
# =============================================================================
# Generates:
#   - Colorized terminal output with summary
#   - JSON report at tests/results/report.json
# =============================================================================

set -euo pipefail

_REPORT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/results"
RESULTS_DIR="${_REPORT_DIR}"

# ---------------------------------------------------------------------------
# Terminal output
# ---------------------------------------------------------------------------

print_header() {
  local title="${1:-HomeLab Stack — Integration Tests}"
  echo ""
  echo -e "${CYAN:-}╔══════════════════════════════════════════════╗${RESET:-}"
  echo -e "${CYAN:-}║  ${BOLD:-}${title}${RESET:-}${CYAN:-}  ║${RESET:-}"
  echo -e "${CYAN:-}╚══════════════════════════════════════════════╝${RESET:-}"
  echo ""
}

print_stack_header() {
  local stack="$1"
  echo ""
  echo -e "${BOLD:-}── ${stack} ──────────────────────────────────${RESET:-}"
}

print_separator() {
  echo -e "${CYAN:-}──────────────────────────────────────────────${RESET:-}"
}

print_summary() {
  local pass="${1:-0}"
  local fail="${2:-0}"
  local skip="${3:-0}"
  local duration="${4:-0}"
  local total=$(( pass + fail + skip ))

  echo ""
  print_separator
  echo -e "${BOLD:-}Results:${RESET:-} ${GREEN:-}${pass} passed${RESET:-}, ${RED:-}${fail} failed${RESET:-}, ${YELLOW:-}${skip} skipped${RESET:-}"
  echo -e "${BOLD:-}Total:${RESET:-}   ${total} tests"
  echo -e "${BOLD:-}Duration:${RESET:-} ${duration}s"
  print_separator
  echo ""

  if [[ "$fail" -gt 0 ]]; then
    echo -e "${RED:-}${BOLD:-}⚠ Some tests failed!${RESET:-}"
  else
    echo -e "${GREEN:-}${BOLD:-}✅ All tests passed!${RESET:-}"
  fi
  echo ""
}

# ---------------------------------------------------------------------------
# JSON report
# ---------------------------------------------------------------------------

# Initialize JSON report
# Usage: init_json_report
init_json_report() {
  mkdir -p "$RESULTS_DIR"
  cat > "${RESULTS_DIR}/report.json" <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "hostname": "$(hostname)",
  "docker_version": "$(docker --version 2>/dev/null | head -1)",
  "stacks": [],
  "summary": {
    "passed": 0,
    "failed": 0,
    "skipped": 0,
    "duration_seconds": 0
  }
}
EOF
}

# Add a stack's test results to JSON report
# Usage: add_stack_to_json <stack_name> <pass> <fail> <skip> <duration>
#   Then pipe test_results into this function
add_stack_to_json() {
  local stack="$1"
  local pass="$2"
  local fail="$3"
  local skip="$4"
  local duration="$5"

  if ! command -v jq &>/dev/null; then
    return 0
  fi

  local report="${RESULTS_DIR}/report.json"

  # Build tests array from _TEST_RESULTS
  local tests_json="[]"
  for result in "${_TEST_RESULTS[@]}"; do
    local status msg detail
    IFS='|' read -r status _ msg detail <<< "$result"
    tests_json=$(echo "$tests_json" | jq \
      --arg status "$status" \
      --arg msg "$msg" \
      --arg detail "${detail:-}" \
      '. + [{"status": $status, "name": $msg, "detail": $detail}]')
  done

  # Add stack to report
  local tmp
  tmp=$(jq \
    --arg stack "$stack" \
    --argjson pass "$pass" \
    --argjson fail "$fail" \
    --argjson skip "$skip" \
    --argjson duration "$duration" \
    --argjson tests "$tests_json" \
    '.stacks += [{"name": $stack, "passed": $pass, "failed": $fail, "skipped": $skip, "duration_seconds": $duration, "tests": $tests}]' \
    "$report")
  echo "$tmp" > "$report"
}

# Finalize JSON report with summary
# Usage: finalize_json_report <total_pass> <total_fail> <total_skip> <total_duration>
finalize_json_report() {
  local pass="$1"
  local fail="$2"
  local skip="$3"
  local duration="$4"

  if ! command -v jq &>/dev/null; then
    return 0
  fi

  local report="${RESULTS_DIR}/report.json"
  local tmp
  tmp=$(jq \
    --argjson pass "$pass" \
    --argjson fail "$fail" \
    --argjson skip "$skip" \
    --argjson duration "$duration" \
    '.summary = {"passed": $pass, "failed": $fail, "skipped": $skip, "duration_seconds": $duration}' \
    "$report")
  echo "$tmp" > "$report"
}

# ---------------------------------------------------------------------------
# JUnit XML report (for CI integration)
# ---------------------------------------------------------------------------

# Generate JUnit XML from JSON report
# Usage: generate_junit_xml
generate_junit_xml() {
  if ! command -v jq &>/dev/null; then
    return 0
  fi

  local report="${RESULTS_DIR}/report.json"
  local junit="${RESULTS_DIR}/junit.xml"

  local total pass fail skip duration
  total=$(jq '.summary.passed + .summary.failed + .summary.skipped' "$report")
  pass=$(jq '.summary.passed' "$report")
  fail=$(jq '.summary.failed' "$report")
  skip=$(jq '.summary.skipped' "$report")
  duration=$(jq '.summary.duration_seconds' "$report")

  cat > "$junit" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<testsuites tests="${total}" failures="${fail}" skipped="${skip}" time="${duration}">
EOF

  # Add each stack as a testsuite
  jq -r '.stacks[] | @base64' "$report" | while read -r stack_b64; do
    local s
    s=$(echo "$stack_b64" | base64 -d)
    local name s_pass s_fail s_skip s_dur
    name=$(echo "$s" | jq -r '.name')
    s_pass=$(echo "$s" | jq '.passed')
    s_fail=$(echo "$s" | jq '.failed')
    s_skip=$(echo "$s" | jq '.skipped')
    s_dur=$(echo "$s" | jq '.duration_seconds')

    echo "  <testsuite name=\"${name}\" tests=\"$(( s_pass + s_fail + s_skip ))\" failures=\"${s_fail}\" skipped=\"${s_skip}\" time=\"${s_dur}\">" >> "$junit"

    echo "$s" | jq -r '.tests[] | @base64' | while read -r test_b64; do
      local t t_status t_name t_detail
      t=$(echo "$test_b64" | base64 -d)
      t_status=$(echo "$t" | jq -r '.status')
      t_name=$(echo "$t" | jq -r '.name')
      t_detail=$(echo "$t" | jq -r '.detail // ""')

      echo "    <testcase name=\"${t_name}\">" >> "$junit"
      if [[ "$t_status" == "FAIL" ]]; then
        echo "      <failure message=\"${t_detail}\"/>" >> "$junit"
      elif [[ "$t_status" == "SKIP" ]]; then
        echo "      <skipped message=\"${t_detail}\"/>" >> "$junit"
      fi
      echo "    </testcase>" >> "$junit"
    done

    echo "  </testsuite>" >> "$junit"
  done

  echo "</testsuites>" >> "$junit"
}
