#!/usr/bin/env bash
# Result reporting for homelab-stack tests
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

REPORT_FILE="${REPORT_FILE:-/tmp/homelab-test-report.json}"
RESULTS=()

log_test_start() {
  local suite="$1"
  echo -e "\n${BOLD}━━━ $suite ━━━${NC}"
}

add_result() {
  local suite="$1" test="$2" status="$3" duration="$4" message="${5:-}"
  RESULTS+=("{\"suite\":\"$suite\",\"test\":\"$test\",\"status\":\"$status\",\"duration\":\"$duration\"$([ -n "$message" ] && echo ",\"message\":\"$message\"" || echo "")}")
}

generate_json_report() {
  local total_passed total_failed total_time
  total_passed=$(echo "${RESULTS[*]}" | python3 -c "import sys,json; r=[json.loads(x) for x in sys.stdin.read().split()]; print(len([x for x in r if x['status']=='PASS']))" 2>/dev/null || echo "0")
  total_failed=$(echo "${RESULTS[*]}" | python3 -c "import sys,json; r=[json.loads(x) for x in sys.stdin.read().split()]; print(len([x for x in r if x['status']=='FAIL']))" 2>/dev/null || echo "0")

  python3 -c "
import json, sys
results = [json.loads(x) for x in '''${RESULTS[*]}'''.split()]
report = {
  'timestamp': '$(date -Iseconds)',
  'suites': list(set(r['suite'] for r in results)),
  'total': len(results),
  'passed': $total_passed,
  'failed': $total_failed,
  'results': results
}
with open('$REPORT_FILE', 'w') as f:
    json.dump(report, f, indent=2)
print('JSON report written to $REPORT_FILE')
" 2>/dev/null || echo "JSON report generation failed — install python3"
}

banner() {
  echo -e "\n${BOLD}╔$(printf '═%.0s' {1..60})╗${NC}"
  printf "${BOLD}║ %-60s ║${NC}\n" "$1"
  echo -e "${BOLD}╚$(printf '═%.0s' {1..60})╝${NC}"
}