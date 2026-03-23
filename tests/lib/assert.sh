#!/usr/bin/env bash
# =============================================================================
# HomeLab Test Framework — Assertion Library
# Usage: source this file, then call assert_* functions
# Returns 0 on pass, 1 on fail (sets _ASSERT_LAST_MSG)
# =============================================================================

_ASSERT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
source "$_ASSERT_DIR/docker.sh"

# Colors (only if terminal)
if [[ -t 1 ]]; then
  _GREEN='\033[0;32m'; _RED='\033[0;31m'; _YELLOW='\033[1;33m'; _NC='\033[0m'
else
  _GREEN=''; _RED=''; _YELLOW=''; _NC=''
fi

_ASSERT_LAST_MSG=""

# ---------------------------------------------------------------------------
# Core assertion
# ---------------------------------------------------------------------------
_assert_result() {
  local result=$1 msg="$2"
  if [[ $result -eq 0 ]]; then
    _ASSERT_LAST_MSG="${_GREEN}PASS${_NC} $msg"
    return 0
  else
    _ASSERT_LAST_MSG="${_RED}FAIL${_NC} $msg"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Equality
# ---------------------------------------------------------------------------
assert_eq() {
  local actual="$1" expected="$2" msg="${3:-"Expected '$expected', got '$actual'"}"
  [[ "$actual" == "$expected" ]]
  _assert_result $? "$msg"
}

assert_not_eq() {
  local actual="$1" unexpected="$2" msg="${3:-"Expected not '$unexpected', got '$actual'"}"
  [[ "$actual" != "$unexpected" ]]
  _assert_result $? "$msg"
}

assert_not_empty() {
  local value="$1" msg="${2:-"Value should not be empty"}"
  [[ -n "$value" ]]
  _assert_result $? "$msg"
}

assert_contains() {
  local haystack="$1" needle="$2" msg="${3:-"Should contain '$needle'"}"
  [[ "$haystack" == *"$needle"* ]]
  _assert_result $? "$msg"
}

assert_file_exists() {
  local file="$1" msg="${2:-"File should exist: $file"}"
  [[ -f "$file" ]]
  _assert_result $? "$msg"
}

assert_file_contains() {
  local file="$1" pattern="$2" msg="${3:-"File should contain '$pattern'"}"
  [[ -f "$file" ]] && grep -q "$pattern" "$file"
  _assert_result $? "$msg"
}

# ---------------------------------------------------------------------------
# Exit code
# ---------------------------------------------------------------------------
assert_exit_code() {
  local actual=$1 expected=$2 msg="${3:-"Exit code should be $expected, got $actual"}"
  [[ "$actual" -eq "$expected" ]]
  _assert_result $? "$msg"
}

# ---------------------------------------------------------------------------
# Docker assertions
# ---------------------------------------------------------------------------
assert_container_running() {
  local name="$1" msg="${2:-"Container $name should be running"}"
  _docker_is_running "$name"
  _assert_result $? "$msg"
}

assert_container_healthy() {
  local name="$1" timeout="${2:-60}" msg="${3:-"Container $name should be healthy"}"
  _docker_wait_healthy "$name" "$timeout"
  _assert_result $? "$msg"
}

assert_container_stopped() {
  local name="$1" msg="${2:-"Container $name should be stopped"}"
  ! _docker_is_running "$name"
  _assert_result $? "$msg"
}

assert_volume_exists() {
  local name="$1" msg="${2:-"Volume $name should exist"}"
  docker volume inspect "$name" >/dev/null 2>&1
  _assert_result $? "$msg"
}

assert_no_latest_images() {
  local dir="$1" msg="${2:-"No :latest tags should be used in $dir"}"
  local found
  found=$(grep -r 'image:.*:latest' "$dir" 2>/dev/null | grep -v '#' || true)
  [[ -z "$found" ]]
  _assert_result $? "$msg${found:+ — Found: $found}"
}

# ---------------------------------------------------------------------------
# HTTP assertions
# ---------------------------------------------------------------------------
assert_http_200() {
  local url="$1" timeout="${2:-30}" msg="${3:-"HTTP GET $url should return 2xx"}"
  local code
  code=$(_http_get "$url" "$timeout")
  [[ "$code" =~ ^[23] ]]
  _assert_result $? "$msg (got HTTP $code)"
}

assert_http_response() {
  local url="$1" pattern="$2" timeout="${3:-30}" msg="${4:-"$url should match pattern"}"
  local body
  body=$(curl -sf --connect-timeout 5 --max-time "$timeout" "$url" 2>/dev/null || echo "")
  echo "$body" | grep -q "$pattern"
  _assert_result $? "$msg"
}

assert_json_value() {
  local json="$1" jq_path="$2" expected="$3" msg="${4:-"JSON $jq_path should be '$expected'"}"
  local actual
  actual=$(echo "$json" | jq -r "$jq_path" 2>/dev/null || echo "")
  [[ "$actual" == "$expected" ]]
  _assert_result $? "$msg (got '$actual')"
}

assert_json_key_exists() {
  local json="$1" jq_path="$2" msg="${3:-"JSON key $jq_path should exist"}"
  echo "$json" | jq -e "$jq_path" >/dev/null 2>&1
  _assert_result $? "$msg"
}

# ---------------------------------------------------------------------------
# Network assertions
# ---------------------------------------------------------------------------
assert_port_open() {
  local host="${1:-localhost}" port=$2 timeout="${3:-3}" msg="${4:-"Port $port on $host should be open"}"
  nc -z -w"$timeout" "$host" "$port" 2>/dev/null
  _assert_result $? "$msg"
}

assert_dns_resolves() {
  local domain="$1" msg="${2:-"DNS should resolve $domain"}"
  nslookup "$domain" >/dev/null 2>&1 || dig "$domain" +short >/dev/null 2>&1
  _assert_result $? "$msg"
}
