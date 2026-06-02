#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Test Assertion Library
# =============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

PASSED=0
FAILED=0
SKIPPED=0

assert_eq() {
  local actual="$1" expected="$2" msg="${3:-}"
  if [[ "$actual" == "$expected" ]]; then
    return 0
  fi
  echo "    Expected: '$expected'"
  echo "    Actual:   '$actual'"
  [[ -n "$msg" ]] && echo "    $msg"
  return 1
}

assert_not_empty() {
  local value="$1" msg="${2:-}"
  if [[ -n "$value" ]]; then
    return 0
  fi
  echo "    Value is empty"
  [[ -n "$msg" ]] && echo "    $msg"
  return 1
}

assert_exit_code() {
  local expected="$1" actual="${2:-$?}" msg="${3:-}"
  if [[ "$actual" -eq "$expected" ]]; then
    return 0
  fi
  echo "    Expected exit code: $expected, Got: $actual"
  [[ -n "$msg" ]] && echo "    $msg"
  return 1
}

assert_container_running() {
  local name="$1"
  if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${name}$"; then
    return 0
  fi
  echo "    Container '$name' is not running"
  docker ps --format 'table {{.Names}}\t{{.Status}}' 2>/dev/null || true
  return 1
}

assert_container_healthy() {
  local name="$1" max_wait="${2:-60}"
  local waited=0 interval=2
  while [[ $waited -lt $max_wait ]]; do
    local health
    health=$(docker inspect --format '{{.State.Health.Status}}' "$name" 2>/dev/null || echo 'starting')
    if [[ "$health" == "healthy" ]]; then
      return 0
    fi
    if [[ "$health" == "unhealthy" ]]; then
      echo "    Container '$name' is unhealthy"
      docker logs --tail=20 "$name" 2>/dev/null || true
      return 1
    fi
    sleep "$interval"
    waited=$((waited + interval))
  done
  echo "    Container '$name' did not become healthy within ${max_wait}s"
  docker logs --tail=20 "$name" 2>/dev/null || true
  return 1
}

assert_http_200() {
  local url="$1" timeout="${2:-30}"
  local code
  code=$(curl -sf -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time "$timeout" "$url" 2>/dev/null || echo "000")
  if [[ "$code" =~ ^2[0-9][0-9]$ ]]; then
    return 0
  fi
  echo "    HTTP $code from $url (expected 2xx)"
  [[ "$code" == "000" ]] && echo "    (Connection failed or timeout)"
  return 1
}

assert_http_response() {
  local url="$1" pattern="$2" timeout="${3:-30}"
  local body
  body=$(curl -sf --connect-timeout 5 --max-time "$timeout" "$url" 2>/dev/null || echo "")
  if echo "$body" | grep -q "$pattern"; then
    return 0
  fi
  echo "    Pattern '$pattern' not found in response from $url"
  return 1
}

assert_json_value() {
  local json="$1" jq_path="$2" expected="$3" msg="${4:-}"
  local actual
  actual=$(echo "$json" | jq -r "$jq_path" 2>/dev/null || echo "__JQ_ERROR__")
  if [[ "$actual" == "$expected" ]]; then
    return 0
  fi
  echo "    JSON path $jq_path: expected '$expected', got '$actual'"
  [[ -n "$msg" ]] && echo "    $msg"
  return 1
}

assert_json_key_exists() {
  local json="$1" jq_path="$2" msg="${3:-}"
  local result
  result=$(echo "$json" | jq -e "$jq_path" 2>/dev/null) || {
    echo "    JSON key '$jq_path' not found"
    [[ -n "$msg" ]] && echo "    $msg"
    return 1
  }
  return 0
}

assert_no_errors() {
  local json="$1" msg="${2:-}"
  local errors
  errors=$(echo "$json" | jq -r '.errors // empty' 2>/dev/null || echo "")
  if [[ -z "$errors" ]]; then
    return 0
  fi
  echo "    Errors found: $errors"
  [[ -n "$msg" ]] && echo "    $msg"
  return 1
}

assert_file_contains() {
  local file="$1" pattern="$2" msg="${3:-}"
  if [[ -f "$file" ]] && grep -q "$pattern" "$file"; then
    return 0
  fi
  echo "    File '$file' does not contain '$pattern'"
  [[ -n "$msg" ]] && echo "    $msg"
  return 1
}

assert_no_latest_images() {
  local dir="$1" msg="${2:-}"
  local count
  count=$(grep -r 'image:.*:latest' "$dir" 2>/dev/null | wc -l || echo 0)
  if [[ "$count" -eq 0 ]]; then
    return 0
  fi
  echo "    Found $count :latest image tag(s) in $dir"
  grep -rn 'image:.*:latest' "$dir" 2>/dev/null || true
  [[ -n "$msg" ]] && echo "    $msg"
  return 1
}

assert_http_redirect_to() {
  local url="$1" expected_location="$2" msg="${3:-}"
  local location
  location=$(curl -sI -o /dev/null -w '%{redirect_url}' --connect-timeout 5 --max-time 10 "$url" 2>/dev/null || echo "")
  if echo "$location" | grep -q "$expected_location"; then
    return 0
  fi
  echo "    Redirect from $url to '$location' (expected containing '$expected_location')"
  [[ -n "$msg" ]] && echo "    $msg"
  return 1
}

assert_port_open() {
  local host="${1:-localhost}" port="$2" msg="${3:-}"
  if nc -z -w3 "$host" "$port" 2>/dev/null; then
    return 0
  fi
  echo "    Port $port on $host is not reachable"
  [[ -n "$msg" ]] && echo "    $msg"
  return 1
}
