#!/usr/bin/env bash
# assert.sh — Assertion library for homelab-stack tests
# shellcheck disable=SC2034

ASSERT_PASS=0
ASSERT_FAIL=0
ASSERT_SKIP=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

assert_pass() {
  local name="$1"
  ASSERT_PASS=$((ASSERT_PASS + 1))
  echo -e "  ${GREEN}✓${NC} ${name}"
}

assert_fail() {
  local name="$1"
  local msg="${2:-}"
  ASSERT_FAIL=$((ASSERT_FAIL + 1))
  echo -e "  ${RED}✗${NC} ${name}"
  [[ -n "$msg" ]] && echo -e "    ${RED}→ ${msg}${NC}"
}

assert_skip() {
  local name="$1"
  local reason="${2:-}"
  ASSERT_SKIP=$((ASSERT_SKIP + 1))
  echo -e "  ${YELLOW}⊘${NC} ${name} (skipped${reason:+: $reason})"
}

assert_eq() {
  local name="$1"
  local expected="$2"
  local actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    assert_pass "$name"
  else
    assert_fail "$name" "expected='${expected}' actual='${actual}'"
  fi
}

assert_not_empty() {
  local name="$1"
  local value="$2"
  if [[ -n "$value" ]]; then
    assert_pass "$name"
  else
    assert_fail "$name" "value is empty"
  fi
}

assert_exit_code() {
  local name="$1"
  local expected="$2"
  local actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    assert_pass "$name"
  else
    assert_fail "$name" "expected exit code ${expected}, got ${actual}"
  fi
}

assert_container_running() {
  local name="$1"
  local container="$2"
  local status
  status=$(docker inspect --format '{{.State.Status}}' "$container" 2>/dev/null || echo "not_found")
  if [[ "$status" == "running" ]]; then
    assert_pass "$name"
  else
    assert_fail "$name" "container '${container}' status='${status}'"
  fi
}

assert_container_healthy() {
  local name="$1"
  local container="$2"
  local timeout="${3:-60}"
  local elapsed=0
  local health
  while [[ $elapsed -lt $timeout ]]; do
    health=$(docker inspect --format '{{.State.Health.Status}}' "$container" 2>/dev/null || echo "not_found")
    if [[ "$health" == "healthy" ]]; then
      assert_pass "$name"
      return 0
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done
  health=$(docker inspect --format '{{.State.Health.Status}}' "$container" 2>/dev/null || echo "not_found")
  assert_fail "$name" "container '${container}' health='${health}' after ${timeout}s"
}

assert_http_200() {
  local name="$1"
  local url="$2"
  local code
  code=$(curl -sk -o /dev/null -w '%{http_code}' --max-time 10 "$url" 2>/dev/null || echo "000")
  if [[ "$code" == "200" ]]; then
    assert_pass "$name"
  else
    assert_fail "$name" "GET ${url} returned HTTP ${code}"
  fi
}

assert_http_response() {
  local name="$1"
  local url="$2"
  local expected_code="$3"
  local code
  code=$(curl -sk -o /dev/null -w '%{http_code}' --max-time 10 "$url" 2>/dev/null || echo "000")
  if [[ "$code" == "$expected_code" ]]; then
    assert_pass "$name"
  else
    assert_fail "$name" "GET ${url} expected HTTP ${expected_code}, got ${code}"
  fi
}

assert_json_value() {
  local name="$1"
  local json="$2"
  local key="$3"
  local expected="$4"
  local actual
  actual=$(echo "$json" | jq -r "$key" 2>/dev/null || echo "__jq_error__")
  if [[ "$actual" == "$expected" ]]; then
    assert_pass "$name"
  else
    assert_fail "$name" "json key '${key}': expected='${expected}' actual='${actual}'"
  fi
}

assert_json_key_exists() {
  local name="$1"
  local json="$2"
  local key="$3"
  local val
  val=$(echo "$json" | jq -r "$key" 2>/dev/null || echo "null")
  if [[ "$val" != "null" && "$val" != "__jq_error__" ]]; then
    assert_pass "$name"
  else
    assert_fail "$name" "json key '${key}' does not exist or is null"
  fi
}

assert_no_errors() {
  local name="$1"
  local output="$2"
  if echo "$output" | grep -qiE 'error|fatal|panic'; then
    assert_fail "$name" "output contains error/fatal/panic"
  else
    assert_pass "$name"
  fi
}

assert_file_contains() {
  local name="$1"
  local file="$2"
  local pattern="$3"
  if grep -q "$pattern" "$file" 2>/dev/null; then
    assert_pass "$name"
  else
    assert_fail "$name" "file '${file}' does not contain '${pattern}'"
  fi
}

assert_no_latest_images() {
  local name="$1"
  local compose_file="$2"
  if grep -qE 'image:.*:latest' "$compose_file" 2>/dev/null; then
    assert_fail "$name" "'${compose_file}' contains ':latest' image tags"
  else
    assert_pass "$name"
  fi
}
