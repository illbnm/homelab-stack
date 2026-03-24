#!/usr/bin/env bash
# =============================================================================
# Assert Library — Test assertions for HomeLab integration tests
# =============================================================================

PASSED=${PASSED:-0}
FAILED=${FAILED:-0}
SKIPPED=${SKIPPED:-0}
TEST_NAME=""

test_start() {
  TEST_NAME="$1"
  printf "  %-40s " "$TEST_NAME"
}

test_pass() {
  echo -e "${GREEN}✅ PASS${NC} (${1:-0.0}s)"
  ((PASSED++))
}

test_fail() {
  echo -e "${RED}❌ FAIL${NC} — $1"
  ((FAILED++))
}

test_skip() {
  echo -e "${YELLOW}⏭️  SKIP${NC} — $1"
  ((SKIPPED++))
}

assert_eq() {
  local actual="$1" expected="$2" msg="${3:-}"
  if [[ "$actual" == "$expected" ]]; then
    return 0
  else
    test_fail "${msg:-Expected '$expected', got '$actual'}"
    return 1
  fi
}

assert_not_empty() {
  local value="$1" msg="${2:-}"
  if [[ -n "$value" ]]; then
    return 0
  else
    test_fail "${msg:-Value is empty}"
    return 1
  fi
}

assert_exit_code() {
  local expected="$1" msg="${2:-}"
  local actual=$?
  if [[ "$actual" -eq "$expected" ]]; then
    return 0
  else
    test_fail "${msg:-Expected exit code $expected, got $actual}"
    return 1
  fi
}

assert_container_running() {
  local name="$1"
  test_start "Container $name running"
  local start=$SECONDS
  if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${name}$"; then
    test_pass "$((SECONDS - start))"
    return 0
  else
    test_fail "Container $name not running"
    return 1
  fi
}

assert_container_healthy() {
  local name="$1" timeout="${2:-60}"
  test_start "Container $name healthy"
  local start=$SECONDS
  local elapsed=0
  while [[ $elapsed -lt $timeout ]]; do
    local health
    health=$(docker inspect --format '{{.State.Health.Status}}' "$name" 2>/dev/null || echo "missing")
    if [[ "$health" == "healthy" ]]; then
      test_pass "$((SECONDS - start))"
      return 0
    fi
    sleep 2
    elapsed=$((SECONDS - start))
  done
  test_fail "Container $name not healthy after ${timeout}s (status: ${health:-missing})"
  return 1
}

assert_http_200() {
  local url="$1" timeout="${2:-30}"
  test_start "HTTP 200 $url"
  local start=$SECONDS
  local code
  code=$(curl -sf -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time "$timeout" "$url" 2>/dev/null || echo "000")
  if [[ "$code" =~ ^2 ]]; then
    test_pass "$((SECONDS - start))"
    return 0
  else
    test_fail "HTTP $code (expected 2xx)"
    return 1
  fi
}

assert_http_response() {
  local url="$1" pattern="$2"
  test_start "Response matches: $pattern"
  local start=$SECONDS
  local body
  body=$(curl -sf --connect-timeout 5 --max-time 10 "$url" 2>/dev/null || echo "")
  if echo "$body" | grep -q "$pattern"; then
    test_pass "$((SECONDS - start))"
    return 0
  else
    test_fail "Response does not match '$pattern'"
    return 1
  fi
}

assert_json_value() {
  local json="$1" jq_path="$2" expected="$3"
  test_start "JSON $jq_path == $expected"
  local actual
  actual=$(echo "$json" | jq -r "$jq_path" 2>/dev/null || echo "")
  assert_eq "$actual" "$expected"
}

assert_json_key_exists() {
  local json="$1" jq_path="$2"
  test_start "JSON key exists: $jq_path"
  local val
  val=$(echo "$json" | jq -e "$jq_path" 2>/dev/null)
  local rc=$?
  if [[ $rc -eq 0 ]] && [[ "$val" != "null" ]]; then
    test_pass
    return 0
  else
    test_fail "JSON key '$jq_path' missing or null"
    return 1
  fi
}

assert_file_contains() {
  local file="$1" pattern="$2"
  test_start "File contains: $pattern"
  if grep -q "$pattern" "$file" 2>/dev/null; then
    test_pass
    return 0
  else
    test_fail "File $file does not contain '$pattern'"
    return 1
  fi
}
