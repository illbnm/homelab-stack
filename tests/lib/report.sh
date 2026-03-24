#!/usr/bin/env bash
# =============================================================================
# Test Report Functions — JSON + Terminal colored output
# =============================================================================

REPORT_FILE=""

report_init() {
  REPORT_START=$SECONDS
  PASSED=0
  FAILED=0
  SKIPPED=0
  declare -gA REPORT_STACKS=()
  declare -ga REPORT_FAILURES=()
}

report_stack_begin() {
  local stack="$1"
  REPORT_STACKS["$stack-start"]=$SECONDS
  REPORT_STACKS["$stack-pass"]=0
  REPORT_STACKS["$stack-fail"]=0
  REPORT_STACKS["$stack-skip"]=0
}

report_stack_end() {
  local stack="$1"
  REPORT_STACKS["$stack-duration"]=$((SECONDS - ${REPORT_STACKS["$stack-start"]:-0}))
}

report_add_failure() {
  REPORT_FAILURES+=("$1")
}

report_summary() {
  local duration=$((SECONDS - REPORT_START))
  local total=$((PASSED + FAILED + SKIPPED))

  echo ""
  echo -e "${BOLD}╔════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║          TEST RESULTS SUMMARY          ║${NC}"
  echo -e "${BOLD}╠════════════════════════════════════════╣${NC}"
  printf  "${BOLD}║${NC}  Total:   %-28s${BOLD}║${NC}\n" "$total"
  printf  "${BOLD}║${NC}  ${GREEN}Passed:  %-28s${NC}${BOLD}║${NC}\n" "$PASSED"
  printf  "${BOLD}║${NC}  ${RED}Failed:  %-28s${NC}${BOLD}║${NC}\n" "$FAILED"
  printf  "${BOLD}║${NC}  ${YELLOW}Skipped: %-28s${NC}${BOLD}║${NC}\n" "$SKIPPED"
  printf  "${BOLD}║${NC}  Duration: ${duration}s%25s${BOLD}║${NC}\n" ""
  echo -e "${BOLD}╚════════════════════════════════════════╝${NC}"

  if [[ ${#REPORT_FAILURES[@]} -gt 0 ]]; then
    echo ""
    echo -e "${RED}${BOLD}Failed Tests:${NC}"
    for f in "${REPORT_FAILURES[@]}"; do
      echo -e "  ${RED}•${NC} $f"
    done
  fi
}

report_json() {
  local duration=$((SECONDS - REPORT_START))
  local total=$((PASSED + FAILED + SKIPPED))
  local status="pass"
  [[ $FAILED -gt 0 ]] && status="fail"

  # Build per-stack JSON
  local stacks_json=""
  for key in "${!REPORT_STACKS[@]}"; do
    :
  done

  # Build failures JSON array
  local failures_json="["
  local first=true
  for f in "${REPORT_FAILURES[@]+"${REPORT_FAILURES[@]}"}"; do
    if [[ "$first" == "true" ]]; then
      first=false
    else
      failures_json+=","
    fi
    failures_json+="\"$(echo "$f" | sed 's/"/\\"/g')\""
  done
  failures_json+="]"

  cat <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "status": "$status",
  "duration_seconds": $duration,
  "results": {
    "passed": $PASSED,
    "failed": $FAILED,
    "skipped": $SKIPPED,
    "total": $total
  },
  "failures": $failures_json
}
EOF
}
