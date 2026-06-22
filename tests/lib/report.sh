REPORT_JSON="tests/results/report.json"

COLOR_RESET="\033[0m"
COLOR_RED="\033[31m"
COLOR_GREEN="\033[32m"
COLOR_YELLOW="\033[33m"

report_start() {
  mkdir -p "$(dirname "$REPORT_JSON")"
  echo -e "╔══════════════════════════════════════╗"
  echo -e "║   HomeLab Stack — Integration Tests  ║"
  echo -e "╚══════════════════════════════════════╝"
  echo ""
  export TESTS_START_TIME=$(date +%s)
  export TESTS_PASSED=0
  export TESTS_FAILED=0
  export TESTS_SKIPPED=0
  echo '{"passed":0,"failed":0,"skipped":0,"duration":0,"tests":[]}' > "$REPORT_JSON"
}

report_pass() {
  local stack="$1"
  local msg="$2"
  local duration="$3"
  echo -e "[${stack}] ▶ ${msg} \t\t${COLOR_GREEN}✅ PASS${COLOR_RESET} (${duration}s)"
  TESTS_PASSED=$((TESTS_PASSED+1))
  
  local temp_json
  temp_json=$(mktemp)
  jq --arg s "$stack" --arg m "$msg" --arg d "$duration" '.tests += [{"stack":$s,"msg":$m,"status":"pass","duration":$d}]' "$REPORT_JSON" > "$temp_json" && mv "$temp_json" "$REPORT_JSON"
}

report_fail() {
  local stack="$1"
  local msg="$2"
  local duration="$3"
  local err_details="$4"
  echo -e "[${stack}] ▶ ${msg} \t\t${COLOR_RED}❌ FAIL${COLOR_RESET} (${duration}s)"
  if [ -n "$err_details" ]; then
    echo -e "       ${COLOR_RED}${err_details}${COLOR_RESET}"
  fi
  TESTS_FAILED=$((TESTS_FAILED+1))
  
  local temp_json
  temp_json=$(mktemp)
  jq --arg s "$stack" --arg m "$msg" --arg d "$duration" --arg e "$err_details" '.tests += [{"stack":$s,"msg":$m,"status":"fail","duration":$d,"error":$e}]' "$REPORT_JSON" > "$temp_json" && mv "$temp_json" "$REPORT_JSON"
}

report_skip() {
  local stack="$1"
  local msg="$2"
  echo -e "[${stack}] ▶ ${msg} \t\t${COLOR_YELLOW}⚠️ SKIP${COLOR_RESET}"
  TESTS_SKIPPED=$((TESTS_SKIPPED+1))
  
  local temp_json
  temp_json=$(mktemp)
  jq --arg s "$stack" --arg m "$msg" '.tests += [{"stack":$s,"msg":$m,"status":"skip"}]' "$REPORT_JSON" > "$temp_json" && mv "$temp_json" "$REPORT_JSON"
}

report_summary() {
  local end_time
  end_time=$(date +%s)
  local total_duration=$((end_time - TESTS_START_TIME))
  echo -e "──────────────────────────────────────"
  echo -e "Results: ${TESTS_PASSED} passed, ${TESTS_FAILED} failed, ${TESTS_SKIPPED} skipped"
  echo -e "Duration: ${total_duration}s"
  echo -e "──────────────────────────────────────"
  
  local temp_json
  temp_json=$(mktemp)
  jq --arg p "$TESTS_PASSED" --arg f "$TESTS_FAILED" --arg sk "$TESTS_SKIPPED" --arg d "$total_duration" '.passed = ($p|tonumber) | .failed = ($f|tonumber) | .skipped = ($sk|tonumber) | .duration = ($d|tonumber)' "$REPORT_JSON" > "$temp_json" && mv "$temp_json" "$REPORT_JSON"
  
  if [ "$TESTS_FAILED" -gt 0 ]; then
    return 1
  fi
  return 0
}
