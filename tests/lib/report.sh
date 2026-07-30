#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
# Report Library — Test Result Output (Terminal Colored + JSON)
# ════════════════════════════════════════════════════════════════

REPORT_TOTAL=0
REPORT_PASSED=0
REPORT_FAILED=0
REPORT_SKIPPED=0
REPORT_START_TIME=""
REPORT_SECTIONS=()
REPORT_RESULTS=()
JSON_MODE=false

# Colors
if [[ -t 1 ]]; then
  C_GREEN='\033[0;32m'
  C_RED='\033[0;31m'
  C_YELLOW='\033[1;33m'
  C_BLUE='\033[0;34m'
  C_BOLD='\033[1m'
  C_DIM='\033[2m'
  C_NC='\033[0m'
else
  C_GREEN=''; C_RED=''; C_YELLOW=''; C_BLUE=''; C_BOLD=''; C_DIM=''; C_NC=''
fi

report_init() {
  JSON_MODE="${1:-false}"
  REPORT_START_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  if ! $JSON_MODE; then
    echo -e "${C_BOLD}═══════════════════════════════════════════════════${C_NC}"
    echo -e "${C_BOLD}  HomeLab Stack Integration Tests${C_NC}"
    echo -e "${C_BOLD}  Started: ${REPORT_START_TIME}${C_NC}"
    echo -e "${C_BOLD}═══════════════════════════════════════════════════${C_NC}"
    echo ""
  fi
}

report_section() {
  local name="$1"
  REPORT_SECTIONS+=("$name")
  if ! $JSON_MODE; then
    echo -e "${C_BLUE}── ${name} ${C_NC}"
  fi
}

report_test_start() {
  local name="$1"
  REPORT_TOTAL=$((REPORT_TOTAL + 1))
  if ! $JSON_MODE; then
    echo -ne "  ${C_DIM}${name}...${C_NC}"
  fi
}

report_test_pass() {
  local name="$1"
  REPORT_PASSED=$((REPORT_PASSED + 1))
  REPORT_RESULTS+=("{\"name\":\"${name}\",\"status\":\"pass\"}")
  if ! $JSON_MODE; then
    echo -e "\r  ${C_GREEN}✓${C_NC} ${name}"
  fi
}

report_test_fail() {
  local name="$1" reason="${2:-Unknown failure}"
  REPORT_FAILED=$((REPORT_FAILED + 1))
  REPORT_RESULTS+=("{\"name\":\"${name}\",\"status\":\"fail\",\"reason\":\"${reason}\"}")
  if ! $JSON_MODE; then
    echo -e "\r  ${C_RED}✗${C_NC} ${name}"
    echo -e "    ${C_RED}${reason}${C_NC}"
  fi
}

report_test_end() {
  local name="$1"
  if ! $JSON_MODE; then
    : # Already printed
  fi
}

report_skip() {
  local name="$1" reason="${2:-Skipped}"
  REPORT_SKIPPED=$((REPORT_SKIPPED + 1))
  if ! $JSON_MODE; then
    echo -e "  ${C_YELLOW}⊘ ${name}${C_NC} ${C_DIM}(${reason})${C_NC}"
  fi
}

report_summary() {
  local duration
  duration=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  if $JSON_MODE; then
    echo "{"
    echo "  \"started\": \"${REPORT_START_TIME}\","
    echo "  \"finished\": \"${duration}\","
    echo "  \"total\": ${REPORT_TOTAL},"
    echo "  \"passed\": ${REPORT_PASSED},"
    echo "  \"failed\": ${REPORT_FAILED},"
    echo "  \"skipped\": ${REPORT_SKIPPED},"
    echo "  \"results\": ["
    local first=true
    for r in "${REPORT_RESULTS[@]}"; do
      if $first; then first=false; else echo ","; fi
      echo "    ${r}"
    done
    echo ""
    echo "  ]"
    echo "}"
  else
    echo ""
    echo -e "${C_BOLD}═══════════════════════════════════════════════════${C_NC}"
    echo -e "  Total:   ${REPORT_TOTAL}"
    echo -e "  ${C_GREEN}Passed:  ${REPORT_PASSED}${C_NC}"
    if [[ $REPORT_FAILED -gt 0 ]]; then
      echo -e "  ${C_RED}Failed:  ${REPORT_FAILED}${C_NC}"
    else
      echo -e "  Failed:  ${REPORT_FAILED}"
    fi
    echo -e "  ${C_YELLOW}Skipped: ${REPORT_SKIPPED}${C_NC}"
    echo -e "${C_BOLD}═══════════════════════════════════════════════════${C_NC}"
  fi

  if [[ $REPORT_FAILED -gt 0 ]]; then
    return 1
  fi
  return 0
}