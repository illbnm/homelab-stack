#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Test Assertion Library
# Provides assertion functions for integration testing
# =============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RESET='\033[0m'

# Global test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# =============================================================================
# Basic Assertions
# =============================================================================

assert_eq() {
  local actual="$1"
  local expected="$2"
  local msg="${3:-Values should be equal}"
  
  if [ "$actual" = "$expected" ]; then
    log_test_pass "$msg"
    return 0
  else
    log_test_fail "$msg" "Expected: $expected, Got: $actual"
    return 1
  fi
}

assert_not_empty() {
  local value="$1"
  local msg="${2:-Value should not be empty}"
  
  if [ -n "$value" ]; then
    log_test_pass "$msg"
    return 0
  else
    log_test_fail "$msg" "Value is empty"
    return 1
  fi
}

assert_exit_code() {
  local expected_code="$1"
  local msg="${2:-Command should exit with code $expected_code}"
  shift 2
  
  if "$@" > /dev/null 2>&1; then
    local actual_code=0
  else
    local actual_code=$?
  fi
  
  if [ "$actual_code" -eq "$expected_code" ]; then
    log_test_pass "$msg"
    return 0
  else
    log_test_fail "$msg" "Expected exit code $expected_code, got $actual_code"
    return 1
  fi
}

# =============================================================================
# Docker Assertions
# =============================================================================

assert_container_running() {
  local name="$1"
  local msg="${2:-Container $name should be running}"
  
  if docker ps --filter "name=$name" --filter "status=running" --format "{{.Names}}" | grep -q "^${name}$"; then
    log_test_pass "$msg"
    return 0
  else
    log_test_fail "$msg" "Container $name is not running"
    return 1
  fi
}

assert_container_healthy() {
  local name="$1"
  local timeout="${2:-60}"
  local msg="${3:-Container $name should be healthy}"
  
  local elapsed=0
  while [ $elapsed -lt $timeout ]; do
    if docker ps --filter "name=$name" --format "{{.Status}}" | grep -q "(healthy)"; then
      log_test_pass "$msg (${elapsed}s)"
      return 0
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done
  
  log_test_fail "$msg" "Container $name not healthy after ${timeout}s"
  return 1
}

assert_container_exists() {
  local name="$1"
  local msg="${2:-Container $name should exist}"
  
  if docker ps -a --filter "name=$name" --format "{{.Names}}" | grep -q "^${name}$"; then
    log_test_pass "$msg"
    return 0
  else
    log_test_fail "$msg" "Container $name does not exist"
    return 1
  fi
}

# =============================================================================
# HTTP Assertions
# =============================================================================

assert_http_200() {
  local url="$1"
  local timeout="${2:-30}"
  local msg="${3:-HTTP GET $url should return 200}"
  
  local status
  status=$(curl -sf -o /dev/null -w "%{http_code}" --max-time "$timeout" "$url" 2>/dev/null || echo "000")
  
  if [ "$status" = "200" ]; then
    log_test_pass "$msg"
    return 0
  else
    log_test_fail "$msg" "Expected 200, got $status"
    return 1
  fi
}

assert_http_response() {
  local url="$1"
  local pattern="$2"
  local msg="${3:-HTTP response should match pattern}"
  
  local response
  response=$(curl -sf --max-time 30 "$url" 2>/dev/null)
  
  if echo "$response" | grep -q "$pattern"; then
    log_test_pass "$msg"
    return 0
  else
    log_test_fail "$msg" "Response does not match pattern: $pattern"
    return 1
  fi
}

# =============================================================================
# JSON Assertions
# =============================================================================

assert_json_value() {
  local json="$1"
  local jq_path="$2"
  local expected="$3"
  local msg="${4:-JSON value should match}"
  
  local actual
  actual=$(echo "$json" | jq -r "$jq_path" 2>/dev/null)
  
  if [ "$actual" = "$expected" ]; then
    log_test_pass "$msg"
    return 0
  else
    log_test_fail "$msg" "Expected: $expected, Got: $actual"
    return 1
  fi
}

assert_json_key_exists() {
  local json="$1"
  local jq_path="$2"
  local msg="${3:-JSON key should exist}"
  
  if echo "$json" | jq -e "$jq_path" > /dev/null 2>&1; then
    log_test_pass "$msg"
    return 0
  else
    log_test_fail "$msg" "JSON key not found: $jq_path"
    return 1
  fi
}

assert_no_errors() {
  local json="$1"
  local msg="${2:-JSON should have no errors}"
  
  local errors
  errors=$(echo "$json" | jq -r '.errors // [] | length' 2>/dev/null)
  
  if [ "$errors" -eq 0 ]; then
    log_test_pass "$msg"
    return 0
  else
    log_test_fail "$msg" "Found $errors errors"
    return 1
  fi
}

# =============================================================================
# File Assertions
# =============================================================================

assert_file_exists() {
  local file="$1"
  local msg="${2:-File $file should exist}"
  
  if [ -f "$file" ]; then
    log_test_pass "$msg"
    return 0
  else
    log_test_fail "$msg" "File not found: $file"
    return 1
  fi
}

assert_file_contains() {
  local file="$1"
  local pattern="$2"
  local msg="${3:-File should contain pattern}"
  
  if grep -q "$pattern" "$file" 2>/dev/null; then
    log_test_pass "$msg"
    return 0
  else
    log_test_fail "$msg" "Pattern not found: $pattern"
    return 1
  fi
}

# =============================================================================
# Logging Functions
# =============================================================================

log_test_pass() {
  local msg="$1"
  echo -e "${GREEN}✅ PASS${RESET} - $msg"
  TESTS_PASSED=$((TESTS_PASSED + 1))
}

log_test_fail() {
  local msg="$1"
  local reason="${2:-}"
  echo -e "${RED}❌ FAIL${RESET} - $msg"
  [ -n "$reason" ] && echo -e "   ${YELLOW}Reason:${RESET} $reason"
  TESTS_FAILED=$((TESTS_FAILED + 1))
}

log_test_skip() {
  local msg="$1"
  local reason="${2:-No reason provided}"
  echo -e "${YELLOW}⏭  SKIP${RESET} - $msg"
  echo -e "   ${YELLOW}Reason:${RESET} $reason"
  TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
}

# =============================================================================
# Helper Functions
# =============================================================================

wait_for_http() {
  local url="$1"
  local timeout="${2:-60}"
  local interval="${3:-2}"
  
  local elapsed=0
  while [ $elapsed -lt $timeout ]; do
    if curl -sf -o /dev/null "$url" 2>/dev/null; then
      return 0
    fi
    sleep "$interval"
    elapsed=$((elapsed + interval))
  done
  
  return 1
}

get_test_results() {
  echo "passed=$TESTS_PASSED failed=$TESTS_FAILED skipped=$TESTS_SKIPPED"
}
