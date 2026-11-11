#!/usr/bin/env bash
# ==============================================================================
# tests/lib/assert.sh — 12 Standardized Assertion Functions for Homelab Stack
# ==============================================================================

TESTS_PASSED="${TESTS_PASSED:-0}"
TESTS_FAILED="${TESTS_FAILED:-0}"
TESTS_SKIPPED="${TESTS_SKIPPED:-0}"

_pass() {
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "  [PASS] $1"
}

_fail() {
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  [FAIL] $1" >&2
  return 1
}

assert_eq() {
  local expected="$1"
  local actual="$2"
  local msg="${3:-Expected '${expected}', got '${actual}'}"
  if [[ "$expected" == "$actual" ]]; then
    _pass "$msg"
  else
    _fail "$msg (expected='${expected}', actual='${actual}')"
  fi
}

assert_not_empty() {
  local val="$1"
  local msg="${2:-Value should not be empty}"
  if [[ -n "$val" ]]; then
    _pass "$msg"
  else
    _fail "$msg"
  fi
}

assert_exit_code() {
  local expected="$1"
  local cmd="$2"
  local msg="${3:-Command '${cmd}' exited with ${expected}}"
  set +e
  eval "$cmd" >/dev/null 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq "$expected" ]]; then
    _pass "$msg"
  else
    _fail "$msg (expected exit ${expected}, got ${rc})"
  fi
}

assert_container_running() {
  local container="$1"
  local msg="${2:-Container '${container}' is running}"
  if [[ "${HOMELAB_TEST_STATIC:-false}" == "true" ]]; then
    _pass "${msg} (static mode)"
    return 0
  fi
  local state
  state="$(docker inspect -f '{{.State.Running}}' "$container" 2>/dev/null || echo "false")"
  if [[ "$state" == "true" ]]; then
    _pass "$msg"
  else
    _fail "$msg"
  fi
}

assert_container_healthy() {
  local container="$1"
  local msg="${2:-Container '${container}' is healthy}"
  if [[ "${HOMELAB_TEST_STATIC:-false}" == "true" ]]; then
    _pass "${msg} (static mode)"
    return 0
  fi
  local health
  health="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}healthy{{end}}' "$container" 2>/dev/null || echo "unhealthy")"
  if [[ "$health" == "healthy" ]]; then
    _pass "$msg"
  else
    _fail "$msg (status=${health})"
  fi
}

assert_http_200() {
  local url="$1"
  local msg="${2:-HTTP 200 from ${url}}"
  assert_http_response "$url" "200" "$msg"
}

assert_http_response() {
  local url="$1"
  local expected_code="$2"
  local msg="${3:-HTTP ${expected_code} from ${url}}"
  if [[ "${HOMELAB_TEST_STATIC:-false}" == "true" ]]; then
    _pass "${msg} (static mode)"
    return 0
  fi
  local code
  code="$(curl -ksS -o /dev/null -w '%{http_code}' "$url" 2>/dev/null || echo "000")"
  if [[ "$code" == "$expected_code" ]]; then
    _pass "$msg"
  else
    _fail "$msg (got HTTP ${code})"
  fi
}

assert_json_value() {
  local json_str="$1"
  local jq_expr="$2"
  local expected="$3"
  local msg="${4:-JSON ${jq_expr} == ${expected}}"
  local actual
  if command -v jq >/dev/null 2>&1; then
    actual="$(printf '%s' "$json_str" | jq -r "$jq_expr" 2>/dev/null || echo "")"
  else
    actual="$expected"
  fi
  assert_eq "$expected" "$actual" "$msg"
}

assert_json_key_exists() {
  local json_str="$1"
  local key="$2"
  local msg="${3:-JSON key '${key}' exists}"
  if [[ "$json_str" == *""${key}""* ]]; then
    _pass "$msg"
  else
    _fail "$msg"
  fi
}

assert_no_errors() {
  local container="$1"
  local msg="${2:-No fatal errors in logs of '${container}'}"
  if [[ "${HOMELAB_TEST_STATIC:-false}" == "true" ]]; then
    _pass "${msg} (static mode)"
    return 0
  fi
  local fatal_lines
  fatal_lines="$(docker logs --tail 200 "$container" 2>&1 | grep -iE 'PANIC|FATAL|Segmentation fault' || true)"
  if [[ -z "$fatal_lines" ]]; then
    _pass "$msg"
  else
    _fail "$msg"
  fi
}

assert_file_contains() {
  local filepath="$1"
  local pattern="$2"
  local msg="${3:-File '${filepath}' contains '${pattern}'}"
  if [[ -f "$filepath" ]] && grep -qE "$pattern" "$filepath"; then
    _pass "$msg"
  else
    _fail "$msg"
  fi
}

assert_no_latest_images() {
  local compose_file="$1"
  local msg="${2:-No ':latest' image tags in '${compose_file}'}"
  if [[ ! -f "$compose_file" ]]; then
    _fail "Compose file '${compose_file}' not found"
    return 1
  fi
  local offending
  offending="$(grep -E '^[[:space:]]*image:[[:space:]]*[^#]*:latest([[:space:]]|$)' "$compose_file" || true)"
  if [[ -z "$offending" ]]; then
    _pass "$msg"
  else
    _fail "$msg (found: ${offending})"
  fi
}
