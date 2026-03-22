#!/usr/bin/env bash
# report.sh — Colored terminal output and JSON report generation

REPORT_DIR="${REPORT_DIR:-tests/results}"
REPORT_FILE="${REPORT_DIR}/report.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Arrays to collect results
declare -a REPORT_RESULTS=()
REPORT_SUITE_NAME=""
REPORT_START_TIME=0

report_suite_start() {
  local suite="$1"
  REPORT_SUITE_NAME="$suite"
  REPORT_START_TIME=$(date +%s%3N)
  echo -e "\n${BOLD}${BLUE}══════════════════════════════════════════${NC}"
  echo -e "${BOLD}${CYAN}  Suite: ${suite}${NC}"
  echo -e "${BOLD}${BLUE}══════════════════════════════════════════${NC}"
}

report_test_result() {
  local test_name="$1"
  local status="$2"   # PASS | FAIL | SKIP
  local duration_ms="$3"
  local message="${4:-}"

  local entry
  entry=$(jq -n \
    --arg suite "$REPORT_SUITE_NAME" \
    --arg name "$test_name" \
    --arg status "$status" \
    --argjson duration "$duration_ms" \
    --arg message "$message" \
    '{suite: $suite, name: $name, status: $status, duration_ms: $duration, message: $message}')
  REPORT_RESULTS+=("$entry")

  case "$status" in
    PASS) echo -e "  ${GREEN}✓${NC} [${duration_ms}ms] ${test_name}" ;;
    FAIL) echo -e "  ${RED}✗${NC} [${duration_ms}ms] ${test_name}${message:+ → $message}" ;;
    SKIP) echo -e "  ${YELLOW}⊘${NC} [${duration_ms}ms] ${test_name}${message:+ (${message})}" ;;
  esac
}

report_suite_end() {
  local pass="$1"
  local fail="$2"
  local skip="$3"
  local end_time
  end_time=$(date +%s%3N)
  local total_ms=$((end_time - REPORT_START_TIME))
  echo -e "${BLUE}──────────────────────────────────────────${NC}"
  echo -e "  ${GREEN}Pass: ${pass}${NC}  ${RED}Fail: ${fail}${NC}  ${YELLOW}Skip: ${skip}${NC}  (${total_ms}ms)"
}

report_write_json() {
  local total_pass="$1"
  local total_fail="$2"
  local total_skip="$3"

  mkdir -p "$REPORT_DIR"

  local results_json="["
  local first=1
  for entry in "${REPORT_RESULTS[@]}"; do
    if [[ $first -eq 1 ]]; then
      results_json+="$entry"
      first=0
    else
      results_json+=",${entry}"
    fi
  done
  results_json+="]"

  jq -n \
    --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --argjson pass "$total_pass" \
    --argjson fail "$total_fail" \
    --argjson skip "$total_skip" \
    --argjson results "$results_json" \
    '{
      timestamp: $timestamp,
      summary: {pass: $pass, fail: $fail, skip: $skip},
      results: $results
    }' > "$REPORT_FILE"

  echo -e "\n${CYAN}Report written to: ${REPORT_FILE}${NC}"
}

report_final_summary() {
  local total_pass="$1"
  local total_fail="$2"
  local total_skip="$3"

  echo -e "\n${BOLD}${BLUE}══════════════════════════════════════════${NC}"
  echo -e "${BOLD}  FINAL RESULTS${NC}"
  echo -e "${BOLD}${BLUE}══════════════════════════════════════════${NC}"
  echo -e "  ${GREEN}${BOLD}Pass: ${total_pass}${NC}"
  echo -e "  ${RED}${BOLD}Fail: ${total_fail}${NC}"
  echo -e "  ${YELLOW}${BOLD}Skip: ${total_skip}${NC}"
  echo -e "${BOLD}${BLUE}══════════════════════════════════════════${NC}"

  if [[ $total_fail -gt 0 ]]; then
    echo -e "\n${RED}${BOLD}RESULT: FAILED${NC}\n"
    return 1
  else
    echo -e "\n${GREEN}${BOLD}RESULT: PASSED${NC}\n"
    return 0
  fi
}
