#!/usr/bin/env bash
# HomeLab Stack — 断言库
# 提供测试断言函数

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 测试结果统计
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# 断言函数：相等性检查
assert_eq() {
  local actual="$1"
  local expected="$2"
  local msg="${3:-Expected '$expected', got '$actual'}"
  
  ((TESTS_TOTAL++))
  
  if [[ "$actual" == "$expected" ]]; then
    ((TESTS_PASSED++))
    echo -e "${GREEN}✅ PASS${NC}: $msg"
    return 0
  else
    ((TESTS_FAILED++))
    echo -e "${RED}❌ FAIL${NC}: $msg"
    return 1
  fi
}

# 断言函数：非空检查
assert_not_empty() {
  local value="$1"
  local msg="${2:-Value should not be empty}"
  
  ((TESTS_TOTAL++))
  
  if [[ -n "$value" ]]; then
    ((TESTS_PASSED++))
    echo -e "${GREEN}✅ PASS${NC}: $msg"
    return 0
  else
    ((TESTS_FAILED++))
    echo -e "${RED}❌ FAIL${NC}: $msg"
    return 1
  fi
}

# 断言函数：退出码检查
assert_exit_code() {
  local code="$1"
  local msg="${2:-Exit code should be $code}"
  
  ((TESTS_TOTAL++))
  
  if [[ $? -eq $code ]]; then
    ((TESTS_PASSED++))
    echo -e "${GREEN}✅ PASS${NC}: $msg"
    return 0
  else
    ((TESTS_FAILED++))
    echo -e "${RED}❌ FAIL${NC}: $msg (expected $code, got $?)"
    return 1
  fi
}

# 断言函数：容器运行状态
assert_container_running() {
  local name="$1"
  local msg="${2:-Container $name should be running}"
  
  ((TESTS_TOTAL++))
  
  if docker ps --filter "name=$name" --filter "status=running" | grep -q "$name"; then
    ((TESTS_PASSED++))
    echo -e "${GREEN}✅ PASS${NC}: $msg"
    return 0
  else
    ((TESTS_FAILED++))
    echo -e "${RED}❌ FAIL${NC}: $msg"
    return 1
  fi
}

# 断言函数：容器健康状态
assert_container_healthy() {
  local name="$1"
  local timeout="${2:-60}"
  local msg="${3:-Container $name should be healthy}"
  
  ((TESTS_TOTAL++))
  
  local start_time=$(date +%s)
  local end_time=$((start_time + timeout))
  
  while [[ $(date +%s) -lt $end_time ]]; do
    if docker inspect --format='{{.State.Health.Status}}' "$name" 2>/dev/null | grep -q "healthy"; then
      ((TESTS_PASSED++))
      echo -e "${GREEN}✅ PASS${NC}: $msg"
      return 0
    fi
    sleep 2
  done
  
  ((TESTS_FAILED++))
  echo -e "${RED}❌ FAIL${NC}: $msg (timeout after ${timeout}s)"
  return 1
}

# 断言函数：HTTP 200 检查
assert_http_200() {
  local url="$1"
  local timeout="${2:-30}"
  local msg="${3:-HTTP GET $url should return 200}"
  
  ((TESTS_TOTAL++))
  
  local http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$timeout" "$url" 2>/dev/null || echo "000")
  
  if [[ "$http_code" == "200" ]]; then
    ((TESTS_PASSED++))
    echo -e "${GREEN}✅ PASS${NC}: $msg"
    return 0
  else
    ((TESTS_FAILED++))
    echo -e "${RED}❌ FAIL${NC}: $msg (expected 200, got $http_code)"
    return 1
  fi
}

# 断言函数：HTTP 响应内容检查
assert_http_response() {
  local url="$1"
  local pattern="$2"
  local msg="${3:-HTTP response should contain '$pattern'}"
  
  ((TESTS_TOTAL++))
  
  if curl -s --max-time 30 "$url" 2>/dev/null | grep -q "$pattern"; then
    ((TESTS_PASSED++))
    echo -e "${GREEN}✅ PASS${NC}: $msg"
    return 0
  else
    ((TESTS_FAILED++))
    echo -e "${RED}❌ FAIL${NC}: $msg"
    return 1
  fi
}

# 断言函数：JSON 值检查
assert_json_value() {
  local json="$1"
  local jq_path="$2"
  local expected="$3"
  local msg="${4:-JSON value at '$jq_path' should be '$expected'}"
  
  ((TESTS_TOTAL++))
  
  local actual=$(echo "$json" | jq -r "$jq_path" 2>/dev/null || echo "")
  
  if [[ "$actual" == "$expected" ]]; then
    ((TESTS_PASSED++))
    echo -e "${GREEN}✅ PASS${NC}: $msg"
    return 0
  else
    ((TESTS_FAILED++))
    echo -e "${RED}❌ FAIL${NC}: $msg (expected '$expected', got '$actual')"
    return 1
  fi
}

# 断言函数：JSON 键存在检查
assert_json_key_exists() {
  local json="$1"
  local jq_path="$2"
  local msg="${3:-JSON key '$jq_path' should exist}"
  
  ((TESTS_TOTAL++))
  
  if echo "$json" | jq -e "$jq_path" >/dev/null 2>&1; then
    ((TESTS_PASSED++))
    echo -e "${GREEN}✅ PASS${NC}: $msg"
    return 0
  else
    ((TESTS_FAILED++))
    echo -e "${RED}❌ FAIL${NC}: $msg"
    return 1
  fi
}

# 断言函数：无错误检查
assert_no_errors() {
  local json="$1"
  local msg="${2:-JSON should have no errors}"
  
  ((TESTS_TOTAL++))
  
  local errors=$(echo "$json" | jq -r '.errors // empty' 2>/dev/null)
  
  if [[ -z "$errors" ]]; then
    ((TESTS_PASSED++))
    echo -e "${GREEN}✅ PASS${NC}: $msg"
    return 0
  else
    ((TESTS_FAILED++))
    echo -e "${RED}❌ FAIL${NC}: $msg (errors: $errors)"
    return 1
  fi
}

# 断言函数：文件内容检查
assert_file_contains() {
  local file="$1"
  local pattern="$2"
  local msg="${3:-File '$file' should contain '$pattern'}"
  
  ((TESTS_TOTAL++))
  
  if [[ -f "$file" ]] && grep -q "$pattern" "$file"; then
    ((TESTS_PASSED++))
    echo -e "${GREEN}✅ PASS${NC}: $msg"
    return 0
  else
    ((TESTS_FAILED++))
    echo -e "${RED}❌ FAIL${NC}: $msg"
    return 1
  fi
}

# 断言函数：无最新镜像检查
assert_no_latest_images() {
  local dir="$1"
  local msg="${2:-No 'latest' image tags should be used in '$dir'}"
  
  ((TESTS_TOTAL++))
  
  if find "$dir" -name "docker-compose.yml" -o -name "docker-compose.yaml" | xargs grep -h "image:" | grep -v "#" | grep -q ":latest"; then
    ((TESTS_FAILED++))
    echo -e "${RED}❌ FAIL${NC}: $msg"
    return 1
  else
    ((TESTS_PASSED++))
    echo -e "${GREEN}✅ PASS${NC}: $msg"
    return 0
  fi
}

# 导出统计信息
export_assert_stats() {
  echo ""
  echo "──────────────────────────────────────"
  echo "Results: $TESTS_PASSED passed, $TESTS_FAILED failed, $TESTS_SKIPPED skipped"
  echo "Total: $TESTS_TOTAL tests"
  echo "──────────────────────────────────────"
}
