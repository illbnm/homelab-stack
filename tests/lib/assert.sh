#!/usr/bin/env bash
set -euo pipefail

ASSERT_PASS=0
ASSERT_FAIL=0
ASSERT_SKIP=0

assert_eq() {
  local actual="$1" expected="$2" msg="${3:-}"
  if [ "$actual" = "$expected" ]; then
    ((ASSERT_PASS++))
    return 0
  else
    ((ASSERT_FAIL++))
    echo "FAIL: $msg (expected: $expected, actual: $actual)" >&2
    return 1
  fi
}

assert_not_empty() {
  local value="$1" msg="${2:-}"
  if [ -n "$value" ]; then
    ((ASSERT_PASS++))
    return 0
  else
    ((ASSERT_FAIL++))
    echo "FAIL: $msg (value is empty)" >&2
    return 1
  fi
}

assert_exit_code() {
  local code="$1" msg="${2:-}"
  assert_eq "$code" "0" "$msg"
}

assert_container_running() {
  local name="$1"
  local status
  status=$(docker inspect --format='{{.State.Status}}' "$name" 2>/dev/null || echo "not_found")
  assert_eq "$status" "running" "Container $name should be running"
}

assert_container_healthy() {
  local name="$1"
  local timeout="${2:-60}"
  local elapsed=0
  while [ $elapsed -lt $timeout ]; do
    local health
    health=$(docker inspect --format='{{.State.Health.Status}}' "$name" 2>/dev/null || echo "unhealthy")
    if [ "$health" = "healthy" ]; then
      ((ASSERT_PASS++))
      return 0
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done
  ((ASSERT_FAIL++))
  echo "FAIL: Container $name not healthy after ${timeout}s" >&2
  return 1
}

assert_http_200() {
  local url="$1" timeout="${2:-30}"
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout "$timeout" --max-time "$timeout" "$url" 2>/dev/null || echo "000")
  assert_eq "$code" "200" "HTTP 200 expected for $url"
}

assert_http_response() {
  local url="$1" pattern="$2"
  if curl -s --max-time 30 "$url" 2>/dev/null | grep -q "$pattern"; then
    ((ASSERT_PASS++))
    return 0
  else
    ((ASSERT_FAIL++))
    echo "FAIL: Pattern '$pattern' not found in response from $url" >&2
    return 1
  fi
}

assert_json_value() {
  local json="$1" jq_path="$2" expected="$3"
  local actual
  actual=$(echo "$json" | jq -r "$jq_path" 2>/dev/null || echo "null")
  assert_eq "$actual" "$expected" "jq $jq_path should equal $expected"
}

assert_json_key_exists() {
  local json="$1" jq_path="$2"
  if echo "$json" | jq -e "$jq_path" > /dev/null 2>&1; then
    ((ASSERT_PASS++))
    return 0
  else
    ((ASSERT_FAIL++))
    echo "FAIL: jq key $jq_path does not exist" >&2
    return 1
  fi
}

assert_no_errors() {
  local json="$1"
  local errors
  errors=$(echo "$json" | jq '.errors' 2>/dev/null || echo "\"parse_error\"")
  if [ "$errors" = "null" ] || [ "$errors" = "[]" ]; then
    ((ASSERT_PASS++))
    return 0
  else
    ((ASSERT_FAIL++))
    echo "FAIL: JSON contains errors: $errors" >&2
    return 1
  fi
}

assert_file_contains() {
  local file="$1" pattern="$2"
  if grep -q "$pattern" "$file" 2>/dev/null; then
    ((ASSERT_PASS++))
    return 0
  else
    ((ASSERT_FAIL++))
    echo "FAIL: Pattern '$pattern' not found in $file" >&2
    return 1
  fi
}

assert_no_latest_images() {
  local dir="$1"
  local count
  count=$(grep -r 'image:.*:latest' "$dir" 2>/dev/null | grep -v '#.*:latest' | wc -l)
  assert_eq "$count" "0" "Found :latest image tags in $dir"
}

print_summary() {
  local total=$((ASSERT_PASS + ASSERT_FAIL + ASSERT_SKIP))
  echo ""
  echo "──────────────────────────────────────"
  echo "Results: $ASSERT_PASS passed, $ASSERT_FAIL failed, $ASSERT_SKIP skipped"
  echo "Total: $total"
  echo "──────────────────────────────────────"
}

export -f assert_eq assert_not_empty assert_exit_code
export -f assert_container_running assert_container_healthy
export -f assert_http_200 assert_http_response
export -f assert_json_value assert_json_key_exists assert_no_errors
export -f assert_file_contains assert_no_latest_images
export -f print_summary
export ASSERT_PASS ASSERT_FAIL ASSERT_SKIP
