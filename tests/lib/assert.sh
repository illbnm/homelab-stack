#!/usr/bin/env bash
# Assertion library for homelab-stack tests
set -euo pipefail

# ── colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

# ── colours (override if no-colour set externally) ───────────────────────────
[[ "${NO_COLOUR:-}" == "true" ]] && { RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; NC=''; }

# ── state ─────────────────────────────────────────────────────────────────────
ASSERT_PASSED=0; ASSERT_FAILED=0; TESTS_RUN=0

# ── helpers ───────────────────────────────────────────────────────────────────
section() { echo -e "\n${CYAN}── $1 ──${NC}"; }
pass()    { echo -e "  ${GREEN}PASS${NC} $*"; ((ASSERT_PASSED++)); ((TESTS_RUN++)); }
fail()    { echo -e "  ${RED}FAIL${NC} $*"; ((ASSERT_FAILED++)); ((TESTS_RUN++)); }
info()    { echo -e "  ${BLUE}INFO${NC} $*"; }
skip()    { echo -e "  ${YELLOW}SKIP${NC} $*"; ((TESTS_RUN++)); }

# ── assert_* functions ────────────────────────────────────────────────────────
assert_true() {
  local desc="$1" cmd="$2"
  if eval "$cmd" &>/dev/null; then
    pass "$desc"
  else
    fail "$desc (cmd: $cmd)"
  fi
}

assert_eq() {
  local desc="$1" got="$2" want="$3"
  TESTS_RUN=$((TESTS_RUN+1))
  if [[ "$got" == "$want" ]]; then
    pass "$desc"
  else
    fail "$desc — got '$got', want '$want'"
  fi
}

assert_http_2xx() {
  local desc="$1" url="$2" port="${3:-}"
  local full_url="$url"
  [[ -n "$port" ]] && full_url="http://localhost:$port"
  TESTS_RUN=$((TESTS_RUN+1))
  local code
  code=$(curl -sf -o /dev/null -w "%{http_code}" "$full_url" --max-time 15 2>/dev/null || echo "000")
  if [[ "$code" =~ ^2[0-9][0-9]$ ]]; then
    pass "$desc (HTTP $code)"
  else
    fail "$desc — expected 2xx, got HTTP $code"
  fi
}

assert_container_running() {
  local desc="$1" container="$2"
  TESTS_RUN=$((TESTS_RUN+1))
  if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${container}$"; then
    pass "$desc"
  else
    fail "$desc — container '$container' not running"
  fi
}

assert_container_healthy() {
  local desc="$1" container="$2"
  TESTS_RUN=$((TESTS_RUN+1))
  local status
  status=$(docker inspect --format '{{.State.Health.Status}}' "$container" 2>/dev/null || echo "none")
  if [[ "$status" == "healthy" ]]; then
    pass "$desc"
  elif [[ "$status" == "none" ]]; then
    # No healthcheck — fall back to running check
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${container}$"; then
      pass "$desc (no healthcheck)"
    else
      fail "$desc — container '$container' not found"
    fi
  else
    fail "$desc — '$container' is '$status'"
  fi
}

assert_port_open() {
  local desc="$1" host="$2" port="$3"
  TESTS_RUN=$((TESTS_RUN+1))
  if timeout 5 bash -c "nc -z $host $port" 2>/dev/null; then
    pass "$desc ($host:$port open)"
  else
    fail "$desc — $host:$port not reachable"
  fi
}

assert_env_set() {
  local desc="$1" env_file="$2" var="$3"
  TESTS_RUN=$((TESTS_RUN+1))
  if [[ -f "$env_file" ]] && grep -q "^${var}=" "$env_file" 2>/dev/null; then
    local val
    val=$(grep "^${var}=" "$env_file" | cut -d= -f2-)
    if [[ -n "$val" && "$val" != "changeme" && "$val" != "yourdomain.com" ]]; then
      pass "$desc ($var set)"
    else
      fail "$desc — $var has placeholder value"
    fi
  else
    fail "$desc — $var not set in $env_file"
  fi
}

# ── summary ───────────────────────────────────────────────────────────────────
assert_summary() {
  echo ""
  echo -e "  ───────────────────────────────────────"
  echo -e "  Tests: $TESTS_RUN   ${GREEN}Passed: $ASSERT_PASSED${NC}   ${RED}Failed: $ASSERT_FAILED${NC}"
  if [[ $ASSERT_FAILED -gt 0 ]]; then
    echo -e "  ${RED}RESULT: FAILED${NC}"
    return 1
  else
    echo -e "  ${GREEN}RESULT: ALL PASSED${NC}"
    return 0
  fi
}

reset_counters() { ASSERT_PASSED=0; ASSERT_FAILED=0; TESTS_RUN=0; }
log_test_start() { echo -e "\n${CYAN}━━━ $1 ━━━${NC}"; }