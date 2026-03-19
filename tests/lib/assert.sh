#!/usr/bin/env bash
# =============================================================================
# assert.sh — Assertion library for HomeLab integration tests
# =============================================================================

# Assert two values are equal
# Usage: assert_eq "actual" "expected" "description"
assert_eq() {
  local actual="$1" expected="$2" desc="${3:-assert_eq}"
  if [[ "$actual" == "$expected" ]]; then
    test_pass "$desc"
  else
    test_fail "$desc" "expected '$expected', got '$actual'"
  fi
}

# Assert value is not empty
# Usage: assert_not_empty "value" "description"
assert_not_empty() {
  local value="$1" desc="${2:-assert_not_empty}"
  if [[ -n "$value" ]]; then
    test_pass "$desc"
  else
    test_fail "$desc" "value is empty"
  fi
}

# Assert string contains substring
# Usage: assert_contains "haystack" "needle" "description"
assert_contains() {
  local haystack="$1" needle="$2" desc="${3:-assert_contains}"
  if [[ "$haystack" == *"$needle"* ]]; then
    test_pass "$desc"
  else
    test_fail "$desc" "string does not contain '$needle'"
  fi
}

# Assert an HTTP endpoint returns the expected status code
# Usage: assert_http_status "url" "expected_code" "description"
assert_http_status() {
  local url="$1" expected="${2:-200}" desc="${3:-HTTP check $1}"
  local code
  code=$(curl -sf -o /dev/null -w '%{http_code}' \
    --connect-timeout 5 --max-time 10 "$url" 2>/dev/null || echo "000")
  if [[ "$code" == "$expected" ]]; then
    test_pass "$desc (HTTP $code)"
  else
    test_fail "$desc" "expected HTTP $expected, got $code"
  fi
}

# Assert HTTP 200
# Usage: assert_http_200 "url" "description"
assert_http_200() {
  local url="$1" desc="${2:-HTTP 200 $1}"
  assert_http_status "$url" "200" "$desc"
}

# Assert HTTP response body contains a string
# Usage: assert_http_body_contains "url" "needle" "description"
assert_http_body_contains() {
  local url="$1" needle="$2" desc="${3:-HTTP body check $1}"
  local body
  body=$(curl -sf --connect-timeout 5 --max-time 10 "$url" 2>/dev/null || echo "")
  if [[ -z "$body" ]]; then
    test_fail "$desc" "empty response from $url"
  elif [[ "$body" == *"$needle"* ]]; then
    test_pass "$desc"
  else
    test_fail "$desc" "response does not contain '$needle'"
  fi
}

# Assert a JSON field equals an expected value (requires jq)
# Usage: assert_json_value "json_string" "jq_filter" "expected" "description"
assert_json_value() {
  local json="$1" filter="$2" expected="$3" desc="${4:-JSON value check}"
  if ! command -v jq &>/dev/null; then
    test_skip "$desc" "jq not installed"
    return
  fi
  local actual
  actual=$(echo "$json" | jq -r "$filter" 2>/dev/null || echo "")
  if [[ "$actual" == "$expected" ]]; then
    test_pass "$desc"
  else
    test_fail "$desc" "at $filter: expected '$expected', got '$actual'"
  fi
}

# Assert a JSON key exists
# Usage: assert_json_key_exists "json_string" "jq_filter" "description"
assert_json_key_exists() {
  local json="$1" filter="$2" desc="${3:-JSON key exists}"
  if ! command -v jq &>/dev/null; then
    test_skip "$desc" "jq not installed"
    return
  fi
  local val
  val=$(echo "$json" | jq -r "$filter" 2>/dev/null || echo "null")
  if [[ "$val" != "null" && -n "$val" ]]; then
    test_pass "$desc"
  else
    test_fail "$desc" "key $filter not found or null"
  fi
}

# Assert no errors in JSON response (checks for common error fields)
# Usage: assert_no_errors "json_string" "description"
assert_no_errors() {
  local json="$1" desc="${2:-no errors in response}"
  if ! command -v jq &>/dev/null; then
    test_skip "$desc" "jq not installed"
    return
  fi
  local has_error
  has_error=$(echo "$json" | jq -r '
    if type == "array" then
      if (map(select(.errorMessage? // .error? // .message? | . != null)) | length) > 0
      then "yes" else "no" end
    elif type == "object" then
      if (.error? // .errorMessage? // .isValid? == false) then "yes" else "no" end
    else "no" end
  ' 2>/dev/null || echo "no")
  if [[ "$has_error" == "no" ]]; then
    test_pass "$desc"
  else
    test_fail "$desc" "response contains errors: $(echo "$json" | head -c 200)"
  fi
}

# Assert a TCP port is reachable
# Usage: assert_port_open "host" "port" "description"
assert_port_open() {
  local host="${1:-localhost}" port="$2" desc="${3:-port $2 open on $1}"
  if nc -z -w3 "$host" "$port" 2>/dev/null; then
    test_pass "$desc"
  else
    test_fail "$desc" "port $port not reachable on $host"
  fi
}

# Assert a container is running
# Usage: assert_container_running "container_name"
assert_container_running() {
  local name="$1" desc="${2:-Container $1 is running}"
  if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${name}$"; then
    test_pass "$desc"
  else
    test_fail "$desc" "container $name is not running"
  fi
}

# Assert a container is healthy
# Usage: assert_container_healthy "container_name"
assert_container_healthy() {
  local name="$1" desc="${2:-Container $1 is healthy}"
  if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${name}$"; then
    test_fail "$desc" "container $name is not running"
    return
  fi
  local health
  health=$(docker inspect --format '{{.State.Health.Status}}' "$name" 2>/dev/null || echo "none")
  case "$health" in
    healthy)       test_pass "$desc" ;;
    none)          test_pass "$desc (no healthcheck defined)" ;;
    *)             test_fail "$desc" "status: $health" ;;
  esac
}

# Assert a file exists
# Usage: assert_file_exists "path" "description"
assert_file_exists() {
  local path="$1" desc="${2:-File $1 exists}"
  if [[ -f "$path" ]]; then
    test_pass "$desc"
  else
    test_fail "$desc" "file not found: $path"
  fi
}

# Assert an environment variable is set
# Usage: assert_env_set "VAR_NAME" "description"
assert_env_set() {
  local var="$1" desc="${2:-Env $1 is set}"
  if [[ -n "${!var:-}" ]]; then
    test_pass "$desc"
  else
    test_fail "$desc" "\$$var is not set"
  fi
}
