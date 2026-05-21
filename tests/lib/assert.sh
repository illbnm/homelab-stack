#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Assertion Library
# =============================================================================
set -uo pipefail

# Colors
readonly _A_RED='\033[0;31m'; _A_GREEN='\033[0;32m'; _A_YELLOW='\033[1;33m'
readonly _A_CYAN='\033[0;36m'; _A_BOLD='\033[1m'; _A_NC='\033[0m'

# Global counters
_TESTS_PASSED=0; _TESTS_FAILED=0; _TESTS_SKIPPED=0
_CURRENT_TEST=""; _CURRENT_SUITE=""
_FAIL_FAST="${FAIL_FAST:-0}"

# JSON results
_JSON_RESULTS="[]"

# ---------------------------------------------------------------------------
begin_suite() {
  _CURRENT_SUITE="$1"
  echo -e "\n${_A_CYAN}${_A_BOLD}[${_CURRENT_SUITE}]${_A_NC}"
}

begin_test() { _CURRENT_TEST="$1"; }

# ---------------------------------------------------------------------------
# Core
# ---------------------------------------------------------------------------
assert_pass() {
  local msg="${1:-passed}"
  _TESTS_PASSED=$(( _TESTS_PASSED + 1 ))
  echo -e "  ${_A_GREEN}✓${_A_NC} ${_CURRENT_TEST}: ${msg}"
  _json_append "pass" "$msg"
}

assert_fail() {
  local msg="${1:-failed}"
  _TESTS_FAILED=$(( _TESTS_FAILED + 1 ))
  echo -e "  ${_A_RED}✗${_A_NC} ${_CURRENT_TEST}: ${msg}"
  _json_append "fail" "$msg"
  [[ "$_FAIL_FAST" == "1" ]] && { echo -e "${_A_RED}FAIL_FAST — aborting${_A_NC}"; exit 1; }
}

assert_skip() {
  local msg="${1:-skipped}"
  _TESTS_SKIPPED=$(( _TESTS_SKIPPED + 1 ))
  echo -e "  ${_A_YELLOW}~${_A_NC} ${_CURRENT_TEST}: ${msg}"
  _json_append "skip" "$msg"
}

# ---------------------------------------------------------------------------
# Equality / Matching
# ---------------------------------------------------------------------------
assert_eq() {
  local exp="$1" act="$2" msg="${3:-values equal}"
  [[ "$act" == "$exp" ]] && assert_pass "$msg" || assert_fail "$msg (expected='$exp', got='$act')"
}

assert_ne() {
  local not="$1" act="$2" msg="${3:-values differ}"
  [[ "$act" != "$not" ]] && assert_pass "$msg" || assert_fail "$msg (got='$act')"
}

assert_contains() {
  local hay="$1" needle="$2" msg="${3:-contains}"
  [[ "$hay" == *"$needle"* ]] && assert_pass "$msg" || assert_fail "$msg (missing '$needle')"
}

assert_match() {
  local pat="$1" act="$2" msg="${3:-regex match}"
  [[ "$act" =~ $pat ]] && assert_pass "$msg" || assert_fail "$msg (no match for '$pat')"
}

assert_gt() {
  [[ "$2" -gt "$1" ]] && assert_pass "${3:-greater than}" || assert_fail "${3:-greater than} (exp>$1, got=$2)"
}

assert_ge() {
  [[ "$2" -ge "$1" ]] && assert_pass "${3:-greater or equal}" || assert_fail "${3:-greater or equal} (exp>=$1, got=$2)"
}

# ---------------------------------------------------------------------------
# File system
# ---------------------------------------------------------------------------
assert_file_exists() { [[ -f "$1" ]] && assert_pass "${2:-file: $1}" || assert_fail "${2:-file missing: $1}"; }
assert_dir_exists()  { [[ -d "$1" ]] && assert_pass "${2:-dir: $1}"  || assert_fail "${2:-dir missing: $1}"; }

assert_file_contains() {
  local f="$1" pat="$2" msg="${3:-file contains}"
  [[ -f "$f" ]] && grep -q "$pat" "$f" && assert_pass "$msg" || assert_fail "$msg"
}

# ---------------------------------------------------------------------------
# JSON result collection
# ---------------------------------------------------------------------------
_json_append() {
  local s="$1" m="${2//\"/\\\"}"
  local e="{\"suite\":\"${_CURRENT_SUITE}\",\"test\":\"${_CURRENT_TEST}\",\"status\":\"${s}\",\"message\":\"${m}\"}"
  [[ "$_JSON_RESULTS" == "[]" ]] && _JSON_RESULTS="[$e]" || _JSON_RESULTS="${_JSON_RESULTS%]},$e]"
}

get_json_results() { echo "$_JSON_RESULTS"; }
