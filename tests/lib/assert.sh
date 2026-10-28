#!/usr/bin/env bash

# Assertion test primitives
assert_eq() {
  local expected="$1"
  local actual="$2"
  local msg="${3:-Values do not match}"
  if [ "$expected" != "$actual" ]; then
    echo "  ❌ ASSERTION FAILED: $msg (Expected: '$expected', Got: '$actual')" >&2
    return 1
  fi
  return 0
}

assert_not_eq() {
  local val1="$1"
  local val2="$2"
  local msg="${3:-Values match unexpectedly}"
  if [ "$val1" = "$val2" ]; then
    echo "  ❌ ASSERTION FAILED: $msg" >&2
    return 1
  fi
  return 0
}

assert_exit_code() {
  local expected="$1"
  local actual="$2"
  local msg="${3:-Unexpected exit code}"
  assert_eq "$expected" "$actual" "$msg"
}

assert_http_200() {
  local url="$1"
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 "$url" 2>/dev/null || echo "000")
  if [ "$code" != "200" ] && [ "$code" != "302" ]; then
    echo "  ❌ HTTP CHECK FAILED for $url: Expected 200/302, got $code" >&2
    return 1
  fi
  return 0
}

assert_container_running() {
  local cname="$1"
  local state
  state=$(docker inspect --format='{{.State.Status}}' "$cname" 2>/dev/null || echo "not_found")
  if [ "$state" != "running" ]; then
    echo "  ❌ CONTAINER NOT RUNNING: $cname (State: $state)" >&2
    return 1
  fi
  return 0
}

assert_container_healthy() {
  local cname="$1"
  local status
  status=$(docker inspect --format='{{json .State.Health.Status}}' "$cname" 2>/dev/null || echo '"none"')
  if [ "$status" = '"unhealthy"' ]; then
    echo "  ❌ CONTAINER UNHEALTHY: $cname" >&2
    return 1
  fi
  return 0
}

assert_json_value() {
  local json_str="$1"
  local query="$2"
  local expected="$3"
  if command -v jq >/dev/null 2>&1; then
    local actual
    actual=$(echo "$json_str" | jq -r "$query" 2>/dev/null || echo "")
    assert_eq "$expected" "$actual" "JSON value mismatch for query $query"
  fi
}

assert_json_key_exists() {
  local json_str="$1"
  local query="$2"
  if command -v jq >/dev/null 2>&1; then
    local val
    val=$(echo "$json_str" | jq -r "$query" 2>/dev/null || echo "null")
    if [ "$val" = "null" ] || [ -z "$val" ]; then
      echo "  ❌ JSON key does not exist: $query" >&2
      return 1
    fi
  fi
  return 0
}

assert_no_errors() {
  local str="$1"
  if echo "$str" | grep -iqE "error|exception|fail"; then
    echo "  ❌ Error detected in response string" >&2
    return 1
  fi
  return 0
}
