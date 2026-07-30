#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
# Assert Library — Test Assertions for Integration Testing
# ════════════════════════════════════════════════════════════════

ASSERTIONS_PASSED=0
ASSERTIONS_FAILED=0
CURRENT_TEST=""

# Colors
if [[ -t 1 ]]; then
  GREEN='\033[0;32m'
  RED='\033[0;31m'
  YELLOW='\033[1;33m'
  NC='\033[0m'
else
  GREEN=''; RED=''; YELLOW=''; NC=''
fi

assert_start() {
  CURRENT_TEST="$1"
}

# ── Basic Assertions ───────────────────────────────────────────

assert_eq() {
  local actual="$1" expected="$2" msg="${3:-Values should be equal}"
  if [[ "$actual" == "$expected" ]]; then
    ((ASSERTIONS_PASSED++))
    return 0
  else
    echo "  ${RED}FAIL${NC}: ${msg} — expected '${expected}', got '${actual}'"
    ((ASSERTIONS_FAILED++))
    return 1
  fi
}

assert_ne() {
  local actual="$1" expected="$2" msg="${3:-Values should not be equal}"
  if [[ "$actual" != "$expected" ]]; then
    ((ASSERTIONS_PASSED++))
    return 0
  else
    echo "  ${RED}FAIL${NC}: ${msg} — values were equal ('${actual}')"
    ((ASSERTIONS_FAILED++))
    return 1
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" msg="${3:-String should contain substring}"
  if [[ "$haystack" == *"$needle"* ]]; then
    ((ASSERTIONS_PASSED++))
    return 0
  else
    echo "  ${RED}FAIL${NC}: ${msg} — '${haystack}' does not contain '${needle}'"
    ((ASSERTIONS_FAILED++))
    return 1
  fi
}

assert_not_contains() {
  local haystack="$1" needle="$2" msg="${3:-String should not contain substring}"
  if [[ "$haystack" != *"$needle"* ]]; then
    ((ASSERTIONS_PASSED++))
    return 0
  else
    echo "  ${RED}FAIL${NC}: ${msg} — '${haystack}' contains '${needle}'"
    ((ASSERTIONS_FAILED++))
    return 1
  fi
}

assert_match() {
  local value="$1" pattern="$2" msg="${3:-Value should match pattern}"
  if [[ "$value" =~ $pattern ]]; then
    ((ASSERTIONS_PASSED++))
    return 0
  else
    echo "  ${RED}FAIL${NC}: ${msg} — '${value}' does not match '${pattern}'"
    ((ASSERTIONS_FAILED++))
    return 1
  fi
}

assert_empty() {
  local value="$1" msg="${2:-Value should be empty}"
  if [[ -z "$value" ]]; then
    ((ASSERTIONS_PASSED++))
    return 0
  else
    echo "  ${RED}FAIL${NC}: ${msg} — value was '${value}'"
    ((ASSERTIONS_FAILED++))
    return 1
  fi
}

assert_not_empty() {
  local value="$1" msg="${2:-Value should not be empty}"
  if [[ -n "$value" ]]; then
    ((ASSERTIONS_PASSED++))
    return 0
  else
    echo "  ${RED}FAIL${NC}: ${msg} — value was empty"
    ((ASSERTIONS_FAILED++))
    return 1
  fi
}

# ── HTTP Assertions ────────────────────────────────────────────

assert_http_200() {
  local url="$1" msg="${2:-HTTP 200 expected}"
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$url" 2>/dev/null || echo "000")
  if [[ "$code" == "200" ]]; then
    ((ASSERTIONS_PASSED++))
    return 0
  else
    echo "  ${RED}FAIL${NC}: ${msg} — got HTTP ${code} from ${url}"
    ((ASSERTIONS_FAILED++))
    return 1
  fi
}

assert_http_status() {
  local url="$1" expected="$2" msg="${3:-HTTP status mismatch}"
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$url" 2>/dev/null || echo "000")
  if [[ "$code" == "$expected" ]]; then
    ((ASSERTIONS_PASSED++))
    return 0
  else
    echo "  ${RED}FAIL${NC}: ${msg} — expected ${expected}, got ${code} from ${url}"
    ((ASSERTIONS_FAILED++))
    return 1
  fi
}

assert_http_contains() {
  local url="$1" needle="$2" msg="${3:-HTTP response should contain string}"
  local body
  body=$(curl -s --max-time 10 "$url" 2>/dev/null || echo "")
  if [[ "$body" == *"$needle"* ]]; then
    ((ASSERTIONS_PASSED++))
    return 0
  else
    echo "  ${RED}FAIL${NC}: ${msg} — response from ${url} does not contain '${needle}'"
    ((ASSERTIONS_FAILED++))
    return 1
  fi
}

assert_http_json_key() {
  local url="$1" key="$2" msg="${3:-JSON response should have key}"
  local body
  body=$(curl -s --max-time 10 "$url" 2>/dev/null || echo "{}")
  if echo "$body" | jq -e ".${key}" &>/dev/null; then
    ((ASSERTIONS_PASSED++))
    return 0
  else
    echo "  ${RED}FAIL${NC}: ${msg} — key '${key}' not found in response from ${url}"
    ((ASSERTIONS_FAILED++))
    return 1
  fi
}

assert_http_json_value() {
  local url="$1" key="$2" expected="$3" msg="${4:-JSON value mismatch}"
  local body actual
  body=$(curl -s --max-time 10 "$url" 2>/dev/null || echo "{}")
  actual=$(echo "$body" | jq -r ".${key}" 2>/dev/null || echo "")
  if [[ "$actual" == "$expected" ]]; then
    ((ASSERTIONS_PASSED++))
    return 0
  else
    echo "  ${RED}FAIL${NC}: ${msg} — expected '${expected}' at ${key}, got '${actual}' from ${url}"
    ((ASSERTIONS_FAILED++))
    return 1
  fi
}

# ── JSON Assertions (on raw strings) ───────────────────────────

assert_json_value() {
  local json="$1" jq_path="$2" expected="$3" msg="${4:-JSON value mismatch}"
  local actual
  actual=$(echo "$json" | jq -r "${jq_path}" 2>/dev/null || echo "")
  if [[ "$actual" == "$expected" ]]; then
    ((ASSERTIONS_PASSED++))
    return 0
  else
    echo "  ${RED}FAIL${NC}: ${msg} — expected '${expected}' at ${jq_path}, got '${actual}'"
    ((ASSERTIONS_FAILED++))
    return 1
  fi
}

assert_json_key_exists() {
  local json="$1" jq_path="$2" msg="${3:-JSON key should exist}"
  if echo "$json" | jq -e "${jq_path}" &>/dev/null; then
    ((ASSERTIONS_PASSED++))
    return 0
  else
    echo "  ${RED}FAIL${NC}: ${msg} — key '${jq_path}' not found in JSON"
    ((ASSERTIONS_FAILED++))
    return 1
  fi
}

assert_no_errors() {
  local json="$1" msg="${2:-Response should not contain errors}"
  local has_error
  has_error=$(echo "$json" | jq -r '.error // .errors // .message // empty' 2>/dev/null || echo "")
  if [[ -z "$has_error" || "$has_error" == "null" ]]; then
    ((ASSERTIONS_PASSED++))
    return 0
  else
    echo "  ${RED}FAIL${NC}: ${msg} — error found: '${has_error}'"
    ((ASSERTIONS_FAILED++))
    return 1
  fi
}

# ── File Assertions ─────────────────────────────────────────────

assert_file_exists() {
  local path="$1" msg="${2:-File should exist}"
  if [[ -f "$path" ]]; then
    ((ASSERTIONS_PASSED++))
    return 0
  else
    echo "  ${RED}FAIL${NC}: ${msg} — file not found: ${path}"
    ((ASSERTIONS_FAILED++))
    return 1
  fi
}

assert_dir_exists() {
  local path="$1" msg="${2:-Directory should exist}"
  if [[ -d "$path" ]]; then
    ((ASSERTIONS_PASSED++))
    return 0
  else
    echo "  ${RED}FAIL${NC}: ${msg} — directory not found: ${path}"
    ((ASSERTIONS_FAILED++))
    return 1
  fi
}

assert_file_contains() {
  local path="$1" needle="$2" msg="${3:-File should contain string}"
  if [[ -f "$path" ]] && grep -q "$needle" "$path" 2>/dev/null; then
    ((ASSERTIONS_PASSED++))
    return 0
  else
    echo "  ${RED}FAIL${NC}: ${msg} — '${path}' does not contain '${needle}'"
    ((ASSERTIONS_FAILED++))
    return 1
  fi
}

# ── Exit handler ───────────────────────────────────────────────

assert_summary() {
  echo ""
  echo "Assertions: ${ASSERTIONS_PASSED} passed, ${ASSERTIONS_FAILED} failed"
  if [[ $ASSERTIONS_FAILED -gt 0 ]]; then
    return 1
  fi
  return 0
}