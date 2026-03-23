#!/usr/bin/env bash
# =============================================================================
# HomeLab Test Framework — Report Library
# Supports: colored terminal output + JSON report
# =============================================================================

_REPORT_DIR="${_REPORT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.."; pwd)/results}"
_REPORT_JSON="$_REPORT_DIR/report.json"
_REPORT_TOTAL=0
_REPORT_PASSED=0
_REPORT_FAILED=0
_REPORT_SKIPPED=0
_REPORT_START_TIME=$(date +%s)
_REPORT_STACK=""

# Colors
if [[ -t 1 ]]; then
  _R_GREEN='\033[0;32m'; _R_RED='\033[0;31m'; _R_YELLOW='\033[1;33m'
  _R_BLUE='\033[0;34m'; _R_BOLD='\033[1m'; _R_DIM='\033[2m'; _R_NC='\033[0m'
else
  _R_GREEN=''; _R_RED=''; _R_YELLOW=''; _R_BLUE=''; _R_BOLD=''; _R_DIM=''; _R_NC=''
fi

# ---------------------------------------------------------------------------
# Init report
# ---------------------------------------------------------------------------
report_init() {
  mkdir -p "$_REPORT_DIR"
  cat > "$_REPORT_JSON" <<'JSON'
{
  "version": "1.0",
  "hostname": "",
  "started_at": "",
  "completed_at": "",
  "duration_seconds": 0,
  "summary": { "total": 0, "passed": 0, "failed": 0, "skipped": 0 },
  "stacks": {}
}
JSON
  # Update hostname and start time
  python3 -c "
import json, sys
with open('$_REPORT_JSON') as f: d=json.load(f)
d['hostname'] = '$(hostname)'
d['started_at'] = '$(date -Iseconds)'
with open('$_REPORT_JSON','w') as f: json.dump(d,f,indent=2)
" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Stack header
# ---------------------------------------------------------------------------
report_stack() {
  _REPORT_STACK="$1"
  echo ""
  echo -e "${_R_BLUE}${_R_BOLD}[$1]${_R_NC}"
}

# ---------------------------------------------------------------------------
# Test result
# ---------------------------------------------------------------------------
report_result() {
  local name="$1" status="$2" duration="${3:-0}" message="${4:-}"
  (( _REPORT_TOTAL++ ))

  local icon color
  case "$status" in
    pass)    icon="${_R_GREEN}✅ PASS${_R_NC}"; (( _REPORT_PASSED++ )) ;;
    fail)    icon="${_R_RED}❌ FAIL${_R_NC}"; (( _REPORT_FAILED++ )) ;;
    skip)    icon="${_R_YELLOW}⏭️  SKIP${_R_NC}"; (( _REPORT_SKIPPED++ )) ;;
  esac

  printf "  %-40s %s ${_R_DIM}(%ss)${_R_NC}\n" "$name" "$icon" "$duration"
  [[ -n "$message" && "$status" == "fail" ]] && echo -e "    ${_R_RED}↳ $message${_R_NC}"

  # Append to JSON
  python3 -c "
import json
with open('$_REPORT_JSON') as f: d=json.load(f)
stack = '$_REPORT_STACK' or 'unknown'
if stack not in d['stacks']: d['stacks'][stack] = []
d['stacks'][stack].append({
    'name': '$name',
    'status': '$status',
    'duration': $duration,
    'message': '''$message'''
})
d['summary']['total'] = $_REPORT_TOTAL
d['summary']['passed'] = $_REPORT_PASSED
d['summary']['failed'] = $_REPORT_FAILED
d['summary']['skipped'] = $_REPORT_SKIPPED
with open('$_REPORT_JSON','w') as f: json.dump(d,f,indent=2)
" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
report_summary() {
  local end_time
  end_time=$(date +%s)
  local duration=$((end_time - _REPORT_START_TIME))

  # Update JSON
  python3 -c "
import json
with open('$_REPORT_JSON') as f: d=json.load(f)
d['completed_at'] = '$(date -Iseconds)'
d['duration_seconds'] = $duration
with open('$_REPORT_JSON','w') as f: json.dump(d,f,indent=2)
" 2>/dev/null || true

  echo ""
  echo -e "${_R_BOLD}╔══════════════════════════════════════════╗${_R_NC}"
  echo -e "${_R_BOLD}║   HomeLab Stack — Integration Tests      ║${_R_NC}"
  echo -e "${_R_BOLD}╚══════════════════════════════════════════╝${_R_NC}"
  echo ""
  echo -e "  Total:   $_REPORT_TOTAL"
  echo -e "  ${_R_GREEN}Passed:  $_REPORT_PASSED${_R_NC}"
  echo -e "  ${_R_RED}Failed:  $_REPORT_FAILED${_R_NC}"
  echo -e "  ${_R_YELLOW}Skipped: $_REPORT_SKIPPED${_R_NC}"
  echo -e "  Duration: ${duration}s"
  echo ""
  echo -e "  Report: $_REPORT_JSON"
  echo ""

  [[ $_REPORT_FAILED -eq 0 ]]
}
