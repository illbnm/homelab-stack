#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Integration Test Runner
# =============================================================================
set -uo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.."; pwd)"
TESTS_DIR="$SCRIPT_DIR"
LIB_DIR="$TESTS_DIR/lib"
RESULTS_DIR="$TESTS_DIR/results"
STACK=""

STACKS=""
ALL_STACKS=false
JSON_OUTPUT=false
VERBOSE=false
TIMEOUT=300
FAILED=0
PASSED=0
SKIPPED=0

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

log_pass()  { echo -e "  ${GREEN}✅ PASS${NC} $*"; ((PASSED++)); }
log_fail()  { echo -e "  ${RED}❌ FAIL${NC} $*"; ((FAILED++)); }
log_skip()  { echo -e "  ${YELLOW}⏭  SKIP${NC} $*"; ((SKIPPED++)); }
log_info()  { echo -e "  ${BLUE}ℹ${NC}  $*"; }
log_test()  { echo -ne "  ${BLUE}▶${NC} $* ... "; }

# JSON results
declare -a JSON_RESULTS=()

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --stack) STACK="$2"; shift 2 ;;
    --all) ALL_STACKS=true; shift ;;
    --json) JSON_OUTPUT=true; shift ;;
    --verbose) VERBOSE=true; shift ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --help|-h)
      cat << EOF
用法: $0 [选项]

选项:
  --stack <name>   运行特定堆栈测试 (base, media, sso, etc.)
  --all             运行所有堆栈测试
  --json            JSON 格式输出
  --verbose         详细输出
  --timeout <秒>    测试超时 (默认: 300s)
  --help            显示帮助

堆栈:
  base  media  storage  monitoring  network
  productivity  ai  sso  databases  notifications  home-automation
EOF
      exit 0 ;;
    *) shift ;;
  esac
done

# Source libraries
for lib in "$LIB_DIR"/*.sh; do
  [[ -f "$lib" ]] && source "$lib"
done

# Find stack test files
get_test_files() {
  local stack="$1"
  local files=()
  if [[ -f "$TESTS_DIR/stacks/${stack}.test.sh" ]]; then
    files+=("$TESTS_DIR/stacks/${stack}.test.sh")
  fi
  if [[ -d "$TESTS_DIR/stacks/$stack" ]]; then
    while IFS= read -r f; do
      files+=("$f")
    done < <(find "$TESTS_DIR/stacks/$stack" -name '*.test.sh' 2>/dev/null)
  fi
  echo "${files[@]}"
}

# Run a single test function
run_test() {
  local test_name="$1"
  local test_func="$2"
  local stack="$3"

  if [[ "$VERBOSE" == "true" ]]; then
    log_info "[$stack] ▶ $test_name"
  else
    log_test "$test_name"
  fi

  local start_time
  start_time=$(date +%s%3N)

  # Run the test
  local output exit_code
  output=$($test_func 2>&1) || exit_code=$?
  local end_time
  end_time=$(date +%s%3N)
  local elapsed_ms=$((end_time - start_time))
  local elapsed_s
  printf -v elapsed_s "%.1f" "$(echo "scale=1; $elapsed_ms/1000" | bc -l 2>/dev/null || echo "0")"

  local result="PASS"
  if [[ ${exit_code:-0} -eq 0 ]]; then
    if [[ "$VERBOSE" == "true" ]]; then
      log_pass "$test_name (${elapsed_s}s)"
    else
      echo -e "✅ PASS (${elapsed_s}s)"
    fi
    JSON_RESULTS+=("{\"test\":\"$test_name\",\"stack\":\"$stack\",\"status\":\"PASS\",\"duration_ms\":$elapsed_ms}")
  else
    result="FAIL"
    if [[ "$VERBOSE" == "true" ]]; then
      echo -e "  ${RED}❌ FAIL${NC} ${elapsed_s}s"
      echo "$output" | head -5 | sed 's/^/     /'
    else
      echo -e "❌ FAIL (${elapsed_s}s)"
    fi
    [[ ${#output} -gt 0 ]] && echo "$output" | head -3 | sed 's/^/     /'
    JSON_RESULTS+=("{\"test\":\"$test_name\",\"stack\":\"$stack\",\"status\":\"FAIL\",\"duration_ms\":$elapsed_ms,\"error\":$(echo "$output" | head -1 | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()[:200]))')}")
  fi
}

# Run a test file
run_test_file() {
  local test_file="$1"
  local stack
  stack=$(basename "$test_file" .test.sh)

  # Source test file (defines test functions but doesn't run them)
  source "$test_file"

  echo ""
  echo -e "${BOLD}━━━ $stack ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  # Find and run all test_ functions
  local funcs
  funcs=$(grep -oE '^test_[a-zA-Z0-9_]+' "$test_file" | sort -u)

  for func in $funcs; do
    run_test "$func" "$func" "$stack"
  done
}

# Write JSON report
write_json_report() {
  mkdir -p "$RESULTS_DIR"
  local timestamp
  timestamp=$(date -Iseconds)

  python3 - << PYEOF
import json, sys, os
from datetime import datetime

results = [json.loads(r) for r in '''${JSON_RESULTS[*]}'''.split('|') if r.strip()]

# Count
passed = sum(1 for r in results if r['status'] == 'PASS')
failed = sum(1 for r in results if r['status'] == 'FAIL')
skipped = $SKIPPED

report = {
    "timestamp": "$timestamp",
    "summary": {
        "total": len(results),
        "passed": passed,
        "failed": failed,
        "skipped": skipped
    },
    "results": results
}

os.makedirs("$RESULTS_DIR", exist_ok=True)
with open("$RESULTS_DIR/report.json", "w") as f:
    json.dump(report, f, indent=2)

print(json.dumps(report, indent=2))
PYEOF
}

# Main
echo ""
echo -e "${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║     HomeLab Stack — Integration Tests                     ║${NC}"
echo -e "${BOLD}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [[ "$ALL_STACKS" == "true" ]]; then
  echo -e "${BLUE}Running all stack tests...${NC}"

  for stack_dir in "$BASE_DIR/stacks"/*; do
    [[ ! -d "$stack_dir" ]] && continue
    stack=$(basename "$stack_dir")
    test_file="$TESTS_DIR/stacks/${stack}.test.sh"
    [[ -f "$test_file" ]] && run_test_file "$test_file"
  done

  # Also run e2e tests
  for e2e_file in "$TESTS_DIR/e2e"/*.test.sh 2>/dev/null; do
    [[ ! -f "$e2e_file" ]] && continue
    run_test_file "$e2e_file"
  done

elif [[ -n "$STACK" ]]; then
  test_file="$TESTS_DIR/stacks/${STACK}.test.sh"
  if [[ -f "$test_file" ]]; then
    run_test_file "$test_file"
  else
    echo -e "${RED}No test file for stack: $STACK${NC}"
    echo "Available test files:"
    ls "$TESTS_DIR/stacks/"*.test.sh 2>/dev/null | xargs -I{} basename {} .test.sh | sed 's/^/  • /'
    exit 1
  fi
else
  echo -e "${RED}Error: --stack <name> or --all required${NC}"
  echo ""
  echo "Available stacks:"
  ls "$BASE_DIR/stacks/"*/docker-compose.yml 2>/dev/null | xargs -I{} dirname {} | xargs -I{} basename {} | sort | sed 's/^/  • /'
  exit 1
fi

# Summary
echo ""
echo -e "${BOLD}────────────────────────────────────────────────────────────────────${NC}"
printf "  Results: ${GREEN}$PASSED passed${NC} | ${RED}$FAILED failed${NC} | ${YELLOW}$SKIPPED skipped${NC}\n"
echo -e "${BOLD}────────────────────────────────────────────────────────────────────${NC}"

if [[ "$JSON_OUTPUT" == "true" ]]; then
  write_json_report
  echo ""
  echo -e "${GREEN}JSON report: $RESULTS_DIR/report.json${NC}"
fi

[[ "$FAILED" -gt 0 ]] && exit 1 || exit 0
