#!/usr/bin/env bash
# =============================================================================
# assert.sh — 测试断言库
# =============================================================================

TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0
CURRENT_TEST=""
FAILURES=()

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

pass() {
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} ${CURRENT_TEST}"
}

fail_test() {
  ((TESTS_FAILED++))
  FAILURES+=("${CURRENT_TEST}: $1")
  echo -e "  ${RED}✗${NC} ${CURRENT_TEST}: $1"
}

skip() {
  ((TESTS_SKIPPED++))
  echo -e "  ${YELLOW}○${NC} ${CURRENT_TEST}: SKIPPED ($1)"
}

assert_eq() {
  local actual="$1" expected="$2" msg="${3:-}"
  if [[ "$actual" == "$expected" ]]; then
    pass
  else
    fail_test "${msg:-Expected '${expected}', got '${actual}'}"
  fi
}

assert_not_empty() {
  local value="$1" msg="${2:-}"
  if [[ -n "$value" ]]; then
    pass
  else
    fail_test "${msg:-Value is empty}"
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" msg="${3:-}"
  if echo "$haystack" | grep -q "$needle"; then
    pass
  else
    fail_test "${msg:-'${needle}' not found in output}"
  fi
}

assert_exit_code() {
  local expected="$1" msg="${2:-}"
  local actual=$?
  if [[ "$actual" -eq "$expected" ]]; then
    pass
  else
    fail_test "${msg:-Expected exit code ${expected}, got ${actual}}"
  fi
}

assert_http_200() {
  local url="$1" msg="${2:-}"
  local code
  code=$(curl -sf -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 "$url" 2>/dev/null || echo "000")
  if [[ "$code" == "200" ]]; then
    pass
  else
    fail_test "${msg:-HTTP ${code} from ${url} (expected 200)}"
  fi
}

assert_http_code() {
  local url="$1" expected="$2" msg="${3:-}"
  local code
  code=$(curl -sf -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 "$url" 2>/dev/null || echo "000")
  if [[ "$code" == "$expected" ]]; then
    pass
  else
    fail_test "${msg:-HTTP ${code} from ${url} (expected ${expected})}"
  fi
}

assert_json_value() {
  local json="$1" path="$2" expected="$3" msg="${4:-}"
  local actual
  actual=$(echo "$json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(eval('d${path}'))" 2>/dev/null || echo "PARSE_ERROR")
  if [[ "$actual" == "$expected" ]]; then
    pass
  else
    fail_test "${msg:-JSON ${path} = '${actual}', expected '${expected}'}"
  fi
}

assert_json_key_exists() {
  local json="$1" key="$2" msg="${3:-}"
  if echo "$json" | python3 -c "import sys,json; d=json.load(sys.stdin); assert '${key}' in str(d)" 2>/dev/null; then
    pass
  else
    fail_test "${msg:-JSON key '${key}' not found}"
  fi
}

assert_no_errors() {
  local output="$1" msg="${2:-}"
  if echo "$output" | grep -qi "error"; then
    fail_test "${msg:-Errors found in output}"
  else
    pass
  fi
}
