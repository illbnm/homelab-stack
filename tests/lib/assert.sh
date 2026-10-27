#!/usr/bin/env bash
set -euo pipefail

assert_eq() {
  local actual="${1:-}" expected="${2:-}" msg="${3:-Expected values to match}"
  [[ "$actual" == "$expected" ]] || { echo "$msg: expected '$expected', got '$actual'" >&2; return 1; }
}

assert_not_empty() {
  local value="${1:-}" msg="${2:-Expected value to be non-empty}"
  [[ -n "$value" ]] || { echo "$msg" >&2; return 1; }
}

assert_exit_code() {
  local code="${1:-1}" msg="${2:-Unexpected exit code}"
  [[ "$code" -eq 0 ]] || { echo "$msg: $code" >&2; return 1; }
}

assert_container_running() {
  local name="$1"
  docker ps --format '{{.Names}}' | grep -Fxq "$name" || { echo "Container not running: $name" >&2; return 1; }
}

assert_container_healthy() {
  local name="$1" timeout="${2:-60}" waited=0 status
  assert_container_running "$name" || return 1
  while (( waited < timeout )); do
    status="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' "$name" 2>/dev/null || echo unknown)"
    [[ "$status" == "healthy" || "$status" == "no-healthcheck" ]] && return 0
    sleep 2
    waited=$((waited + 2))
  done
  echo "Container unhealthy: $name ($status)" >&2
  return 1
}

assert_http_200() {
  local url="$1" timeout="${2:-30}" code
  code="$(curl -fsS -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time "$timeout" "$url" 2>/dev/null || echo 000)"
  [[ "$code" == "200" ]] || { echo "Expected HTTP 200 from $url, got $code" >&2; return 1; }
}

assert_http_response() {
  local url="$1" pattern="$2" body
  body="$(curl -fsS --connect-timeout 5 --max-time 30 "$url")" || { echo "Failed to fetch $url" >&2; return 1; }
  grep -Eq "$pattern" <<<"$body" || { echo "Pattern not found in $url: $pattern" >&2; return 1; }
}

assert_json_value() {
  local json="$1" jq_path="$2" expected="$3"
  local actual
  actual="$(jq -r "$jq_path // empty" <<<"$json")"
  [[ "$actual" == "$expected" ]] || { echo "Expected JSON $jq_path=$expected, got ${actual:-<empty>}" >&2; return 1; }
}

assert_json_key_exists() {
  local json="$1" jq_path="$2"
  local value
  value="$(jq -r "$jq_path // empty" <<<"$json")"
  [[ -n "$value" && "$value" != "null" ]] || { echo "Missing JSON key: $jq_path" >&2; return 1; }
}

assert_no_errors() {
  local json="$1" errors
  errors="$(jq -r '.errors // empty' <<<"$json")"
  [[ -z "$errors" || "$errors" == "null" || "$errors" == "[]" ]] || { echo "JSON contains errors: $errors" >&2; return 1; }
}

assert_file_contains() {
  local file="$1" pattern="$2"
  grep -Eq "$pattern" "$file" || { echo "Pattern not found in $file: $pattern" >&2; return 1; }
}

assert_no_latest_images() {
  local dir="$1" count
  count="$(grep -RhoE 'image:[[:space:]]*[^[:space:]]+:latest' "$dir" 2>/dev/null | wc -l | tr -d ' ')"
  [[ "$count" == "0" ]] || { echo "Found latest image tags under $dir" >&2; return 1; }
}
