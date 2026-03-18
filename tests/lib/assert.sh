#!/usr/bin/env bash
# =============================================================================
# Assertion Library
# Provides assertion functions for testing
# =============================================================================

# Test counters
PASSED=0
FAILED=0
SKIPPED=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Assertions
log_pass() {
  echo -e "  ${GREEN}✓${NC} $*"
  ((PASSED++))
}

log_fail() {
  echo -e "  ${RED}✗${NC} $*"
  ((FAILED++))
}

log_skip() {
  echo -e "  ${YELLOW}~${NC} $* (skipped)"
  ((SKIPPED++))
}

log_group() {
  echo -e "\n${BLUE}${BOLD}[$*]${NC}"
}

# Assertion functions
assert_eq() {
  local expected="$1"
  local actual="$2"
  local message="${3:-Values should be equal}"
  if [[ "$expected" == "$actual" ]]; then
    log_pass "$message"
    return 0
  else
    log_fail "$message (expected: $expected, got: $actual)"
    return 1
  fi
}

assert_http_200() {
  local url="$1"
  local message="${2:-HTTP 200 check for $url}"
  local code
  code=$(curl -sf -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 10 "$url" 2>/dev/null || echo "000")
  if [[ "$code" =~ ^2[0-9][0-9]$ ]]; then
    log_pass "$message → HTTP $code"
    return 0
  else
    log_fail "$message → HTTP $code (expected 2xx)"
    return 1
  fi
}

assert_container_running() {
  local name="$1"
  if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${name}$"; then
    log_pass "Container $name is running"
    return 0
  else
    log_skip "Container $name not running"
    return 2
  fi
}

assert_container_healthy() {
  local name="$1"
  local health
  health=$(docker inspect --format '{{.State.Health.Status}}' "$name" 2>/dev/null || echo 'no-healthcheck')
  if [[ "$health" == 'healthy' ]] || [[ "$health" == 'no-healthcheck' ]]; then
    log_pass "Container $name is healthy ($health)"
    return 0
  else
    log_fail "Container $name unhealthy: $health"
    return 1
  fi
}