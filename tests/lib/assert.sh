#!/usr/bin/env bash
# =============================================================================
# assert.sh — Assertion library for HomeLab Stack integration tests
# =============================================================================
set -uo pipefail

# Globals (set by runner)
TEST_CURRENT=""; TEST_RESULTS_DIR=""

assert_eq() {
  local actual="$1" expected="$2" msg="${3:-}"
  if [[ "$actual" == "$expected" ]]; then
    test_pass "${msg:-assert_eq: '$actual' == '$expected'}"
  else
    test_fail "${msg:-assert_eq} — expected '$expected', got '$actual'"
  fi
}

assert_not_empty() {
  local value="$1" msg="${2:-assert_not_empty}"
  if [[ -n "$value" ]]; then
    test_pass "$msg"
  else
    test_fail "$msg — value is empty"
  fi
}

assert_exit_code() {
  local expected="$1"; shift
  local output
  output=$("$@" 2>&1); local rc=$?
  if [[ "$rc" -eq "$expected" ]]; then
    test_pass "exit code $rc == $expected ($*)"
  else
    test_fail "exit code $rc != $expected ($*) — $output"
  fi
}

assert_container_running() {
  local name="$1"
  if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${name}$"; then
    test_pass "container '$name' is running"
  else
    test_fail "container '$name' is not running"
  fi
}

assert_container_healthy() {
  local name="$1" timeout="${2:-60}"
  local elapsed=0
  while (( elapsed < timeout )); do
    local health
    health=$(docker inspect --format '{{.State.Health.Status}}' "$name" 2>/dev/null || echo "no-healthcheck")
    case "$health" in
      healthy)       test_pass "container '$name' is healthy"; return 0 ;;
      unhealthy)     test_fail "container '$name' is unhealthy"; return 1 ;;
      no-healthcheck) test_pass "container '$name' running (no healthcheck)"; return 0 ;;
      starting)      sleep 2; ((elapsed+=2)) ;;
      *)             sleep 2; ((elapsed+=2)) ;;
    esac
  done
  test_fail "container '$name' not healthy within ${timeout}s"
}

assert_http_200() {
  local url="$1" timeout="${2:-15}"
  local code
  code=$(curl -sf -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time "$timeout" "$url" 2>/dev/null || echo 000)
  if [[ "$code" -ge 200 && "$code" -lt 400 ]]; then
    test_pass "HTTP $code — $url"
  else
    test_fail "HTTP $code — $url (expected 2xx/3xx)"
  fi
}

assert_http_status() {
  local url="$1" expected="${2:-200}" timeout="${3:-15}"
  local code
  code=$(curl -sf -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time "$timeout" "$url" 2>/dev/null || echo 000)
  if [[ "$code" -eq "$expected" ]]; then
    test_pass "HTTP $code == $expected — $url"
  else
    test_fail "HTTP $code != $expected — $url"
  fi
}

assert_http_response() {
  local url="$1" pattern="$2" timeout="${3:-15}"
  local body
  body=$(curl -sf --connect-timeout 5 --max-time "$timeout" "$url" 2>/dev/null)
  if echo "$body" | grep -q "$pattern"; then
    test_pass "response matches '$pattern' — $url"
  else
    test_fail "response missing '$pattern' — $url"
  fi
}

assert_json_value() {
  local json="$1" jq_path="$2" expected="$3" msg="${4:-}"
  if command -v jq &>/dev/null; then
    local actual
    actual=$(echo "$json" | jq -r "$jq_path" 2>/dev/null)
    if [[ "$actual" == "$expected" ]]; then
      test_pass "${msg:-JSON $jq_path == '$expected'}"
    else
      test_fail "${msg:-JSON $jq_path} — expected '$expected', got '$actual'"
    fi
  else
    test_skip "jq not installed — ${msg:-JSON value check}"
  fi
}

assert_json_key_exists() {
  local json="$1" jq_path="$2" msg="${3:-}"
  if command -v jq &>/dev/null; then
    if echo "$json" | jq -e "$jq_path" &>/dev/null; then
      test_pass "${msg:-JSON key $jq_path exists}"
    else
      test_fail "${msg:-JSON key $jq_path does not exist}"
    fi
  else
    test_skip "jq not installed — ${msg:-JSON key check}"
  fi
}

assert_no_errors() {
  local json="$1" msg="${2:-assert_no_errors}"
  if command -v jq &>/dev/null; then
    local errors
    errors=$(echo "$json" | jq -r '.errors // empty' 2>/dev/null)
    if [[ -z "$errors" ]]; then
      test_pass "$msg"
    else
      test_fail "$msg — errors: $errors"
    fi
  else
    test_skip "jq not installed — $msg"
  fi
}

assert_file_contains() {
  local file="$1" pattern="$2" msg="${3:-}"
  if [[ -f "$file" ]] && grep -q "$pattern" "$file" 2>/dev/null; then
    test_pass "${msg:-$file contains '$pattern'}"
  else
    test_fail "${msg:-$file missing '$pattern'}"
  fi
}

assert_network_exists() {
  local name="$1"
  if docker network ls --format '{{.Name}}' 2>/dev/null | grep -q "^${name}$"; then
    test_pass "network '$name' exists"
  else
    test_fail "network '$name' does not exist"
  fi
}

assert_port_open() {
  local host="${1:-localhost}" port="$2" msg="${3:-}"
  if command -v nc &>/dev/null; then
    if nc -z -w3 "$host" "$port" 2>/dev/null; then
      test_pass "${msg:-port $port on $host is open}"
    else
      test_fail "${msg:-port $port on $host is closed}"
    fi
  elif command -v timeout &>/dev/null; then
    if timeout 3 bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null; then
      test_pass "${msg:-port $port on $host is open}"
    else
      test_fail "${msg:-port $port on $host is closed}"
    fi
  else
    test_skip "nc not installed — ${msg:-port check}"
  fi
}

assert_no_latest_images() {
  local dir="${1:-stacks}"
  local count
  count=$(grep -r 'image:.*:latest' "$dir" --include='*.yml' --include='*.yaml' 2>/dev/null | wc -l)
  if [[ "$count" -eq 0 ]]; then
    test_pass "no :latest image tags in $dir"
  else
    test_fail "found $count :latest image tag(s) in $dir"
  fi
}
