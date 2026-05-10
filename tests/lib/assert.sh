#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Assertion Library
# Provides test assertion functions for integration tests.
#
# Usage: source ./tests/lib/assert.sh
# =============================================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

PASS=0; FAIL=0; SKIP=0
CURRENT_TEST=""; CURRENT_STACK=""
RESULTS_FILE=""

# ------------------------------------------------------------------
# Test lifecycle
# ------------------------------------------------------------------
describe() { CURRENT_STACK="$1"; echo -e "\n${BOLD}${CYAN}━━━ $1 ━━━${RESET}"; }
it() { CURRENT_TEST="$1"; echo -n "  $1... "; }

pass() {
  ((PASS++)) || true
  echo -e "${GREEN}PASS${RESET}"
  [ -n "$RESULTS_FILE" ] && echo "{\"stack\":\"$CURRENT_STACK\",\"test\":\"$CURRENT_TEST\",\"status\":\"pass\"}" >> "$RESULTS_FILE"
}

fail() {
  local msg="${1:-}"
  ((FAIL++)) || true
  echo -e "${RED}FAIL${RESET}${msg:+ — $msg}"
  [ -n "$RESULTS_FILE" ] && echo "{\"stack\":\"$CURRENT_STACK\",\"test\":\"$CURRENT_TEST\",\"status\":\"fail\",\"message\":\"$msg\"}" >> "$RESULTS_FILE"
}

skip() {
  local reason="${1:-not applicable}"
  ((SKIP++)) || true
  echo -e "${YELLOW}SKIP ($reason)${RESET}"
  [ -n "$RESULTS_FILE" ] && echo "{\"stack\":\"$CURRENT_STACK\",\"test\":\"$CURRENT_TEST\",\"status\":\"skip\",\"reason\":\"$reason\"}" >> "$RESULTS_FILE"
}

# ------------------------------------------------------------------
# Assertions
# ------------------------------------------------------------------
assert_eq() {
  local actual="$1" expected="$2" msg="${3:-}"
  if [ "$actual" = "$expected" ]; then pass; else fail "${msg:+$msg: }expected '$expected', got '$actual'"; fi
}

assert_ne() {
  local actual="$1" expected="$2" msg="${3:-}"
  if [ "$actual" != "$expected" ]; then pass; else fail "${msg:+$msg: }unexpectedly equal to '$expected'"; fi
}

assert_contains() {
  local haystack="$1" needle="$2" msg="${3:-}"
  if echo "$haystack" | grep -qF "$needle"; then pass; else fail "${msg:+$msg: }'$needle' not found"; fi
}

assert_not_contains() {
  local haystack="$1" needle="$2" msg="${3:-}"
  if ! echo "$haystack" | grep -qF "$needle"; then pass; else fail "${msg:+$msg: }unexpectedly contains '$needle'"; fi
}

assert_true() {
  if eval "$1" &>/dev/null; then pass; else fail "${2:-command returned false}"; fi
}

assert_false() {
  if ! eval "$1" &>/dev/null; then pass; else fail "${2:-command returned true}"; fi
}

# ------------------------------------------------------------------
# HTTP assertions
# ------------------------------------------------------------------
assert_http() {
  local url="$1" expected_code="${2:-200}" msg="${3:-}"
  local resp
  resp=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$url" 2>/dev/null || echo "000")
  if [ "$resp" = "$expected_code" ]; then pass; else fail "${msg:+$msg: }HTTP $resp (expected $expected_code) → $url"; fi
}

assert_http_200() { assert_http "$1" 200 "${2:-}"; }
assert_http_301() { assert_http "$1" 301 "${2:-}"; }
assert_http_401() { assert_http "$1" 401 "${2:-}"; }
assert_http_403() { assert_http "$1" 403 "${2:-}"; }

assert_json_value() {
  local json="$1" jq_filter="$2" expected="$3" msg="${4:-}"
  local actual
  actual=$(echo "$json" | jq -r "$jq_filter" 2>/dev/null || echo "JSON_PARSE_ERROR")
  if [ "$actual" = "$expected" ]; then pass; else fail "${msg:+$msg: }expected '$expected', got '$actual'"; fi
}

# ------------------------------------------------------------------
# Container assertions
# ------------------------------------------------------------------
assert_container_running() {
  local name="$1"
  local status
  status=$(docker inspect -f '{{.State.Status}}' "$name" 2>/dev/null || echo "not_found")
  if [ "$status" = "running" ]; then pass; else fail "container '$name' status: $status"; fi
}

assert_container_healthy() {
  local name="$1"
  local health
  health=$(docker inspect -f '{{.State.Health.Status}}' "$name" 2>/dev/null || echo "no_healthcheck")
  if [ "$health" = "healthy" ]; then pass; else fail "container '$name' health: $health"; fi
}

# ------------------------------------------------------------------
# File assertions
# ------------------------------------------------------------------
assert_file_exists() { if [ -f "$1" ]; then pass; else fail "file not found: $1"; fi; }
assert_dir_exists()  { if [ -d "$1" ]; then pass; else fail "directory not found: $1"; fi; }
assert_file_contains() { assert_file_exists "$1" && { if grep -qF "$2" "$1"; then pass; else fail "'$2' not found in $1"; fi; }; }

# ------------------------------------------------------------------
# Results
# ------------------------------------------------------------------
print_summary() {
  local total=$((PASS + FAIL + SKIP))
  echo ""
  echo -e "${BOLD}══════════════════════════════════════${RESET}"
  echo -e "  Total:  ${BOLD}$total${RESET}"
  echo -e "  Passed: ${GREEN}$PASS${RESET}"
  echo -e "  Failed: ${RED}$FAIL${RESET}"
  if [ "$SKIP" -gt 0 ]; then echo -e "  Skipped: ${YELLOW}$SKIP${RESET}"; fi
  echo -e "${BOLD}══════════════════════════════════════${RESET}"

  if [ "$FAIL" -gt 0 ]; then
    echo -e "\n${RED}Some tests failed.${RESET}"
    return 1
  else
    echo -e "\n${GREEN}All tests passed!${RESET}"
    return 0
  fi
}