#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Test Report Generator
# Generates JSON and terminal reports for test results
# =============================================================================

set -euo pipefail

# =============================================================================
# Report Variables
# =============================================================================

REPORT_DIR="tests/results"
REPORT_FILE="$REPORT_DIR/report.json"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# =============================================================================
# Report Functions
# =============================================================================

init_report() {
  mkdir -p "$REPORT_DIR"
  
  # Initialize empty JSON report
  cat > "$REPORT_FILE" << EOF
{
  "timestamp": "$TIMESTAMP",
  "tests": [],
  "summary": {
    "total": 0,
    "passed": 0,
    "failed": 0,
    "skipped": 0,
    "duration": 0
  }
}
EOF
}

add_test_result() {
  local stack="$1"
  local name="$2"
  local status="$3"
  local duration="$4"
  local message="${5:-}"
  
  # Add test result to JSON
  local tmp_file=$(mktemp)
  jq --arg stack "$stack" \
     --arg name "$name" \
     --arg status "$status" \
     --arg duration "$duration" \
     --arg message "$message" \
     '.tests += [{
       "stack": $stack,
       "name": $name,
       "status": $status,
       "duration": $duration,
       "message": $message
     }]' "$REPORT_FILE" > "$tmp_file"
  
  mv "$tmp_file" "$REPORT_FILE"
  
  # Update summary
  update_summary "$status"
}

update_summary() {
  local status="$1"
  
  local tmp_file=$(mktemp)
  jq --arg status "$status" '
    .summary.total += 1 |
    if $status == "PASS" then .summary.passed += 1
    elif $status == "FAIL" then .summary.failed += 1
    elif $status == "SKIP" then .summary.skipped += 1
    else . end
  ' "$REPORT_FILE" > "$tmp_file"
  
  mv "$tmp_file" "$REPORT_FILE"
}

finalize_report() {
  local duration="$1"
  
  # Add final duration
  local tmp_file=$(mktemp)
  jq --arg duration "$duration" '.summary.duration = $duration' "$REPORT_FILE" > "$tmp_file"
  mv "$tmp_file" "$REPORT_FILE"
}

# =============================================================================
# Terminal Output Functions
# =============================================================================

print_header() {
  cat << 'EOF'
╔══════════════════════════════════════╗
║   HomeLab Stack — Integration Tests  ║
╚══════════════════════════════════════╝
EOF
}

print_test_result() {
  local stack="$1"
  local name="$2"
  local status="$3"
  local duration="$4"
  
  local status_icon status_color
  case "$status" in
    PASS)
      status_icon="✅"
      status_color='\033[0;32m'
      ;;
    FAIL)
      status_icon="❌"
      status_color='\033[0;31m'
      ;;
    SKIP)
      status_icon="⏭ "
      status_color='\033[1;33m'
      ;;
    *)
      status_icon="❓"
      status_color='\033[0m'
      ;;
  esac
  
  echo -e "[${stack}] ▶ ${name} ${status_color}${status_icon} ${status}${RESET} (${duration}s)"
}

print_summary() {
  local passed="$1"
  local failed="$2"
  local skipped="$3"
  local duration="$4"
  
  echo ""
  echo "──────────────────────────────────────"
  echo -e "Results: ${GREEN}${passed} passed${RESET}, ${RED}${failed} failed${RESET}, ${YELLOW}${skipped} skipped${RESET}"
  echo "Duration: ${duration}s"
  echo "──────────────────────────────────────"
  
  if [ "$failed" -gt 0 ]; then
    echo -e "${RED}Some tests failed. Please check the output above.${RESET}"
    return 1
  else
    echo -e "${GREEN}All tests passed! ✅${RESET}"
    return 0
  fi
}

# =============================================================================
# Export Functions
# =============================================================================

export_junit_xml() {
  local output_file="${1:-$REPORT_DIR/junit.xml}"
  
  # Convert JSON to JUnit XML format
  jq -r '
    "<testsuites>",
    "<testsuite name=\"Homelab Integration Tests\" tests=\"\(.summary.total)\" failures=\"\(.summary.failed)\" skipped=\"\(.summary.skipped)\">",
    (.tests[] | 
      "  <testcase classname=\"\(.stack)\" name=\"\(.name)\" time=\"\(.duration)\">" +
      if .status == "FAIL" then
        "<failure message=\"\(.message)\"/>"
      elif .status == "SKIP" then
        "<skipped message=\"\(.message)\"/>"
      else
        ""
      end +
      "  </testcase>"
    ),
    "</testsuite>",
    "</testsuites>"
  ' "$REPORT_FILE" > "$output_file"
}
