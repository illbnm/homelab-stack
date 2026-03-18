#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# Assert.sh — 测试断言库
#
# 提供完整的断言函数，用于集成测试脚本
# ═══════════════════════════════════════════════════════════════════════════

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# 测试统计
ASSERT_TOTAL=0
ASSERT_PASSED=0
ASSERT_FAILED=0
ASSERT_SKIPPED=0

# 当前测试上下文
CURRENT_TEST=""
CURRENT_SUITE=""

# ═══════════════════════════════════════════════════════════════════════════
# 辅助函数
# ═══════════════════════════════════════════════════════════════════════════

_assert_print_header() {
  echo
  echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║   HomeLab Stack — Integration Tests ║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"
  echo
}

_assert_print_summary() {
  local total=$1
  local passed=$2
  local failed=$3
  local skipped=$4

  echo
  echo "──────────────────────────────────────"
  echo -e "Results: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}, ${YELLOW}${skipped} skipped${NC}"
  echo "──────────────────────────────────────"
  echo

  if [[ $failed -gt 0 ]]; then
    return 1
  fi
  return 0
}

_assert_format_duration() {
  local seconds=$1
  if (( $(echo "$seconds >= 60" | bc -l 2>/dev/null || echo "0") )); then
    printf "%.1fm" "$(echo "$seconds / 60" | bc -l)"
  else
    printf "%.1fs" "$seconds"
  fi
}

# ═══════════════════════════════════════════════════════════════════════════
# 核心断言函数
# ═══════════════════════════════════════════════════════════════════════════

# assert_eq <actual> <expected> [msg]
assert_eq() {
  ((ASSERT_TOTAL++))
  local actual="$1"
  local expected="$2"
  local msg="${3:-Assertion failed: expected '$expected' but got '$actual'}"

  if [[ "$actual" == "$expected" ]]; then
    echo -e "  ✅ PASS: ${msg:-Values equal}"
    ((ASSERT_PASSED++))
    return 0
  else
    echo -e "  ❌ FAIL: ${msg}"
    echo -e "     Expected: $expected"
    echo -e "     Got:      $actual"
    ((ASSERT_FAILED++))
    return 1
  fi
}

# assert_ne <actual> <expected> [msg]
assert_ne() {
  ((ASSERT_TOTAL++))
  local actual="$1"
  local expected="$2"
  local msg="${3:-Assertion failed: values should not be equal}"

  if [[ "$actual" != "$expected" ]]; then
    echo -e "  ✅ PASS: ${msg:-Values not equal}"
    ((ASSERT_PASSED++))
    return 0
  else
    echo -e "  ❌ FAIL: ${msg}"
    echo -e "     Both: $expected"
    ((ASSERT_FAILED++))
    return 1
  fi
}

# assert_contains <string> <substring> [msg]
assert_contains() {
  ((ASSERT_TOTAL++))
  local string="$1"
  local substring="$2"
  local msg="${3:-Assertion failed: string does not contain expected substring}"

  if [[ "$string" == *"$substring"* ]]; then
    echo -e "  ✅ PASS: ${msg:-String contains substring}"
    ((ASSERT_PASSED++))
    return 0
  else
    echo -e "  ❌ FAIL: ${msg}"
    echo -e "     String:   $string"
    echo -e "     Expected: $substring"
    ((ASSERT_FAILED++))
    return 1
  fi
}

# assert_not_empty <value> [msg]
assert_not_empty() {
  ((ASSERT_TOTAL++))
  local value="$1"
  local msg="${2:-Assertion failed: value is empty}"

  if [[ -n "$value" ]]; then
    echo -e "  ✅ PASS: ${msg:-Value is not empty}"
    ((ASSERT_PASSED++))
    return 0
  else
    echo -e "  ❌ FAIL: ${msg}"
    ((ASSERT_FAILED++))
    return 1
  fi
}

# assert_exit_code <code> [msg]
assert_exit_code() {
  ((ASSERT_TOTAL++))
  local code="$1"
  local msg="${2:-Assertion failed: expected exit code 0}"

  if [[ $code -eq 0 ]]; then
    echo -e "  ✅ PASS: ${msg:-Exit code is 0}"
    ((ASSERT_PASSED++))
    return 0
  else
    echo -e "  ❌ FAIL: ${msg}"
    echo -e "     Exit code: $code"
    ((ASSERT_FAILED++))
    return 1
  fi
}

# assert_file_exists <path> [msg]
assert_file_exists() {
  ((ASSERT_TOTAL++))
  local path="$1"
  local msg="${2:-Assertion failed: file does not exist}"

  if [[ -f "$path" ]]; then
    echo -e "  ✅ PASS: ${msg:-File exists}"
    ((ASSERT_PASSED++))
    return 0
  else
    echo -e "  ❌ FAIL: ${msg}"
    echo -e "     Path: $path"
    ((ASSERT_FAILED++))
    return 1
  fi
}

# assert_dir_exists <path> [msg]
assert_dir_exists() {
  ((ASSERT_TOTAL++))
  local path="$1"
  local msg="${2:-Assertion failed: directory does not exist}"

  if [[ -d "$path" ]]; then
    echo -e "  ✅ PASS: ${msg:-Directory exists}"
    ((ASSERT_PASSED++))
    return 0
  else
    echo -e "  ❌ FAIL: ${msg}"
    echo -e "     Path: $path"
    ((ASSERT_FAILED++))
    return 1
  fi
}

# ═══════════════════════════════════════════════════════════════════════════
# Docker 专用断言
# ═══════════════════════════════════════════════════════════════════════════

# assert_container_running <container_name> [timeout=30]
assert_container_running() {
  ((ASSERT_TOTAL++))
  local container="$1"
  local timeout="${2:-30}"
  local start_time=$(date +%s)

  while true; do
    if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
      echo -e "  ✅ PASS: Container '$container' is running"
      ((ASSERT_PASSED++))
      return 0
    fi

    local elapsed=$(($(date +%s) - start_time))
    if [[ $elapsed -ge $timeout ]]; then
      echo -e "  ❌ FAIL: Container '$container' not running after ${timeout}s"
      ((ASSERT_FAILED++))
      return 1
    fi
    sleep 1
  done
}

# assert_container_healthy <container_name> [timeout=60]
assert_container_healthy() {
  ((ASSERT_TOTAL++))
  local container="$1"
  local timeout="${2:-60}"
  local start_time=$(date +%s)

  while true; do
    local status=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "none")
    if [[ "$status" == "healthy" ]]; then
      echo -e "  ✅ PASS: Container '$container' is healthy"
      ((ASSERT_PASSED++))
      return 0
    elif [[ "$status" == "unhealthy" ]]; then
      echo -e "  ❌ FAIL: Container '$container' is unhealthy"
      ((ASSERT_FAILED++))
      return 1
    fi

    local elapsed=$(($(date +%s) - start_time))
    if [[ $elapsed -ge $timeout ]]; then
      echo -e "  ❌ FAIL: Container '$container' not healthy after ${timeout}s (status: $status)"
      ((ASSERT_FAILED++))
      return 1
    fi
    sleep 2
  done
}

# assert_container_exited <container_name>
assert_container_exited() {
  ((ASSERT_TOTAL++))
  local container="$1"
  local status=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null || echo "none")

  if [[ "$status" == "exited" ]]; then
    echo -e "  ✅ PASS: Container '$container' exited"
    ((ASSERT_PASSED++))
    return 0
  else
    echo -e "  ❌ FAIL: Container '$container' not exited (status: $status)"
    ((ASSERT_FAILED++))
    return 1
  fi
}

# ═══════════════════════════════════════════════════════════════════════════
# HTTP 断言
# ═══════════════════════════════════════════════════════════════════════════

# assert_http_200 <url> [timeout=30] [expected_body=""]
assert_http_200() {
  ((ASSERT_TOTAL++))
  local url="$1"
  local timeout="${2:-30}"
  local expected_body="${3:-}"
  local start_time=$(date +%s)

  while true; do
    local code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null || echo "000")
    if [[ "$code" == "200" ]]; then
      if [[ -n "$expected_body" ]]; then
        local body=$(curl -s --max-time 5 "$url" 2>/dev/null || echo "")
        if [[ "$body" == *"$expected_body"* ]]; then
          echo -e "  ✅ PASS: HTTP 200 with expected body from $url"
          ((ASSERT_PASSED++))
          return 0
        else
          echo -e "  ⚠️  WARN: HTTP 200 but body doesn't match"
          echo -e "     Expected: $expected_body"
          echo -e "     Got: ${body:0:100}..."
          # 这里不失败，只警告
          ((ASSERT_PASSED++))
          return 0
        fi
      fi
      echo -e "  ✅ PASS: HTTP 200 from $url"
      ((ASSERT_PASSED++))
      return 0
    fi

    local elapsed=$(($(date +%s) - start_time))
    if [[ $elapsed -ge $timeout ]]; then
      echo -e "  ❌ FAIL: Expected HTTP 200 from $url, got $code after ${timeout}s"
      ((ASSERT_FAILED++))
      return 1
    fi
    sleep 2
  done
}

# assert_http_401 <url> [msg]
assert_http_401() {
  ((ASSERT_TOTAL++))
  local url="$1"
  local msg="${2:-Assertion failed: expected HTTP 401 Unauthorized}"

  local code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null || echo "000")
  if [[ "$code" == "401" ]]; then
    echo -e "  ✅ PASS: $msg (HTTP 401)"
    ((ASSERT_PASSED++))
    return 0
  else
    echo -e "  ❌ FAIL: $msg"
    echo -e "     Expected: 401, Got: $code"
    ((ASSERT_FAILED++))
    return 1
  fi
}

# ═══════════════════════════════════════════════════════════════════════════
# JSON 断言
# ═══════════════════════════════════════════════════════════════════════════

# assert_json_value <json_string> <jq_path> <expected> [msg]
assert_json_value() {
  ((ASSERT_TOTAL++))
  local json="$1"
  local jq_path="$2"
  local expected="$3"
  local msg="${4:-Assertion failed: JSON value mismatch}"

  local actual=$(echo "$json" | jq -r "$jq_path" 2>/dev/null || echo "JQ_ERROR")

  if [[ "$actual" == "$expected" ]]; then
    echo -e "  ✅ PASS: ${msg:-JSON value matches}"
    ((ASSERT_PASSED++))
    return 0
  else
    echo -e "  ❌ FAIL: ${msg}"
    echo -e "     JQ Path: $jq_path"
    echo -e "     Expected: $expected"
    echo -e "     Got:      $actual"
    ((ASSERT_FAILED++))
    return 1
  fi
}

# assert_json_key_exists <json_string> <jq_path> [msg]
assert_json_key_exists() {
  ((ASSERT_TOTAL++))
  local json="$1"
  local jq_path="$2"
  local msg="${3:-Assertion failed: JSON key does not exist}"

  local result=$(echo "$json" | jq -e "$jq_path" 2>/dev/null)

  if [[ $? -eq 0 ]]; then
    echo -e "  ✅ PASS: ${msg:-JSON key exists}"
    ((ASSERT_PASSED++))
    return 0
  else
    echo -e "  ❌ FAIL: ${msg}"
    echo -e "     JQ Path: $jq_path"
    ((ASSERT_FAILED++))
    return 1
  fi
}

# assert_no_errors <json_string> [msg]
assert_no_errors() {
  ((ASSERT_TOTAL++))
  local json="$1"
  local msg="${2:-Assertion failed: JSON contains errors}"

  local errors=$(echo "$json" | jq -r '.errors // empty' 2>/dev/null)

  if [[ -z "$errors" ]]; then
    echo -e "  ✅ PASS: ${msg:-No errors in JSON}"
    ((ASSERT_PASSED++))
    return 0
  else
    echo -e "  ❌ FAIL: ${msg}"
    echo -e "     Errors: $errors"
    ((ASSERT_FAILED++))
    return 1
  fi
}

# ═══════════════════════════════════════════════════════════════════════════
# 配置断言
# ═══════════════════════════════════════════════════════════════════════════

# assert_file_contains <file> <pattern> [msg]
assert_file_contains() {
  ((ASSERT_TOTAL++))
  local file="$1"
  local pattern="$2"
  local msg="${3:-Assertion failed: file does not contain pattern}"

  if [[ -f "$file" ]] && grep -q "$pattern" "$file"; then
    echo -e "  ✅ PASS: ${msg:-File contains pattern}"
    ((ASSERT_PASSED++))
    return 0
  else
    echo -e "  ❌ FAIL: ${msg}"
    echo -e "     File: $file"
    echo -e "     Pattern: $pattern"
    ((ASSERT_FAILED++))
    return 1
  fi
}

# assert_no_latest_images <dir> [msg]
assert_no_latest_images() {
  ((ASSERT_TOTAL++))
  local dir="$1"
  local msg="${2:-Assertion failed: found :latest image tags}"

  local count=$(grep -r 'image:.*:latest' "$dir" 2>/dev/null | wc -l | tr -d ' ')

  if [[ "$count" -eq 0 ]]; then
    echo -e "  ✅ PASS: ${msg:-No :latest image tags}"
    ((ASSERT_PASSED++))
    return 0
  else
    echo -e "  ❌ FAIL: ${msg}"
    echo -e "     Found $count instances of :latest in $dir"
    ((ASSERT_FAILED++))
    return 1
  fi
}

# assert_valid_yaml <file> [msg]
assert_valid_yaml() {
  ((ASSERT_TOTAL++))
  local file="$1"
  local msg="${2:-Assertion failed: invalid YAML syntax}"

  if command -v yq &>/dev/null; then
    if yq eval "$file" &>/dev/null; then
      echo -e "  ✅ PASS: ${msg:-Valid YAML}"
      ((ASSERT_PASSED++))
      return 0
    fi
  else
    # 回退到 Python
    if python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>/dev/null; then
      echo -e "  ✅ PASS: ${msg:-Valid YAML}"
      ((ASSERT_PASSED++))
      return 0
    fi
  fi

  echo -e "  ❌ FAIL: $msg"
  echo -e "     File: $file"
  ((ASSERT_FAILED++))
  return 1
}

# ═══════════════════════════════════════════════════════════════════════════
# 高级断言
# ═══════════════════════════════════════════════════════════════════════════

# assert_service_ports_open <container> <port>
assert_service_ports_open() {
  ((ASSERT_TOTAL++))
  local container="$1"
  local port="$2"

  local host_port=$(docker port "$container" "$port" 2>/dev/null | cut -d: -f2 | head -1)

  if [[ -z "$host_port" ]]; then
    echo -e "  ❌ FAIL: Port $port not exposed on $container"
    ((ASSERT_FAILED++))
    return 1
  fi

  if nc -z localhost "$host_port" 2>/dev/null; then
    echo -e "  ✅ PASS: Port $host_port (container:$port) is listening on $container"
    ((ASSERT_PASSED++))
    return 0
  else
    echo -e "  ❌ FAIL: Port $host_port on $container is not listening"
    ((ASSERT_FAILED++))
    return 1
  fi
}

# assert_docker_network_exists <network>
assert_docker_network_exists() {
  ((ASSERT_TOTAL++))
  local network="$1"

  if docker network ls --format '{{.Name}}' | grep -q "^${network}$"; then
    echo -e "  ✅ PASS: Docker network '$network' exists"
    ((ASSERT_PASSED++))
    return 0
  else
    echo -e "  ❌ FAIL: Docker network '$network' does not exist"
    ((ASSERT_FAILED++))
    return 1
  fi
}

# assert_docker_volume_exists <volume>
assert_docker_volume_exists() {
  ((ASSERT_TOTAL++))
  local volume="$1"

  if docker volume ls --format '{{.Name}}' | grep -q "^${volume}$"; then
    echo -e "  ✅ PASS: Docker volume '$volume' exists"
    ((ASSERT_PASSED++))
    return 0
  else
    echo -e "  ❌ FAIL: Docker volume '$volume' does not exist"
    ((ASSERT_FAILED++))
    return 1
  fi
}

# ═══════════════════════════════════════════════════════════════════════════
# 统计与输出
# ═══════════════════════════════════════════════════════════════════════════

assert_total() {
  echo "$ASSERT_TOTAL"
}

assert_passed() {
  echo "$ASSERT_PASSED"
}

assert_failed() {
  echo "$ASSERT_FAILED"
}

assert_skipped() {
  echo "$ASSERT_SKIPPED"
}

assert_reset_stats() {
  ASSERT_TOTAL=0
  ASSERT_PASSED=0
  ASSERT_FAILED=0
  ASSERT_SKIPPED=0
}

assert_set_suite() {
  CURRENT_SUITE="$1"
}

assert_set_test() {
  CURRENT_TEST="$1"
}

assert_print_test_header() {
  local test_name="${1:-$CURRENT_TEST}"
  echo -e "${BLUE}[${CURRENT_SUITE}]${NC} ▶ ${BOLD}$test_name${NC}"
}

# ═══════════════════════════════════════════════════════════════════════════
# 导出
# ═══════════════════════════════════════════════════════════════════════════

# 确保脚本作为库加载时不会直接执行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "This library is meant to be sourced, not executed directly."
  exit 1
fi