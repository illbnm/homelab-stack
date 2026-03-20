#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Assertion Library
# Provides assert_* functions for integration tests.
# =============================================================================

# Track results globally
declare -g TEST_PASSED=0
declare -g TEST_FAILED=0
declare -g TEST_SKIPPED=0
declare -g TEST_RESULTS_JSON="[]"

# Colors
readonly _RED='\033[0;31m'
readonly _GREEN='\033[0;32m'
readonly _YELLOW='\033[1;33m'
readonly _NC='\033[0m'

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------
_record_pass() {
  local name="$1"
  ((TEST_PASSED++))
  echo -e "  ${_GREEN}✓${_NC} $name"
  _append_result "pass" "$name" ""
}

_record_fail() {
  local name="$1" detail="${2:-}"
  ((TEST_FAILED++))
  echo -e "  ${_RED}✗${_NC} $name${detail:+ — $detail}"
  _append_result "fail" "$name" "$detail"
}

_record_skip() {
  local name="$1" reason="${2:-}"
  ((TEST_SKIPPED++))
  echo -e "  ${_YELLOW}~${_NC} $name (skipped${reason:+: $reason})"
  _append_result "skip" "$name" "$reason"
}

_append_result() {
  local status="$1" name="$2" detail="$3"
  # Escape double quotes in strings for JSON safety
  name="${name//\"/\\\"}"
  detail="${detail//\"/\\\"}"
  local entry="{\"status\":\"${status}\",\"name\":\"${name}\",\"detail\":\"${detail}\"}"
  if [[ "$TEST_RESULTS_JSON" == "[]" ]]; then
    TEST_RESULTS_JSON="[${entry}]"
  else
    TEST_RESULTS_JSON="${TEST_RESULTS_JSON%]},${entry}]"
  fi
}

# ---------------------------------------------------------------------------
# Assertions
# ---------------------------------------------------------------------------

# assert_eq VALUE EXPECTED [MESSAGE]
assert_eq() {
  local actual="$1" expected="$2" msg="${3:-assert_eq '$1' == '$2'}"
  if [[ "$actual" == "$expected" ]]; then
    _record_pass "$msg"
  else
    _record_fail "$msg" "expected='${expected}' actual='${actual}'"
  fi
}

# assert_ne VALUE UNEXPECTED [MESSAGE]
assert_ne() {
  local actual="$1" unexpected="$2" msg="${3:-assert_ne '$1' != '$2'}"
  if [[ "$actual" != "$unexpected" ]]; then
    _record_pass "$msg"
  else
    _record_fail "$msg" "value should not be '${unexpected}'"
  fi
}

# assert_contains HAYSTACK NEEDLE [MESSAGE]
assert_contains() {
  local haystack="$1" needle="$2" msg="${3:-assert_contains}"
  if [[ "$haystack" == *"$needle"* ]]; then
    _record_pass "$msg"
  else
    _record_fail "$msg" "string does not contain '${needle}'"
  fi
}

# assert_not_empty VALUE [MESSAGE]
assert_not_empty() {
  local value="$1" msg="${2:-assert_not_empty}"
  if [[ -n "$value" ]]; then
    _record_pass "$msg"
  else
    _record_fail "$msg" "value is empty"
  fi
}

# assert_exit_code EXPECTED [MESSAGE]
# Must be called immediately after the command whose exit code you want to check.
# Usage: some_command; assert_exit_code $? 0 "command succeeded"
assert_exit_code() {
  local actual="$1" expected="${2:-0}" msg="${3:-assert_exit_code == $2}"
  if [[ "$actual" -eq "$expected" ]]; then
    _record_pass "$msg"
  else
    _record_fail "$msg" "exit_code=${actual} expected=${expected}"
  fi
}

# assert_http_status URL EXPECTED_CODE [MESSAGE]
# Performs a curl and checks the HTTP status code.
assert_http_status() {
  local url="$1" expected="${2:-200}" msg="${3:-HTTP $expected $url}"
  local code
  code=$(curl -sf -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 10 "$url" 2>/dev/null || echo "000")
  if [[ "$code" == "$expected" ]]; then
    _record_pass "$msg"
  else
    _record_fail "$msg" "HTTP ${code} (expected ${expected})"
  fi
}

# assert_http_200 URL [MESSAGE]
assert_http_200() {
  local url="$1" msg="${2:-HTTP 200 $1}"
  assert_http_status "$url" "200" "$msg"
}

# assert_http_ok URL [MESSAGE]
# Passes for any 2xx or 3xx status.
assert_http_ok() {
  local url="$1" msg="${2:-HTTP OK $1}"
  local code
  code=$(curl -sf -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 10 "$url" 2>/dev/null || echo "000")
  if [[ "$code" =~ ^[23][0-9]{2}$ ]]; then
    _record_pass "$msg"
  else
    _record_fail "$msg" "HTTP ${code} (expected 2xx/3xx)"
  fi
}

# assert_http_json_value URL JQ_FILTER EXPECTED [MESSAGE]
# Fetches JSON from URL and checks a jq filter matches expected value.
assert_http_json_value() {
  local url="$1" filter="$2" expected="$3" msg="${4:-JSON $filter == $3 from $1}"
  local body actual
  body=$(curl -sf --connect-timeout 5 --max-time 10 "$url" 2>/dev/null) || {
    _record_fail "$msg" "curl failed for $url"
    return
  }
  if ! command -v jq &>/dev/null; then
    _record_skip "$msg" "jq not installed"
    return
  fi
  actual=$(echo "$body" | jq -r "$filter" 2>/dev/null)
  if [[ "$actual" == "$expected" ]]; then
    _record_pass "$msg"
  else
    _record_fail "$msg" "expected='${expected}' actual='${actual}'"
  fi
}

# assert_json_value JSON_STRING JQ_FILTER EXPECTED [MESSAGE]
assert_json_value() {
  local json="$1" filter="$2" expected="$3" msg="${4:-JSON $filter == $3}"
  if ! command -v jq &>/dev/null; then
    _record_skip "$msg" "jq not installed"
    return
  fi
  local actual
  actual=$(echo "$json" | jq -r "$filter" 2>/dev/null)
  if [[ "$actual" == "$expected" ]]; then
    _record_pass "$msg"
  else
    _record_fail "$msg" "expected='${expected}' actual='${actual}'"
  fi
}

# assert_json_key_exists JSON_STRING JQ_FILTER [MESSAGE]
assert_json_key_exists() {
  local json="$1" filter="$2" msg="${3:-JSON key exists: $2}"
  if ! command -v jq &>/dev/null; then
    _record_skip "$msg" "jq not installed"
    return
  fi
  local val
  val=$(echo "$json" | jq -r "$filter" 2>/dev/null)
  if [[ -n "$val" && "$val" != "null" ]]; then
    _record_pass "$msg"
  else
    _record_fail "$msg" "key not found or null"
  fi
}

# assert_no_errors JSON_STRING [MESSAGE]
# Checks that JSON response has no "error" or "errors" keys with truthy values.
assert_no_errors() {
  local json="$1" msg="${2:-No errors in response}"
  if ! command -v jq &>/dev/null; then
    _record_skip "$msg" "jq not installed"
    return
  fi
  local has_error
  has_error=$(echo "$json" | jq -r 'if .error then .error elif .errors then (.errors | length) else "none" end' 2>/dev/null)
  if [[ "$has_error" == "none" || "$has_error" == "0" || "$has_error" == "false" ]]; then
    _record_pass "$msg"
  else
    _record_fail "$msg" "errors found: ${has_error}"
  fi
}

# assert_file_exists PATH [MESSAGE]
assert_file_exists() {
  local path="$1" msg="${2:-File exists: $1}"
  if [[ -f "$path" ]]; then
    _record_pass "$msg"
  else
    _record_fail "$msg" "file not found"
  fi
}

# assert_file_contains PATH PATTERN [MESSAGE]
assert_file_contains() {
  local path="$1" pattern="$2" msg="${3:-File $1 contains '$2'}"
  if [[ ! -f "$path" ]]; then
    _record_fail "$msg" "file not found: $path"
    return
  fi
  if grep -q "$pattern" "$path" 2>/dev/null; then
    _record_pass "$msg"
  else
    _record_fail "$msg" "pattern not found"
  fi
}

# assert_no_gcr_images DIR [MESSAGE]
# Checks that no compose files reference gcr.io images.
assert_no_gcr_images() {
  local dir="$1" msg="${2:-No gcr.io images in $1}"
  local count
  count=$(grep -r 'image:.*gcr\.io' "$dir" 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$count" -eq 0 ]]; then
    _record_pass "$msg"
  else
    _record_fail "$msg" "found ${count} gcr.io image references"
  fi
}

# assert_command_exists CMD [MESSAGE]
assert_command_exists() {
  local cmd="$1" msg="${2:-Command exists: $1}"
  if command -v "$cmd" &>/dev/null; then
    _record_pass "$msg"
  else
    _record_fail "$msg" "command not found"
  fi
}

# skip_test MESSAGE
# Explicitly skip a test with a reason.
skip_test() {
  _record_skip "$1" "${2:-}"
}
