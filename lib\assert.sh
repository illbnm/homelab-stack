#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Assertion Library
# Provides: assert_eq, assert_neq, assert_contains, assert_http_200,
#           assert_http_status, assert_container_running,
#           assert_container_healthy, assert_port_open,
#           assert_json_field, assert_file_exists, assert_env_set
# =============================================================================

# shellcheck shell=bash

# Guard against double-sourcing
[[ -n "${_ASSERT_SH_LOADED:-}" ]] && return 0
_ASSERT_SH_LOADED=1

ASSERT_TIMEOUT="${ASSERT_TIMEOUT:-30}"
ASSERT_RETRY_INTERVAL="${ASSERT_RETRY_INTERVAL:-2}"

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------
_assert_pass() {
  local name="$1"
  # report library will handle actual recording; just signal success
  return 0
}

_assert_fail() {
  local msg="$1"
  echo "ASSERT FAILED: ${msg}" >&2
  return 1
}

# Portable curl wrapper — always returns body, sets _HTTP_STATUS
_curl() {
  local url="$1"
  shift
  local tmp_header
  tmp_header=$(mktemp)
  local body
  body=$(curl \
    --silent \
    --max-time "${ASSERT_TIMEOUT}" \
    --retry 3 \
    --retry-delay 2 \
    --retry-connrefused \
    --dump-header "$tmp_header" \
    "$@" \
    "$url" 2>/dev/null || true)
  _HTTP_STATUS=$(grep -m1 "^HTTP/" "$tmp_header" 2>/dev/null | awk '{print $2}' || echo "000")
  rm -f "$tmp_header"
  echo "$body"
}

# ---------------------------------------------------------------------------
# Basic assertions
# ---------------------------------------------------------------------------

# assert_eq <expected> <actual> [message]
assert_eq() {
  local expected="$1"
  local actual="$2"
  local msg="${3:-expected '${expected}' but got '${actual}'}"
  if [[ "$expected" == "$actual" ]]; then
    return 0
  fi
  _assert_fail "$msg"
}

# assert_neq <unexpected> <actual> [message]
assert_neq() {
  local unexpected="$1"
  local actual="$2"
  local msg="${3:-expected value to differ from '${unexpected}'}"
  if [[ "$unexpected" != "$actual" ]]; then
    return 0
  fi
  _assert_fail "$msg"
}

# assert_contains <haystack> <needle> [message]
assert_contains() {
  local haystack="$1"
  local needle="$2"
  local msg="${3:-expected string to contain '${needle}'}"
  if [[ "$haystack" == *"$needle"* ]]; then
    return 0
  fi
  _assert_fail "$msg"
}

# assert_not_empty <value> [message]
assert_not_empty() {
  local value="$1"
  local msg="${2:-expected non-empty value}"
  if [[ -n "$value" ]]; then
    return 0
  fi
  _assert_fail "$msg"
}

# assert_true <condition_exit_code> [message]
assert_true() {
  local rc="$1"
  local msg="${2:-expected condition to be true}"
  if [[ "$rc" -eq 0 ]]; then
    return 0
  fi
  _assert_fail "$msg"
}

# ---------------------------------------------------------------------------
# HTTP assertions
# ---------------------------------------------------------------------------

# assert_http_status <expected_code> <url> [curl_extra_args...]
assert_http_status() {
  local expected="$1"
  local url="$2"
  shift 2
  local body
  body=$(_curl "$url" "$@")
  if [[ "$_HTTP_STATUS" == "$expected" ]]; then
    return 0
  fi
  _assert_fail "GET ${url} → HTTP ${_HTTP_STATUS} (expected ${expected})"
}

# assert_http_200 <url> [curl_extra_args...]
assert_http_200() {
  local url="$1"
  shift
  assert_http_status "200" "$url" "$@"
}

# assert_http_body_contains <url> <needle> [curl_extra_args...]
assert_http_body_contains() {
  local url="$1"
  local needle="$2"
  shift 2
  local body
  body=$(_curl "$url" "$@")
  if [[ "$body" == *"$needle"* ]]; then
    return 0
  fi
  _assert_fail "GET ${url} body does not contain '${needle}'. Status: ${_HTTP_STATUS}"
}

# assert_http_json_field <url> <jq_filter> <expected_value> [curl_extra_args...]
assert_http_json_field() {
  local url="$1"
  local jq_filter="$2"
  local expected="$3"
  shift 3

  if ! command -v jq &>/dev/null; then
    echo "SKIP: jq not available for JSON assertion on ${url}" >&2
    return 0
  fi

  local body
  body=$(_curl "$url" "$@")
  local actual
  actual=$(echo "$body" | jq -r "$jq_filter" 2>/dev/null || echo "__JQ_ERROR__")

  if [[ "$actual" == "$expected" ]]; then
    return 0
  fi
  _assert_fail "GET ${url} | jq '${jq_filter}' → '${actual}' (expected '${expected}')"
}

# assert_http_redirects <url> [curl_extra_args...]
# Checks that the URL returns a 3xx redirect
assert_http_redirects() {
  local url="$1"
  shift
  local body
  body=$(_curl "$url" "$@")
  if [[ "$_HTTP_STATUS" =~ ^3[0-9][0-9]$ ]]; then
    return 0
  fi
  _assert_fail "GET ${url} → HTTP ${_HTTP_STATUS} (expected 3xx redirect)"
}

# ---------------------------------------------------------------------------
# Container assertions
# ---------------------------------------------------------------------------

# assert_container_running <container_name_or_id>
assert_container_running() {
  local name="$1"
  local state
  state=$(docker inspect --format '{{.State.Running}}' "$name" 2>/dev/null || echo "false")
  if [[ "$state" == "true" ]]; then
    return 0
  fi
  _assert_fail "Container '${name}' is not running (State.Running=${state})"
}

# assert_container_healthy <container_name_or_id>
# Passes if health is 'healthy' OR if no healthcheck is configured (none/starting treated as skip)
assert_container_healthy() {
  local name="$1"
  local health
  health=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$name" 2>/dev/null || echo "unknown")

  case "$health" in
    healthy)
      return 0
      ;;
    none)
      # No healthcheck configured — treat as pass with warning
      echo "WARN: Container '${name}' has no healthcheck configured" >&2
      return 0
      ;;
    starting)
      _assert_fail "Container '${name}' health is still 'starting' (not yet healthy)"
      ;;
    *)
      _assert_fail "Container '${name}' health status: '${health}' (expected 'healthy')"
      ;;
  esac
}

# assert_container_exists <container_name>
assert_container_exists() {
  local name="$1"
  if docker inspect "$name" &>/dev/null; then
    return 0
  fi
  _assert_fail "Container '${name}' does not exist"
}

# assert_container_image <container_name> <expected_image_prefix>
assert_container_image() {
  local name="$1"
  local expected_prefix="$2"
  local image
  image=$(docker inspect --format '{{.Config.Image}}' "$name" 2>/dev/null || echo "")
  if [[ "$image" == ${expected_prefix}* ]]; then
    return 0
  fi
  _assert_fail "Container '${name}' image '${image}' does not start with '${expected_prefix}'"
}

# assert_container_env <container_name> <env_key> <expected_value>
assert_container_env() {
  local name="$1"
  local key="$2"
  local expected="$3"
  local value
  value=$(docker inspect --format "{{range .Config.Env}}{{println .}}{{end}}" "$name" 2>/dev/null \
    | grep "^${key}=" | cut -d= -f2- || echo "")
  if [[ "$value" == "$expected" ]]; then
    return 0
  fi
  _assert_fail "Container '${name}' env ${key}='${value}' (expected '${expected}')"
}

# assert_container_has_label <container_name> <label_key>
assert_container_has_label() {
  local name="$1"
  local label="$2"
  local value
  value=$(docker inspect --format "{{index .Config.Labels \"${label}\"}}" "$name" 2>/dev/null || echo "")
  if [[ -n "$value" ]]; then
    return 0
  fi
  _assert_fail "Container '${name}' is missing label '${label}'"
}

# ---------------------------------------------------------------------------
# Network / port assertions
# ---------------------------------------------------------------------------

# assert_port_open <host> <port> [timeout_sec]
assert_port_open() {
  local host="$1"
  local port="$2"
  local timeout="${3:-${ASSERT_TIMEOUT}}"
  if timeout "$timeout" bash -c "until (echo >/dev/tcp/${host}/${port}) 2>/dev/null; do sleep 1; done" 2>/dev/null; then
    return 0
  fi
  _assert_fail "Port ${port} on ${host} is not open (timeout: ${timeout}s)"
}

# assert_port_closed <host> <port>
assert_port_closed() {
  local host="$1"
  local port="$2"
  if ! (echo >/dev/tcp/"${host}"/"${port}") 2>/dev/null; then
    return 0
  fi
  _assert_fail "Port ${port} on ${host} should be closed but is open"
}

# assert_docker_network_exists <network_name>
assert_docker_network_exists() {
  local network="$1"
  if docker network inspect "$network" &>/dev/null; then
    return 0
  fi
  _assert_fail "Docker network '${network}' does not exist"
}

# assert_container_in_network <container_name> <network_name>
assert_container_in_network() {
  local container="$1"
  local network="$2"
  local networks
  networks=$(docker inspect --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}' "$container" 2>/dev/null || echo "")
  if [[ "$networks" == *"$network"* ]]; then
    return 0
  fi
  _assert_fail "Container '${container}' is not in network '${network}'"
}

# ---------------------------------------------------------------------------
# File / environment assertions
# ---------------------------------------------------------------------------

# assert_file_exists <path>
assert_file_exists() {
  local path="$1"
  if [[ -f "$path" ]]; then
    return 0
  fi
  _assert_fail "File '${path}' does not exist"
}

# assert_dir_exists <path>
assert_dir_exists() {
  local path="$1"
  if [[ -d "$path" ]]; then
    return 0
  fi
  _assert_fail "Directory '${path}' does not exist"
}

# assert_env_set <variable_name>
assert_env_set() {
  local var="$1"
  if [[ -n "${!var:-}" ]]; then
    return 0
  fi
  _assert_fail "Environment variable '${var}' is not set or empty"
}

# assert_env_file_has_key <file> <key>
assert_env_file_has_key() {
  local file="$1"
  local key="$2"
  if grep -qE "^${key}=" "$file" 2>/dev/null; then
    return 0
  fi
  _assert_fail "File '${file}' does not contain key '${key}'"
}

# ---------------------------------------------------------------------------
# Wait helpers (not strict assertions — used for setup)
# ---------------------------------------------------------------------------

# wait_for_http <url> [timeout_sec]
wait_for_http() {
  local url="$1"
  local timeout="${2:-${ASSERT_TIMEOUT}}"
  local elapsed=0
  while [[ $elapsed -lt $timeout ]]; do
    local status
    status=$(curl --silent --max-time 5 --output /dev/null --write-out "%{http_code}" "$url" 2>/dev/null || echo "000")
    if [[ "$status" != "000" ]]; then
      return 0
    fi
    sleep "$ASSERT_RETRY_INTERVAL"
    elapsed=$(( elapsed + ASSERT_RETRY_INTERVAL ))
  done
  echo "WARN: Timed out waiting for ${url}" >&2
  return 1
}

# wait_for_container_healthy <container_name> [timeout_sec]
wait_for_container_healthy() {
  local name="$1"
  local timeout="${2:-${ASSERT_TIMEOUT}}"
  local elapsed=0
  while [[ $elapsed -lt $timeout ]]; do
    local health
    health=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$name" 2>/dev/null || echo "unknown")
    if [[ "$health" == "healthy" || "$health" == "none" ]]; then
      return 0
    fi
    sleep "$ASSERT_RETRY_INTERVAL"
    elapsed=$(( elapsed + ASSERT_RETRY_INTERVAL ))
  done
  echo "WARN: Container '${name}' did not become healthy within ${timeout}s" >&2
  return 1
}
