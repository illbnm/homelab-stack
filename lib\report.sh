#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Test Report Library
# Outputs: coloured terminal + optional JSON file
# =============================================================================

# shellcheck shell=bash

[[ -n "${_REPORT_SH_LOADED:-}" ]] && return 0
_REPORT_SH_LOADED=1

# ---------------------------------------------------------------------------
# ANSI colours
# ---------------------------------------------------------------------------
_R_RESET='\033[0m'
_R_BOLD='\033[1m'
_R_RED='\033[0;31m'
_R_GREEN='\033[0;32m'
_R_YELLOW='\033[0;33m'
_R_CYAN='\033[0;36m'
_R_WHITE='\033[0;37m'
_R_GREY='\033[0;90m'

# Disable colours if not a terminal or CI flag set
if [[ ! -t 1 ]] || [[ "${NO_COLOR:-}" == "1" ]]; then
  _R_RESET=''
  _R_BOLD=''
  _R_RED=''
  _R_GREEN=''
  _R_YELLOW=''
  _R_CYAN=''
  _R_WHITE=''
  _R_GREY=''
fi

# ---------------------------------------------------------------------------
# Shared state (written to tmp files for subshell compatibility)
# ---------------------------------------------------------------------------
_REPORT_TMP_DIR=""
_REPORT_JSON_FILE=""

report_init() {
  local json_out="${1:-}"
  _REPORT_TMP_DIR=$(mktemp -d)
  _REPORT_JSON_FILE="$json_out"

  # Counters
  echo "0" > "${_REPORT_TMP_DIR}/passed"
  echo "0" > "${_REPORT_TMP_DIR}/failed"
  echo "0" > "${_REPORT_TMP_DIR}/skipped"

  # JSON accumulator
  echo "[]" > "${_REPORT_TMP_DIR}/results.json"

  # Export for subshells
  export _REPORT_TMP_DIR
  export _REPORT_JSON_FILE
}

_inc() {
  local file="${_REPORT_TMP_DIR}/$1"
  local val
  val=$(cat "$file")
  echo $(( val + 1 )) > "$file"
}

_read_counter() {
  cat "${_REPORT_TMP_DIR}/$1" 2>/dev/null || echo "0"
}

# ---------------------------------------------------------------------------
# Logging helpers (used outside test functions)
# ---------------------------------------------------------------------------
log_info() {
  echo -e "${_R_CYAN}[INFO]${_R_RESET}  $*"
}

log_warn() {
  echo -e "${_R_YELLOW}[WARN]${_R_RESET}  $*"
}

log_error() {
  echo -e "${_R_RED}[ERROR]${_R_RESET} $*" >&2
}

# ---------------------------------------------------------------------------
# Suite lifecycle
# ---------------------------------------------------------------------------
report_header() {
  local title="$1"
  local line
  line=$(printf '─%.0s' {1..60})
  echo ""
  echo -e "${_R_BOLD}${_R_CYAN}${line}${_R_RESET}"
  echo -e "${_R_BOLD}${_R_CYAN}  ${title}${_R_RESET}"
  echo -e "${_R_BOLD}${_R_CYAN}  $(date '+%Y-%m-%d %H:%M:%S %Z')${_R_RESET}"
  echo -e "${_R_BOLD}${_R_CYAN}${line}${_R_RESET}"
  echo ""
}

report_suite_start() {
  local suite="$1"
  echo -e "${_R_BOLD}${_R_WHITE}▶ Suite: ${suite}${_R_RESET}"
}

report_suite_end() {
  local suite="$1"
  echo ""
}

report_suite_skip() {
  local suite="$1"
  echo -e "  ${_R_GREY}⊘ SKIP  ${suite} (no test file found)${_R_RESET}"
  _inc skipped
  _append_json_result "$suite" "skip" 0 ""
}

# ---------------------------------------------------------------------------
# Test lifecycle
# ---------------------------------------------------------------------------
report_test_start() {
  local fn="$1"
  if [[ "${TEST_VERBOSE:-false}" == "true" ]]; then
    echo -e "  ${_R_GREY}↳ running: ${fn}${_R_RESET}"
  fi
}

report_test_pass() {
  local fn="$1"
  local duration="${2:-0}"
  local label
  label=$(printf '%-55s' "$fn")
  echo -e "  ${_R_GREEN}✔ PASS${_R_RESET}  ${label} ${_R_GREY}(${duration}ms)${_R_RESET}"
  _inc passed
  _append_json_result "$fn" "pass" "$duration" ""
}

report_test_fail() {
  local fn="$1"
  local duration="${2:-0}"
  local msg="${3:-}"
  local label
  label=$(printf '%-55s' "$fn")
  echo -e "  ${_R_RED}✘ FAIL${_R_RESET}  ${label} ${_R_GREY}(${duration}ms)${_R_RESET}"
  if [[ -n "$msg" ]]; then
    echo -e "    ${_R_RED}└─ ${msg}${_R_RESET}"
  fi
  _inc failed
  _append_json_result "$fn" "fail" "$duration" "$msg"
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
report_summary() {
  local passed failed skipped total
  passed=$(_read_counter passed)
  failed=$(_read_counter failed)
  skipped=$(_read_counter skipped)
  total=$(( passed + failed ))

  local line
  line=$(printf '─%.0s' {1..60})
  echo -e "${_R_BOLD}${_R_WHITE}${line}${_R_RESET}"

  if [[ "$failed" -eq 0 ]]; then
    echo -e "${_R_BOLD}${_R_GREEN}  ALL TESTS PASSED${_R_RESET}"
  else
    echo -e "${_R_BOLD}${_R_RED}  TESTS FAILED${_R_RESET}"
  fi

  echo -e "  Total:   ${total}"
  echo -e "  ${_R_GREEN}Passed:  ${passed}${_R_RESET}"
  echo -e "  ${_R_RED}Failed:  ${failed}${_R_RESET}"
  echo -e "  ${_R_YELLOW}Skipped: ${skipped}${_R_RESET}"
  echo -e "${_R_BOLD}${_R_WHITE}${line}${_R_RESET}"
  echo ""

  # Write JSON output if requested
  if [[ -n "${_REPORT_JSON_FILE}" ]]; then
    _write_json_report "$_REPORT_JSON_FILE" "$passed" "$failed" "$skipped"
    echo -e "${_R_GREY}JSON report written to: ${_REPORT_JSON_FILE}${_R_RESET}"
  fi

  # Cleanup
  rm -rf "${_REPORT_TMP_DIR}"
}

report_get_failed_count() {
  _read_counter failed
}

# ---------------------------------------------------------------------------
# JSON helpers
# ---------------------------------------------------------------------------
_escape_json_string() {
  local s="$1"
  # Escape backslashes, double-quotes, newlines, tabs
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\t'/\\t}"
  echo "$s"
}

_append_json_result() {
  local name="$1"
  local status="$2"
  local duration="$3"
  local message="$4"

  local json_file="${_REPORT_TMP_DIR}/results.json"
  [[ ! -f "$json_file" ]] && echo "[]" > "$json_file"

  local name_esc message_esc
  name_esc=$(_escape_json_string "$name")
  message_esc=$(_escape_json_string "$message")

  local entry
  entry=$(printf '{"name":"%s","status":"%s","duration_ms":%s,"message":"%s"}' \
    "$name_esc" "$status" "$duration" "$message_esc")

  # Append to array (portable jq-less approach)
  local current
  current=$(cat "$json_file")
  if [[ "$current" == "[]" ]]; then
    echo "[${entry}]" > "$json_file"
  else
    # Remove trailing ] and append
    echo "${current%]},${entry}]" > "$json_file"
  fi
}

_write_json_report() {
  local output_file="$1"
  local passed="$2"
  local failed="$3"
  local skipped="$4"
  local results
  results=$(cat "${_REPORT_TMP_DIR}/results.json" 2>/dev/null || echo "[]")

  local timestamp
  timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

  cat > "$output_file" <<EOF
{
  "timestamp": "${timestamp}",
  "summary": {
    "passed": ${passed},
    "failed": ${failed},
    "skipped": ${skipped},
    "total": $(( passed + failed ))
  },
  "results": ${results}
}
EOF
}
