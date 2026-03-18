#!/usr/bin/env bash
# =============================================================================
# report.sh — Test reporting (terminal + JSON)
# =============================================================================
set -uo pipefail

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

REPORT_JSON_ENABLED=0
REPORT_JSON_FILE=""
REPORT_RESULTS=()  # array of "PASS|FAIL|SKIP|test_name|stack|duration"

json_init() {
  REPORT_JSON_ENABLED=1
  REPORT_JSON_FILE="${1:-tests/results/report.json}"
  mkdir -p "$(dirname "$REPORT_JSON_FILE")"
  echo '{"tests":[],"summary":{"passed":0,"failed":0,"skipped":0,"duration":0}}' > "$REPORT_JSON_FILE"
}

test_start() {
  TEST_CURRENT="$1"
  TEST_START_TIME=$(date +%s%N 2>/dev/null || date +%s)
}

test_pass() {
  local dur
  dur=$(( ($(date +%s%N 2>/dev/null || date +%s) - TEST_START_TIME) / 1000000 ))
  dur="${dur}ms"
  REPORT_RESULTS+=("PASS|$TEST_CURRENT|$TEST_STACK|$dur")
  if [[ "$REPORT_JSON_ENABLED" -eq 1 ]]; then
    _json_append "PASS" "$TEST_CURRENT" "$TEST_STACK" "$dur" ""
  fi
}

test_fail() {
  local reason="${1:-$TEST_CURRENT}"
  local dur
  dur=$(( ($(date +%s%N 2>/dev/null || date +%s) - TEST_START_TIME) / 1000000 ))
  dur="${dur}ms"
  REPORT_RESULTS+=("FAIL|$TEST_CURRENT|$TEST_STACK|$dur|$reason")
  if [[ "$REPORT_JSON_ENABLED" -eq 1 ]]; then
    _json_append "FAIL" "$TEST_CURRENT" "$TEST_STACK" "$dur" "$reason"
  fi
}

test_skip() {
  local reason="${1:-$TEST_CURRENT}"
  local dur="0ms"
  REPORT_RESULTS+=("SKIP|$TEST_CURRENT|$TEST_STACK|$dur|$reason")
  if [[ "$REPORT_JSON_ENABLED" -eq 1 ]]; then
    _json_append "SKIP" "$TEST_CURRENT" "$TEST_STACK" "$dur" "$reason"
  fi
}

_json_append() {
  local status="$1" name="$2" stack="$3" dur="$4" reason="$5"
  # Simple append using tmp file (avoid jq dependency for JSON writing)
  local entry
  entry=$(cat <<ENTRY
{"status":"$status","name":"$name","stack":"$stack","duration":"$dur","reason":"$reason"}
ENTRY
)
  local tmp
  tmp=$(mktemp)
  if command -v jq &>/dev/null; then
    jq ".tests += [$entry] |
         .summary.passed = [.tests[].status | select(.==\"PASS\")] | length |
         .summary.failed = [.tests[].status | select(.==\"FAIL\")] | length |
         .summary.skipped = [.tests[].status | select(.==\"SKIP\")] | length" \
      "$REPORT_JSON_FILE" > "$tmp" && mv "$tmp" "$REPORT_JSON_FILE"
  else
    # Fallback: just append to a JSONL file
    echo "$entry" >> "${REPORT_JSON_FILE%.json}.jsonl"
  fi
}

print_summary() {
  local passed=0 failed=0 skipped=0
  for r in "${REPORT_RESULTS[@]}"; do
    IFS='|' read -r status name stack dur reason <<< "$r"
    case "$status" in
      PASS) ((passed++)); echo -e "  ${GREEN}✓${NC} ${DIM}[$stack]${NC} $name ${DIM}($dur)${NC}" ;;
      FAIL) ((failed++)); echo -e "  ${RED}✗${NC} ${DIM}[$stack]${NC} $name ${DIM}($dur)${NC}"; echo -e "       ${RED}$reason${NC}" ;;
      SKIP) ((skipped++)); echo -e "  ${YELLOW}~${NC} ${DIM}[$stack]${NC} $name ${DIM}($dur)${NC}" ;;
    esac
  done

  echo ""
  echo -e "${BOLD}──────────────────────────────────────${NC}"
  echo -e "  ${GREEN}$passed passed${NC} | ${RED}$failed failed${NC} | ${YELLOW}$skipped skipped${NC} | ${#REPORT_RESULTS[@]} total"
  echo -e "${BOLD}──────────────────────────────────────${NC}"
}
