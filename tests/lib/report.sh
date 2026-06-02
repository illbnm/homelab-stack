#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Test Report Generator
# Colored terminal output + JSON report file
# =============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

RESULT_DIR="${RESULT_DIR:-$SCRIPT_DIR/../results}"
REPORT_JSON="$RESULT_DIR/report.json"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

GLOBAL_PASSED=0
GLOBAL_FAILED=0
GLOBAL_SKIPPED=0
declare -A STACK_RESULTS
JSON_TESTS="[]"

report_init() {
  mkdir -p "$RESULT_DIR"
  echo "[]" > "$REPORT_JSON"
  STACK_RESULTS=()
  JSON_TESTS="[]"
}

print_header() {
  echo ""
  echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}${CYAN}║   HomeLab Stack — Integration Tests              ║${NC}"
  echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════╝${NC}"
  echo -e "  Started: $(date '+%Y-%m-%d %H:%M:%S')"
  echo -e "  ${BLUE}Platform: $(uname -m)${NC}"
  echo ""
}

report_test() {
  local stack="$1" test_name="$2" result="$3" duration="${4:-0.0}"
  local status_mark

  case "$result" in
    PASS)
      status_mark="${GREEN}✅ PASS${NC}"
      STACK_RESULTS["${stack}_passed"]=$((${STACK_RESULTS["${stack}_passed"]:-0} + 1))
      GLOBAL_PASSED=$((GLOBAL_PASSED + 1))
      ;;
    FAIL)
      status_mark="${RED}❌ FAIL${NC}"
      STACK_RESULTS["${stack}_failed"]=$((${STACK_RESULTS["${stack}_failed"]:-0} + 1))
      GLOBAL_FAILED=$((GLOBAL_FAILED + 1))
      ;;
    SKIP)
      status_mark="${YELLOW}⬜ SKIP${NC}"
      STACK_RESULTS["${stack}_skipped"]=$((${STACK_RESULTS["${stack}_skipped"]:-0} + 1))
      GLOBAL_SKIPPED=$((GLOBAL_SKIPPED + 1))
      ;;
  esac

  printf "  ${BOLD}[%-8s]${NC} %-45s %s (%.1fs)\n" "$stack" "$test_name" "$status_mark" "$duration"

  local entry
  entry=$(jq -n \
    --arg stack "$stack" \
    --arg name "$test_name" \
    --arg result "$result" \
    --argjson duration "$duration" \
    --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    '{stack: $stack, test: $name, result: $result, duration: $duration, timestamp: $timestamp}')

  JSON_TESTS=$(echo "$JSON_TESTS" | jq ". + [$entry]")
}

print_summary() {
  echo ""
  echo -e "${BOLD}──────────────────────────────────────────────────${NC}"
  echo -e "  Results: ${GREEN}$GLOBAL_PASSED passed${NC} | ${RED}$GLOBAL_FAILED failed${NC} | ${YELLOW}$GLOBAL_SKIPPED skipped${NC}"
  echo -e "  Total:   $((GLOBAL_PASSED + GLOBAL_FAILED + GLOBAL_SKIPPED)) tests"
  echo -e "  Duration: ${BOLD}${SECONDS}s${NC}"
  echo -e "${BOLD}──────────────────────────────────────────────────${NC}"

  if [[ $GLOBAL_FAILED -gt 0 ]]; then
    echo -e "\n  ${RED}${BOLD}⚠  TESTS FAILED${NC}"
  else
    echo -e "\n  ${GREEN}${BOLD}🎉 ALL TESTS PASSED${NC}"
  fi
}

write_json_report() {
  local total=$((GLOBAL_PASSED + GLOBAL_FAILED + GLOBAL_SKIPPED))
  local report
  report=$(jq -n \
    --arg timestamp "$TIMESTAMP" \
    --argjson passed "$GLOBAL_PASSED" \
    --argjson failed "$GLOBAL_FAILED" \
    --argjson skipped "$GLOBAL_SKIPPED" \
    --argjson total "$total" \
    --argjson duration "$SECONDS" \
    --arg arch "$(uname -m)" \
    --arg host "$(hostname)" \
    --argjson results "$JSON_TESTS" \
    '{
      meta: {
        timestamp: $timestamp,
        arch: $arch,
        host: $host,
        duration_seconds: $duration
      },
      summary: {
        passed: $passed,
        failed: $failed,
        skipped: $skipped,
        total: $total
      },
      results: $results
    }')

  echo "$report" | jq '.' > "$REPORT_JSON"
  echo -e "\n  ${BLUE}📄 JSON report:${NC} $REPORT_JSON"
}

print_stack_header() {
  local stack="$1"
  echo ""
  echo -e "${BOLD}${BLUE}═══ ${stack} ═══${NC}"
}
