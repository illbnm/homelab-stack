#!/usr/bin/env bash
# Assertion library for homelab integration tests
set -euo pipefail

PASS=0
FAIL=0
SKIP=0

_green() { echo -e "\033[32m$1\033[0m"; }
_red() { echo -e "\033[31m$1\033[0m"; }
_yellow() { echo -e "\033[33m$1\033[0m"; }

assert_eq() {
  local actual="$1" expected="$2" msg="${3:-assert_eq}"
  if [ "$actual" = "$expected" ]; then
    _green "  ✓ $msg"
    ((PASS++))
  else
    _red "  ✗ $msg (expected: $expected, got: $actual)"
    ((FAIL++))
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" msg="${3:-assert_contains}"
  if echo "$haystack" | grep -q "$needle"; then
    _green "  ✓ $msg"
    ((PASS++))
  else
    _red "  ✗ $msg (expected to contain: $needle)"
    ((FAIL++))
  fi
}

assert_container_running() {
  local name="$1"
  local state
  state=$(docker inspect -f '{{.State.Running}}' "$name" 2>/dev/null || echo "false")
  if [ "$state" = "true" ]; then
    _green "  ✓ container '$name' is running"
    ((PASS++))
  else
    _red "  ✗ container '$name' is NOT running"
    ((FAIL++))
  fi
}

assert_container_healthy() {
  local name="$1"
  local health
  health=$(docker inspect -f '{{.State.Health.Status}}' "$name" 2>/dev/null || echo "none")
  if [ "$health" = "healthy" ]; then
    _green "  ✓ container '$name' is healthy"
    ((PASS++))
  else
    _red "  ✗ container '$name' health: $health"
    ((FAIL++))
  fi
}

assert_http_200() {
  local url="$1" msg="${2:-GET $url returns 200}"
  local code
  code=$(curl -sf -o /dev/null -w '%{http_code}' "$url" 2>/dev/null || echo "000")
  if [ "$code" = "200" ]; then
    _green "  ✓ $msg"
    ((PASS++))
  else
    _red "  ✗ $msg (got HTTP $code)"
    ((FAIL++))
  fi
}

assert_http_code() {
  local url="$1" expected="$2" msg="${3:-GET $url returns $2}"
  local code
  code=$(curl -sf -o /dev/null -w '%{http_code}' "$url" 2>/dev/null || echo "000")
  if [ "$code" = "$expected" ]; then
    _green "  ✓ $msg"
    ((PASS++))
  else
    _red "  ✗ $msg (got HTTP $code)"
    ((FAIL++))
  fi
}

assert_json_value() {
  local json="$1" path="$2" expected="$3" msg="${4:-json $path = $expected}"
  local actual
  actual=$(echo "$json" | python3 -c "import json,sys; d=json.load(sys.stdin); print(eval('d'+\"$path\".replace('.','')))" 2>/dev/null || echo "PARSE_ERROR")
  assert_eq "$actual" "$expected" "$msg"
}

assert_port_open() {
  local host="$1" port="$2" msg="${3:-port $host:$port is open}"
  if timeout 3 bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null; then
    _green "  ✓ $msg"
    ((PASS++))
  else
    _red "  ✗ $msg"
    ((FAIL++))
  fi
}

skip_test() {
  local msg="$1"
  _yellow "  ⊘ SKIP: $msg"
  ((SKIP++))
}

print_summary() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Results: $(_green "$PASS passed"), $(_red "$FAIL failed"), $(_yellow "$SKIP skipped")"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

print_json_report() {
  echo "{\"passed\":$PASS,\"failed\":$FAIL,\"skipped\":$SKIP,\"total\":$((PASS+FAIL+SKIP))}"
}
