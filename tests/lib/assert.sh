#!/usr/bin/env bash
# =============================================================================
# assert.sh — Assertion library for HomeLab Stack integration tests
# =============================================================================
# Provides shell-based assertions for:
#   - Container status (running, healthy, exited)
#   - HTTP endpoint checks (status codes, response body)
#   - JSON parsing and value matching
#   - Port availability
#   - Log pattern matching
#   - DNS resolution
#   - Volume/mount verification
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

_PASS_COUNT=0
_FAIL_COUNT=0
_SKIP_COUNT=0
_CURRENT_TEST=""
_TEST_RESULTS=()

# Colors (disabled if NO_COLOR is set or not a terminal)
if [[ -z "${NO_COLOR:-}" ]] && [[ -t 1 ]]; then
  GREEN='\033[0;32m'
  RED='\033[0;31m'
  YELLOW='\033[1;33m'
  CYAN='\033[0;36m'
  BOLD='\033[1m'
  RESET='\033[0m'
else
  GREEN='' RED='' YELLOW='' CYAN='' BOLD='' RESET=''
fi

_assert_pass() {
  local msg="${1:-}"
  (( _PASS_COUNT++ ))
  _TEST_RESULTS+=("PASS|${_CURRENT_TEST}|${msg}")
  echo -e "  ${GREEN}✅ PASS${RESET} ${msg}"
}

_assert_fail() {
  local msg="${1:-}"
  local detail="${2:-}"
  (( _FAIL_COUNT++ ))
  _TEST_RESULTS+=("FAIL|${_CURRENT_TEST}|${msg}|${detail}")
  echo -e "  ${RED}❌ FAIL${RESET} ${msg}"
  [[ -n "$detail" ]] && echo -e "        ${RED}${detail}${RESET}"
}

_assert_skip() {
  local msg="${1:-}"
  local reason="${2:-}"
  (( _SKIP_COUNT++ ))
  _TEST_RESULTS+=("SKIP|${_CURRENT_TEST}|${msg}|${reason}")
  echo -e "  ${YELLOW}⏭  SKIP${RESET} ${msg} — ${reason}"
}

# ---------------------------------------------------------------------------
# Container assertions
# ---------------------------------------------------------------------------

# Check that a Docker container is running
# Usage: assert_container_running <container_name>
assert_container_running() {
  local name="$1"
  local msg="Container '${name}' is running"

  local state
  state=$(docker inspect --format='{{.State.Status}}' "$name" 2>/dev/null) || {
    _assert_fail "$msg" "Container not found"
    return 1
  }

  if [[ "$state" == "running" ]]; then
    _assert_pass "$msg"
    return 0
  else
    _assert_fail "$msg" "Expected: running, Got: ${state}"
    return 1
  fi
}

# Check that a Docker container reports healthy
# Usage: assert_container_healthy <container_name>
assert_container_healthy() {
  local name="$1"
  local msg="Container '${name}' is healthy"

  local health
  health=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' "$name" 2>/dev/null) || {
    _assert_fail "$msg" "Container not found"
    return 1
  }

  case "$health" in
    healthy)
      _assert_pass "$msg"
      return 0
      ;;
    no-healthcheck)
      _assert_skip "$msg" "No healthcheck configured"
      return 0
      ;;
    *)
      _assert_fail "$msg" "Expected: healthy, Got: ${health}"
      return 1
      ;;
  esac
}

# Check that a container has exited with a specific code (for init containers)
# Usage: assert_container_exit_code <container_name> <expected_code>
assert_container_exit_code() {
  local name="$1"
  local expected="${2:-0}"
  local msg="Container '${name}' exited with code ${expected}"

  local code
  code=$(docker inspect --format='{{.State.ExitCode}}' "$name" 2>/dev/null) || {
    _assert_fail "$msg" "Container not found"
    return 1
  }

  if [[ "$code" == "$expected" ]]; then
    _assert_pass "$msg"
    return 0
  else
    _assert_fail "$msg" "Expected exit code: ${expected}, Got: ${code}"
    return 1
  fi
}

# Check that a container is NOT running (for stopped/removed containers)
# Usage: assert_container_not_running <container_name>
assert_container_not_running() {
  local name="$1"
  local msg="Container '${name}' is not running"

  local state
  state=$(docker inspect --format='{{.State.Status}}' "$name" 2>/dev/null) || {
    _assert_pass "$msg"  # container doesn't exist = not running
    return 0
  }

  if [[ "$state" != "running" ]]; then
    _assert_pass "$msg"
    return 0
  else
    _assert_fail "$msg" "Container is still running"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# HTTP assertions
# ---------------------------------------------------------------------------

# Assert HTTP GET returns a specific status code
# Usage: assert_http_status <url> <expected_code> [timeout_seconds]
assert_http_status() {
  local url="$1"
  local expected="${2:-200}"
  local timeout="${3:-10}"
  local msg="HTTP ${expected} from ${url}"

  local status
  status=$(curl -s -o /dev/null -w '%{http_code}' --max-time "$timeout" \
    -k "$url" 2>/dev/null) || {
    _assert_fail "$msg" "Connection failed (timeout: ${timeout}s)"
    return 1
  }

  if [[ "$status" == "$expected" ]]; then
    _assert_pass "$msg"
    return 0
  else
    _assert_fail "$msg" "Expected: ${expected}, Got: ${status}"
    return 1
  fi
}

# Shorthand: assert HTTP 200
# Usage: assert_http_200 <url> [timeout]
assert_http_200() {
  assert_http_status "$1" 200 "${2:-10}"
}

# Assert HTTP response body contains a specific string
# Usage: assert_http_body_contains <url> <expected_string> [timeout]
assert_http_body_contains() {
  local url="$1"
  local expected="$2"
  local timeout="${3:-10}"
  local msg="HTTP body from ${url} contains '${expected}'"

  local body
  body=$(curl -s --max-time "$timeout" -k "$url" 2>/dev/null) || {
    _assert_fail "$msg" "Connection failed"
    return 1
  }

  if echo "$body" | grep -q "$expected"; then
    _assert_pass "$msg"
    return 0
  else
    _assert_fail "$msg" "String not found in response body"
    return 1
  fi
}

# Assert HTTP response body matches a regex
# Usage: assert_http_body_matches <url> <regex> [timeout]
assert_http_body_matches() {
  local url="$1"
  local regex="$2"
  local timeout="${3:-10}"
  local msg="HTTP body from ${url} matches /${regex}/"

  local body
  body=$(curl -s --max-time "$timeout" -k "$url" 2>/dev/null) || {
    _assert_fail "$msg" "Connection failed"
    return 1
  }

  if echo "$body" | grep -qE "$regex"; then
    _assert_pass "$msg"
    return 0
  else
    _assert_fail "$msg" "Pattern not matched in response body"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# JSON assertions (requires jq)
# ---------------------------------------------------------------------------

# Assert a JSON value at a jq path equals expected
# Usage: assert_json_value <json_string> <jq_path> <expected_value>
assert_json_value() {
  local json="$1"
  local path="$2"
  local expected="$3"
  local msg="JSON ${path} == '${expected}'"

  if ! command -v jq &>/dev/null; then
    _assert_skip "$msg" "jq not installed"
    return 0
  fi

  local actual
  actual=$(echo "$json" | jq -r "$path" 2>/dev/null) || {
    _assert_fail "$msg" "Failed to parse JSON or invalid path"
    return 1
  }

  if [[ "$actual" == "$expected" ]]; then
    _assert_pass "$msg"
    return 0
  else
    _assert_fail "$msg" "Expected: '${expected}', Got: '${actual}'"
    return 1
  fi
}

# Assert a JSON key exists at a jq path
# Usage: assert_json_key_exists <json_string> <jq_path>
assert_json_key_exists() {
  local json="$1"
  local path="$2"
  local msg="JSON key exists at ${path}"

  if ! command -v jq &>/dev/null; then
    _assert_skip "$msg" "jq not installed"
    return 0
  fi

  local result
  result=$(echo "$json" | jq -e "$path" 2>/dev/null) || {
    _assert_fail "$msg" "Key not found or JSON parse error"
    return 1
  }

  if [[ "$result" != "null" ]]; then
    _assert_pass "$msg"
    return 0
  else
    _assert_fail "$msg" "Key exists but value is null"
    return 1
  fi
}

# Assert HTTP endpoint returns valid JSON with a specific value
# Usage: assert_http_json_value <url> <jq_path> <expected_value> [timeout]
assert_http_json_value() {
  local url="$1"
  local path="$2"
  local expected="$3"
  local timeout="${4:-10}"
  local msg="HTTP JSON ${url} ${path} == '${expected}'"

  local body
  body=$(curl -s --max-time "$timeout" -k "$url" 2>/dev/null) || {
    _assert_fail "$msg" "Connection failed"
    return 1
  }

  assert_json_value "$body" "$path" "$expected"
}

# ---------------------------------------------------------------------------
# Port assertions
# ---------------------------------------------------------------------------

# Assert a TCP port is listening
# Usage: assert_port_listening <port> [host]
assert_port_listening() {
  local port="$1"
  local host="${2:-localhost}"
  local msg="Port ${port} is listening on ${host}"

  if command -v ss &>/dev/null; then
    if ss -tlnp | grep -q ":${port} "; then
      _assert_pass "$msg"
      return 0
    fi
  elif command -v netstat &>/dev/null; then
    if netstat -tlnp 2>/dev/null | grep -q ":${port} "; then
      _assert_pass "$msg"
      return 0
    fi
  fi

  # Fallback: try TCP connection
  if timeout 3 bash -c "echo >/dev/tcp/${host}/${port}" 2>/dev/null; then
    _assert_pass "$msg"
    return 0
  else
    _assert_fail "$msg" "Port not listening"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Log assertions
# ---------------------------------------------------------------------------

# Assert container logs contain a pattern
# Usage: assert_log_contains <container_name> <pattern> [since]
assert_log_contains() {
  local name="$1"
  local pattern="$2"
  local since="${3:-1h}"
  local msg="Logs of '${name}' contain '${pattern}'"

  local logs
  logs=$(docker logs --since "$since" "$name" 2>&1) || {
    _assert_fail "$msg" "Failed to get container logs"
    return 1
  }

  if echo "$logs" | grep -q "$pattern"; then
    _assert_pass "$msg"
    return 0
  else
    _assert_fail "$msg" "Pattern not found in logs"
    return 1
  fi
}

# Assert container logs do NOT contain an error pattern
# Usage: assert_log_no_errors <container_name> [error_pattern] [since]
assert_log_no_errors() {
  local name="$1"
  local pattern="${2:-FATAL\|panic\|CRITICAL}"
  local since="${3:-1h}"
  local msg="No critical errors in '${name}' logs"

  local logs
  logs=$(docker logs --since "$since" "$name" 2>&1) || {
    _assert_fail "$msg" "Failed to get container logs"
    return 1
  }

  if echo "$logs" | grep -qi "$pattern"; then
    local matches
    matches=$(echo "$logs" | grep -ci "$pattern")
    _assert_fail "$msg" "Found ${matches} match(es) for error pattern"
    return 1
  else
    _assert_pass "$msg"
    return 0
  fi
}

# ---------------------------------------------------------------------------
# DNS assertions
# ---------------------------------------------------------------------------

# Assert a hostname resolves (useful for Traefik/AdGuard)
# Usage: assert_dns_resolves <hostname> [server]
assert_dns_resolves() {
  local hostname="$1"
  local server="${2:-}"
  local msg="DNS resolves '${hostname}'"

  local cmd="nslookup ${hostname}"
  [[ -n "$server" ]] && cmd="nslookup ${hostname} ${server}"

  if $cmd &>/dev/null; then
    _assert_pass "$msg"
    return 0
  else
    _assert_fail "$msg" "DNS resolution failed"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Volume / mount assertions
# ---------------------------------------------------------------------------

# Assert a Docker volume exists
# Usage: assert_volume_exists <volume_name>
assert_volume_exists() {
  local name="$1"
  local msg="Docker volume '${name}' exists"

  if docker volume inspect "$name" &>/dev/null; then
    _assert_pass "$msg"
    return 0
  else
    _assert_fail "$msg" "Volume not found"
    return 1
  fi
}

# Assert a directory exists inside a container
# Usage: assert_container_path_exists <container_name> <path>
assert_container_path_exists() {
  local container="$1"
  local path="$2"
  local msg="Path '${path}' exists in container '${container}'"

  if docker exec "$container" test -e "$path" 2>/dev/null; then
    _assert_pass "$msg"
    return 0
  else
    _assert_fail "$msg" "Path not found in container"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Network assertions
# ---------------------------------------------------------------------------

# Assert a Docker network exists
# Usage: assert_network_exists <network_name>
assert_network_exists() {
  local name="$1"
  local msg="Docker network '${name}' exists"

  if docker network inspect "$name" &>/dev/null; then
    _assert_pass "$msg"
    return 0
  else
    _assert_fail "$msg" "Network not found"
    return 1
  fi
}

# Assert a container is connected to a specific network
# Usage: assert_container_in_network <container_name> <network_name>
assert_container_in_network() {
  local container="$1"
  local network="$2"
  local msg="Container '${container}' is in network '${network}'"

  if docker inspect --format='{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}' "$container" 2>/dev/null | grep -q "$network"; then
    _assert_pass "$msg"
    return 0
  else
    _assert_fail "$msg" "Container not connected to network"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Environment / Config assertions
# ---------------------------------------------------------------------------

# Assert an environment variable is set inside a container
# Usage: assert_container_env <container_name> <var_name> [expected_value]
assert_container_env() {
  local container="$1"
  local var="$2"
  local expected="${3:-}"
  local msg="Env '${var}' set in '${container}'"

  local val
  val=$(docker exec "$container" printenv "$var" 2>/dev/null) || {
    _assert_fail "$msg" "Variable not set or container not accessible"
    return 1
  }

  if [[ -n "$expected" ]]; then
    if [[ "$val" == "$expected" ]]; then
      _assert_pass "${msg} == '${expected}'"
      return 0
    else
      _assert_fail "${msg}" "Expected: '${expected}', Got: '${val}'"
      return 1
    fi
  else
    _assert_pass "$msg"
    return 0
  fi
}

# ---------------------------------------------------------------------------
# Equality assertions
# ---------------------------------------------------------------------------

# Assert two values are equal
# Usage: assert_eq <actual> <expected> [message]
assert_eq() {
  local actual="$1"
  local expected="$2"
  local msg="${3:-Values are equal}"

  if [[ "$actual" == "$expected" ]]; then
    _assert_pass "$msg"
    return 0
  else
    _assert_fail "$msg" "Expected: '${expected}', Got: '${actual}'"
    return 1
  fi
}

# Assert a value is not empty
# Usage: assert_not_empty <value> [message]
assert_not_empty() {
  local value="$1"
  local msg="${2:-Value is not empty}"

  if [[ -n "$value" ]]; then
    _assert_pass "$msg"
    return 0
  else
    _assert_fail "$msg" "Value is empty"
    return 1
  fi
}

# Assert a command succeeds (exit code 0)
# Usage: assert_command_succeeds <command...>
assert_command_succeeds() {
  local msg="Command succeeds: $*"

  if "$@" &>/dev/null; then
    _assert_pass "$msg"
    return 0
  else
    _assert_fail "$msg" "Command returned non-zero exit code"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Summary / getters
# ---------------------------------------------------------------------------

get_pass_count() { echo "$_PASS_COUNT"; }
get_fail_count() { echo "$_FAIL_COUNT"; }
get_skip_count() { echo "$_SKIP_COUNT"; }
get_total_count() { echo $(( _PASS_COUNT + _FAIL_COUNT + _SKIP_COUNT )); }

get_test_results() {
  for r in "${_TEST_RESULTS[@]}"; do
    echo "$r"
  done
}

reset_counters() {
  _PASS_COUNT=0
  _FAIL_COUNT=0
  _SKIP_COUNT=0
  _TEST_RESULTS=()
}
