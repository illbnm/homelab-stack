#!/usr/bin/env bash
# =============================================================================
# Test Reporting — Colored Terminal + JSON Dual Output
# =============================================================================
[[ -n "${_LIB_REPORT_LOADED:-}" ]] && return 0
_LIB_REPORT_LOADED=1

set -euo pipefail

# ---------------------------------------------------------------------------
# Colors & symbols
# ---------------------------------------------------------------------------
readonly CLR_GREEN='\033[0;32m'
readonly CLR_RED='\033[0;31m'
readonly CLR_YELLOW='\033[1;33m'
readonly CLR_CYAN='\033[0;36m'
readonly CLR_BOLD='\033[1m'
readonly CLR_DIM='\033[2m'
readonly CLR_RESET='\033[0m'

readonly SYM_PASS="${CLR_GREEN}PASS${CLR_RESET}"
readonly SYM_FAIL="${CLR_RED}FAIL${CLR_RESET}"
readonly SYM_SKIP="${CLR_YELLOW}SKIP${CLR_RESET}"

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
_REPORT_RESULTS=()
_REPORT_SUITE_START=""
_REPORT_TOTAL_PASS=0
_REPORT_TOTAL_FAIL=0
_REPORT_TOTAL_SKIP=0
_REPORT_JSON_FILE="${REPORT_JSON_FILE:-tests/results/report.json}"

# ---------------------------------------------------------------------------
# report_header
#   Print a unicode box-drawing header.
# ---------------------------------------------------------------------------
report_header() {
  local title="${1:-HomeLab Integration Tests}"
  local width=60
  local pad=$(( (width - ${#title} - 2) / 2 ))
  local pad_right=$(( width - ${#title} - 2 - pad ))
  echo ""
  echo -e "${CLR_CYAN}"
  printf '%s' "╔"
  printf '═%.0s' $(seq 1 "${width}")
  printf '%s\n' "╗"
  printf '║'
  printf ' %.0s' $(seq 1 "${pad}")
  printf ' %s ' "${title}"
  printf ' %.0s' $(seq 1 "${pad_right}")
  printf '║\n'
  printf '%s' "╠"
  printf '═%.0s' $(seq 1 "${width}")
  printf '%s\n' "╣"
  echo -e "${CLR_RESET}"
  _REPORT_SUITE_START=$(date +%s)
}

# ---------------------------------------------------------------------------
# report_suite <stack_name>
#   Print a section header for a test suite.
# ---------------------------------------------------------------------------
report_suite() {
  local stack="${1:?stack name required}"
  echo ""
  echo -e "${CLR_BOLD}${CLR_CYAN}  ── ${stack} ──${CLR_RESET}"
}

# ---------------------------------------------------------------------------
# report_test <stack> <test_name> <status> <duration_ms> [message]
#   Record and display a single test result.
#   status: pass | fail | skip
# ---------------------------------------------------------------------------
report_test() {
  local stack="${1:?stack required}"
  local test_name="${2:?test name required}"
  local status="${3:?status required}"
  local duration_ms="${4:-0}"
  local message="${5:-}"

  local sym
  case "${status}" in
    pass) sym="${SYM_PASS}"; (( _REPORT_TOTAL_PASS++ )) || true ;;
    fail) sym="${SYM_FAIL}"; (( _REPORT_TOTAL_FAIL++ )) || true ;;
    skip) sym="${SYM_SKIP}"; (( _REPORT_TOTAL_SKIP++ )) || true ;;
    *)    sym="${status}" ;;
  esac

  # Terminal output
  printf "  ${CLR_DIM}[%s]${CLR_RESET} > %-42s %b ${CLR_DIM}(%dms)${CLR_RESET}\n" \
    "${stack}" "${test_name}" "${sym}" "${duration_ms}"

  if [[ -n "${message}" ]] && [[ "${status}" == "fail" ]]; then
    echo -e "         ${CLR_RED}${message}${CLR_RESET}"
  fi

  # Escape special characters for valid JSON
  message="${message//\\/\\\\}"    # escape backslashes first
  message="${message//$'\n'/\\n}"  # escape newlines
  message="${message//$'\t'/\\t}"  # escape tabs
  message="${message//\"/\\\"}"    # escape double quotes

  # Collect for JSON
  _REPORT_RESULTS+=("$(printf '{"stack":"%s","test":"%s","status":"%s","duration_ms":%d,"message":"%s"}' \
    "${stack}" "${test_name}" "${status}" "${duration_ms}" "${message}")")
}

# ---------------------------------------------------------------------------
# report_footer
#   Print the summary line and unicode box-drawing footer.
# ---------------------------------------------------------------------------
report_footer() {
  local total=$(( _REPORT_TOTAL_PASS + _REPORT_TOTAL_FAIL + _REPORT_TOTAL_SKIP ))
  local suite_end
  suite_end=$(date +%s)
  local suite_duration=$(( suite_end - ${_REPORT_SUITE_START:-${suite_end}} ))
  local width=60

  echo ""
  echo -e "${CLR_CYAN}"
  printf '%s' "╠"
  printf '═%.0s' $(seq 1 "${width}")
  printf '%s\n' "╣"
  echo -e "${CLR_RESET}"

  printf '  %bSummary:%b ' "${CLR_BOLD}" "${CLR_RESET}"
  printf '%b%d passed%b, ' "${CLR_GREEN}" "${_REPORT_TOTAL_PASS}" "${CLR_RESET}"
  printf '%b%d failed%b, ' "${CLR_RED}" "${_REPORT_TOTAL_FAIL}" "${CLR_RESET}"
  printf '%b%d skipped%b ' "${CLR_YELLOW}" "${_REPORT_TOTAL_SKIP}" "${CLR_RESET}"
  printf '%b(%d total, %ds)%b\n' "${CLR_DIM}" "${total}" "${suite_duration}" "${CLR_RESET}"

  echo -e "${CLR_CYAN}"
  printf '%s' "╚"
  printf '═%.0s' $(seq 1 "${width}")
  printf '%s\n' "╝"
  echo -e "${CLR_RESET}"
}

# ---------------------------------------------------------------------------
# report_json_write
#   Write the collected results to a JSON file.
# ---------------------------------------------------------------------------
report_json_write() {
  local outfile="${1:-${_REPORT_JSON_FILE}}"
  local total=$(( _REPORT_TOTAL_PASS + _REPORT_TOTAL_FAIL + _REPORT_TOTAL_SKIP ))
  local suite_end
  suite_end=$(date +%s)
  local suite_duration=$(( suite_end - ${_REPORT_SUITE_START:-${suite_end}} ))

  mkdir -p "$(dirname "${outfile}")"

  {
    printf '{\n'
    printf '  "timestamp": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '  "duration_seconds": %d,\n' "${suite_duration}"
    printf '  "summary": {\n'
    printf '    "total": %d,\n' "${total}"
    printf '    "passed": %d,\n' "${_REPORT_TOTAL_PASS}"
    printf '    "failed": %d,\n' "${_REPORT_TOTAL_FAIL}"
    printf '    "skipped": %d\n' "${_REPORT_TOTAL_SKIP}"
    printf '  },\n'
    printf '  "results": [\n'

    local i=0
    local count=${#_REPORT_RESULTS[@]}
    for result in "${_REPORT_RESULTS[@]}"; do
      (( i++ )) || true
      if (( i < count )); then
        printf '    %s,\n' "${result}"
      else
        printf '    %s\n' "${result}"
      fi
    done

    printf '  ]\n'
    printf '}\n'
  } > "${outfile}"

  echo -e "  ${CLR_DIM}JSON report written to ${outfile}${CLR_RESET}"
}

# ---------------------------------------------------------------------------
# run_test <stack> <test_name> <command...>
#   Execute a test command, capture timing and result, report it.
# ---------------------------------------------------------------------------
run_test() {
  local stack="${1:?stack required}"
  local test_name="${2:?test name required}"
  shift 2

  local start_ms end_ms duration_ms
  start_ms=$(date +%s%3N 2>/dev/null || date +%s000)

  local exit_code=0
  local output=""
  output=$("$@" 2>&1) || exit_code=$?

  end_ms=$(date +%s%3N 2>/dev/null || date +%s000)
  duration_ms=$(( end_ms - start_ms ))

  if [[ ${exit_code} -eq 0 ]]; then
    report_test "${stack}" "${test_name}" "pass" "${duration_ms}"
  else
    report_test "${stack}" "${test_name}" "fail" "${duration_ms}" "${output}"
  fi

  return ${exit_code}
}

# ---------------------------------------------------------------------------
# skip_test <stack> <test_name> <reason>
#   Record a skipped test.
# ---------------------------------------------------------------------------
skip_test() {
  local stack="${1:?stack required}"
  local test_name="${2:?test name required}"
  local reason="${3:-skipped}"
  report_test "${stack}" "${test_name}" "skip" 0 "${reason}"
}
