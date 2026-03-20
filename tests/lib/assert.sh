#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Assertion Library
# Provides test assertion functions for integration tests.
# =============================================================================

# Counters (shared via export from run-tests.sh)
: "${TEST_PASSED:=0}"
: "${TEST_FAILED:=0}"
: "${TEST_SKIPPED:=0}"
: "${TEST_RESULTS_FILE:=/tmp/homelab-test-results.json}"

# Colors
_RED='\033[0;31m'
_GREEN='\033[0;32m'
_YELLOW='\033[1;33m'
_NC='\033[0m'

# Internal: record a result
_record_result() {
  local status="$1" name="$2" message="${3:-}"
  case "$status" in
    pass)
      echo -e "  ${_GREEN}✓${_NC} $name${message:+ — $message}"
      TEST_PASSED=$((TEST_PASSED + 1))
      ;;
    fail)
      echo -e "  ${_RED}✗${_NC} $name${message:+ — $message}"
      TEST_FAILED=$((TEST_FAILED + 1))
      ;;
    skip)
      echo -e "  ${_YELLOW}~${_NC} $name (skipped)${message:+ — $message}"
      TEST_SKIPPED=$((TEST_SKIPPED + 1))
      ;;
  esac
  # Append to JSON-lines file for report.sh
  printf '{"status":"%s","name":"%s","message":"%s","timestamp":"%s"}\n' \
    "$status" "$name" "$message" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    >> "$TEST_RESULTS_FILE"
}

# ---------------------------------------------------------------------------
# Basic assertions
# ---------------------------------------------------------------------------

# assert_eq VALUE EXPECTED [MESSAGE]
assert_eq() {
  local actual="$1" expected="$2" msg="${3:-assert_eq}"
  if [[ "$actual" == "$expected" ]]; then
    _record_result pass "$msg"
  else
    _record_result fail "$msg" "expected '$expected', got '$actual'"
  fi
}

# assert_not_eq VALUE UNEXPECTED [MESSAGE]
assert_not_eq() {
  local actual="$1" unexpected="$2" msg="${3:-assert_not_eq}"
  if [[ "$actual" != "$unexpected" ]]; then
    _record_result pass "$msg"
  else
    _record_result fail "$msg" "did not expect '$unexpected'"
  fi
}

# assert_contains HAYSTACK NEEDLE [MESSAGE]
assert_contains() {
  local haystack="$1" needle="$2" msg="${3:-assert_contains}"
  if [[ "$haystack" == *"$needle"* ]]; then
    _record_result pass "$msg"
  else
    _record_result fail "$msg" "expected to contain '$needle'"
  fi
}

# assert_not_contains HAYSTACK NEEDLE [MESSAGE]
assert_not_contains() {
  local haystack="$1" needle="$2" msg="${3:-assert_not_contains}"
  if [[ "$haystack" != *"$needle"* ]]; then
    _record_result pass "$msg"
  else
    _record_result fail "$msg" "expected NOT to contain '$needle'"
  fi
}

# assert_matches VALUE REGEX [MESSAGE]
assert_matches() {
  local value="$1" regex="$2" msg="${3:-assert_matches}"
  if [[ "$value" =~ $regex ]]; then
    _record_result pass "$msg"
  else
    _record_result fail "$msg" "expected to match '$regex'"
  fi
}

# assert_exit_code CODE [MESSAGE]
# Checks $? of the PREVIOUS command — call immediately after the command
assert_exit_code() {
  local expected="$1" msg="${2:-assert_exit_code}"
  local actual="$?"
  if [[ "$actual" -eq "$expected" ]]; then
    _record_result pass "$msg"
  else
    _record_result fail "$msg" "exit code $actual (expected $expected)"
  fi
}

# ---------------------------------------------------------------------------
# HTTP assertions
# ---------------------------------------------------------------------------

# assert_http_200 URL [MESSAGE]
assert_http_200() {
  local url="$1" msg="${2:-HTTP 200: $1}"
  local code
  code=$(curl -sf -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 10 "$url" 2>/dev/null || echo 000)
  if [[ "$code" == "200" ]]; then
    _record_result pass "$msg"
  else
    _record_result fail "$msg" "HTTP $code (expected 200)"
  fi
}

# assert_http_status URL EXPECTED_CODE [MESSAGE]
assert_http_status() {
  local url="$1" expected="$2" msg="${3:-HTTP $2: $1}"
  local code
  code=$(curl -sf -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 10 "$url" 2>/dev/null || echo 000)
  if [[ "$code" == "$expected" ]]; then
    _record_result pass "$msg"
  else
    _record_result fail "$msg" "HTTP $code (expected $expected)"
  fi
}

# assert_http_ok URL [MESSAGE]
# Accepts any 2xx or 3xx status
assert_http_ok() {
  local url="$1" msg="${2:-HTTP OK: $1}"
  local code
  code=$(curl -sf -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 10 "$url" 2>/dev/null || echo 000)
  if [[ "$code" =~ ^[23] ]]; then
    _record_result pass "$msg" "HTTP $code"
  else
    _record_result fail "$msg" "HTTP $code (expected 2xx/3xx)"
  fi
}

# assert_http_body_contains URL NEEDLE [MESSAGE]
assert_http_body_contains() {
  local url="$1" needle="$2" msg="${3:-HTTP body contains '$2': $1}"
  local body
  body=$(curl -sf --connect-timeout 5 --max-time 10 "$url" 2>/dev/null || echo "")
  if [[ "$body" == *"$needle"* ]]; then
    _record_result pass "$msg"
  else
    _record_result fail "$msg" "body does not contain '$needle'"
  fi
}

# ---------------------------------------------------------------------------
# JSON assertions (requires jq)
# ---------------------------------------------------------------------------

# assert_json_value JSON_STRING JQ_FILTER EXPECTED [MESSAGE]
assert_json_value() {
  local json="$1" filter="$2" expected="$3" msg="${4:-JSON $filter == $3}"
  local actual
  actual=$(echo "$json" | jq -r "$filter" 2>/dev/null || echo "__JQ_ERROR__")
  if [[ "$actual" == "$expected" ]]; then
    _record_result pass "$msg"
  else
    _record_result fail "$msg" "got '$actual' (expected '$expected')"
  fi
}

# assert_json_key_exists JSON_STRING JQ_FILTER [MESSAGE]
assert_json_key_exists() {
  local json="$1" filter="$2" msg="${3:-JSON key exists: $2}"
  local val
  val=$(echo "$json" | jq -r "$filter" 2>/dev/null || echo "null")
  if [[ "$val" != "null" && -n "$val" ]]; then
    _record_result pass "$msg"
  else
    _record_result fail "$msg" "key not found or null"
  fi
}

# assert_no_errors JSON_STRING [MESSAGE]
# Checks that JSON response doesn't contain error indicators
assert_no_errors() {
  local json="$1" msg="${2:-No errors in response}"
  if echo "$json" | jq -e '.error // .errors // .message | select(. != null)' &>/dev/null; then
    local err
    err=$(echo "$json" | jq -r '.error // .errors // .message' 2>/dev/null)
    _record_result fail "$msg" "found error: $err"
  else
    _record_result pass "$msg"
  fi
}

# ---------------------------------------------------------------------------
# File assertions
# ---------------------------------------------------------------------------

# assert_file_exists PATH [MESSAGE]
assert_file_exists() {
  local path="$1" msg="${2:-File exists: $1}"
  if [[ -f "$path" ]]; then
    _record_result pass "$msg"
  else
    _record_result fail "$msg" "file not found"
  fi
}

# assert_file_contains PATH NEEDLE [MESSAGE]
assert_file_contains() {
  local path="$1" needle="$2" msg="${3:-File contains '$2': $1}"
  if [[ -f "$path" ]] && grep -q "$needle" "$path" 2>/dev/null; then
    _record_result pass "$msg"
  else
    _record_result fail "$msg" "pattern not found in file"
  fi
}

# assert_file_not_contains PATH NEEDLE [MESSAGE]
assert_file_not_contains() {
  local path="$1" needle="$2" msg="${3:-File does not contain '$2': $1}"
  if [[ -f "$path" ]] && ! grep -q "$needle" "$path" 2>/dev/null; then
    _record_result pass "$msg"
  else
    _record_result fail "$msg" "pattern found in file"
  fi
}

# assert_no_gcr_images DIR [MESSAGE]
assert_no_gcr_images() {
  local dir="$1" msg="${2:-No gcr.io images in $1}"
  local count
  count=$(grep -r 'gcr\.io' "$dir" --include='*.yml' --include='*.yaml' 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$count" -eq 0 ]]; then
    _record_result pass "$msg"
  else
    _record_result fail "$msg" "found $count gcr.io references"
  fi
}

# ---------------------------------------------------------------------------
# Skip helper
# ---------------------------------------------------------------------------

# skip_test MESSAGE
skip_test() {
  _record_result skip "${1:-test}" "${2:-}"
}
