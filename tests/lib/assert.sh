#!/usr/bin/env bash
# =============================================================================
# tests/lib/assert.sh — 断言库
# 提供所有标准断言方法
# =============================================================================

# Internal state
ASSERT_LAST_MSG=""
ASSERT_LAST_PASSED=true

# ---- Core assertion helpers ----

assert_eq() {
  local actual="$1" expected="$2" msg="${3:-}"
  if [[ "$actual" == "$expected" ]]; then
    ASSERT_LAST_PASSED=true
    return 0
  else
    ASSERT_LAST_PASSED=false
    echo "Expected: '$expected', Got: '$actual' ${msg:+— $msg}"
    return 1
  fi
}

assert_not_eq() {
  local actual="$1" unexpected="$2" msg="${3:-}"
  if [[ "$actual" != "$unexpected" ]]; then
    ASSERT_LAST_PASSED=true
    return 0
  else
    ASSERT_LAST_PASSED=false
    echo "Value '$actual' should not equal '$unexpected' ${msg:+— $msg}"
    return 1
  fi
}

assert_not_empty() {
  local value="$1" msg="${2:-}"
  if [[ -n "$value" ]]; then
    ASSERT_LAST_PASSED=true
    return 0
  else
    ASSERT_LAST_PASSED=false
    echo "Value must not be empty ${msg:+— $msg}"
    return 1
  fi
}

assert_exit_code() {
  local expected_code="$1" actual_code="$2" msg="${3:-}"
  if [[ "$actual_code" == "$expected_code" ]]; then
    ASSERT_LAST_PASSED=true
    return 0
  else
    ASSERT_LAST_PASSED=false
    echo "Expected exit code $expected_code, got $actual_code ${msg:+— $msg}"
    return 1
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" msg="${3:-}"
  if [[ "$haystack" == *"$needle"* ]]; then
    ASSERT_LAST_PASSED=true
    return 0
  else
    ASSERT_LAST_PASSED=false
    echo "String does not contain '$needle' ${msg:+— $msg}"
    return 1
  fi
}

assert_file_exists() {
  local file="$1" msg="${2:-}"
  if [[ -f "$file" ]]; then
    ASSERT_LAST_PASSED=true
    return 0
  else
    ASSERT_LAST_PASSED=false
    echo "File does not exist: $file ${msg:+— $msg}"
    return 1
  fi
}

assert_file_contains() {
  local file="$1" pattern="$2" msg="${3:-}"
  if [[ -f "$file" ]] && grep -q "$pattern" "$file" 2>/dev/null; then
    ASSERT_LAST_PASSED=true
    return 0
  else
    ASSERT_LAST_PASSED=false
    echo "File does not contain '$pattern': $file ${msg:+— $msg}"
    return 1
  fi
}

# ---- Docker/container assertions ----

assert_container_running() {
  local name="$1" msg="${2:-}"
  if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${name}$"; then
    ASSERT_LAST_PASSED=true
    return 0
  else
    ASSERT_LAST_PASSED=false
    echo "Container not running: $name ${msg:+— $msg}"
    return 1
  fi
}

assert_container_healthy() {
  local name="$1" timeout="${2:-60}" msg="${3:-}"

  # Wait up to timeout seconds
  local waited=0 interval=5
  while [[ $waited -lt $timeout ]]; do
    local status
    status=$(docker inspect --format '{{.State.Health.Status}}' "$name" 2>/dev/null || echo 'unknown')
    case "$status" in
      healthy)
        ASSERT_LAST_PASSED=true
        return 0
        ;;
      unhealthy)
        ASSERT_LAST_PASSED=false
        echo "Container unhealthy: $name ${msg:+— $msg}"
        return 1
        ;;
      no-healthcheck|"")
        # No healthcheck defined — check if running
        if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${name}$"; then
          ASSERT_LAST_PASSED=true
          return 0
        fi
        ;;
    esac
    sleep $interval
    waited=$((waited + interval))
  done

  ASSERT_LAST_PASSED=false
  echo "Container did not become healthy within ${timeout}s: $name ${msg:+— $msg}"
  return 1
}

assert_container_stopped() {
  local name="$1" msg="${2:-}"
  if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${name}$"; then
    ASSERT_LAST_PASSED=true
    return 0
  else
    ASSERT_LAST_PASSED=false
    echo "Container should be stopped: $name ${msg:+— $msg}"
    return 1
  fi
}

# ---- HTTP assertions ----

assert_http_200() {
  local url="$1" timeout="${2:-30}" msg="${3:-}"
  local code
  code=$(curl -sf --connect-timeout 5 --max-time "$timeout" \
    -o /dev/null -w '%{http_code}' "$url" 2>/dev/null || echo "000")

  if [[ "$code" =~ ^[23] ]]; then
    ASSERT_LAST_PASSED=true
    return 0
  else
    ASSERT_LAST_PASSED=false
    echo "Expected HTTP 2xx/3xx, got $code for $url ${msg:+— $msg}"
    return 1
  fi
}

assert_http_response() {
  local url="$1" pattern="$2" timeout="${3:-30}" msg="${4:-}"
  local body
  body=$(curl -sf --connect-timeout 5 --max-time "$timeout" "$url" 2>/dev/null || echo "")

  if echo "$body" | grep -q "$pattern"; then
    ASSERT_LAST_PASSED=true
    return 0
  else
    ASSERT_LAST_PASSED=false
    echo "Response from $url does not contain '$pattern' ${msg:+— $msg}"
    return 1
  fi
}

assert_http_status() {
  local url="$1" expected="$2" timeout="${3:-30}" msg="${4:-}"
  local code
  code=$(curl -sf --connect-timeout 5 --max-time "$timeout" \
    -o /dev/null -w '%{http_code}' "$url" 2>/dev/null || echo "000")

  if [[ "$code" == "$expected" ]]; then
    ASSERT_LAST_PASSED=true
    return 0
  else
    ASSERT_LAST_PASSED=false
    echo "Expected HTTP $expected, got $code for $url ${msg:+— $msg}"
    return 1
  fi
}

# ---- JSON assertions ----

assert_json_value() {
  local json="$1" jq_path="$2" expected="$3" msg="${4:-}"
  local actual
  actual=$(echo "$json" | python3 -c "import sys,json; d=json.load(sys.stdin); path='$jq_path'; print(d${jq_path#\.})" 2>/dev/null || echo "__NOT_FOUND__")

  if [[ "$actual" == "$expected" ]]; then
    ASSERT_LAST_PASSED=true
    return 0
  else
    ASSERT_LAST_PASSED=false
    echo "JSON path $jq_path: expected '$expected', got '$actual' ${msg:+— $msg}"
    return 1
  fi
}

assert_json_key_exists() {
  local json="$1" jq_path="$2" msg="${3:-}"
  local value
  value=$(echo "$json" | python3 -c "import sys,json; d=json.load(sys.stdin); path='$jq_path'; print(d${jq_path#\.})" 2>/dev/null || echo "__NOT_FOUND__")

  if [[ "$value" != "__NOT_FOUND__" && -n "$value" && "$value" != "null" ]]; then
    ASSERT_LAST_PASSED=true
    return 0
  else
    ASSERT_LAST_PASSED=false
    echo "JSON key $jq_path does not exist or is empty ${msg:+— $msg}"
    return 1
  fi
}

assert_no_errors() {
  local json="$1" msg="${2:-}"
  local errors
  errors=$(echo "$json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('errors',''))" 2>/dev/null || echo "PARSE_ERROR")

  if [[ "$errors" == "PARSE_ERROR" ]]; then
    ASSERT_LAST_PASSED=false
    echo "Failed to parse JSON response ${msg:+— $msg}"
    return 1
  fi

  if [[ -z "$errors" ]]; then
    ASSERT_LAST_PASSED=true
    return 0
  else
    ASSERT_LAST_PASSED=false
    echo "Response contains errors: $errors ${msg:+— $msg}"
    return 1
  fi
}

# ---- Image / compose assertions ----

assert_no_latest_images() {
  local dir="$1" msg="${2:-}"
  local count
  count=$(grep -rE '^\s+image:\s*[^:]+\s*$' "$dir" --include='docker-compose*.yml' 2>/dev/null | wc -l || echo 0)

  if [[ "$count" -eq 0 ]]; then
    ASSERT_LAST_PASSED=true
    return 0
  else
    ASSERT_LAST_PASSED=false
    echo "Found $count images without version tag (no :tag) ${msg:+— $msg}"
    grep -rE '^\s+image:\s*[^:]+\s*$' "$dir" --include='docker-compose*.yml' 2>/dev/null | head -5
    return 1
  fi
}

assert_image_tag_healthy() {
  local img="$1"
  # Check image has a tag (not latest or empty)
  if [[ "$img" =~ :[a-zA-Z0-9_.-]+$ ]]; then
    ASSERT_LAST_PASSED=true
    return 0
  else
    ASSERT_LAST_PASSED=false
    echo "Image has no valid tag: $img"
    return 1
  fi
}

assert_compose_valid() {
  local compose_file="$1" msg="${2:-}"
  if docker compose -f "$compose_file" config --quiet 2>/dev/null; then
    ASSERT_LAST_PASSED=true
    return 0
  else
    ASSERT_LAST_PASSED=false
    echo "docker-compose config failed: $compose_file ${msg:+— $msg}"
    docker compose -f "$compose_file" config 2>&1 | head -3
    return 1
  fi
}

assert_env_var_set() {
  local var_name="$1" msg="${2:-}"
  if [[ -n "${!var_name:-}" ]]; then
    ASSERT_LAST_PASSED=true
    return 0
  else
    ASSERT_LAST_PASSED=false
    echo "Environment variable not set: $var_name ${msg:+— $msg}"
    return 1
  fi
}
