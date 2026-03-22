#!/bin/bash
# assert.sh - 断言库 for HomeLab Stack Integration Tests
# 提供统一的断言函数，支持彩色输出和详细错误信息

set -o pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 计数器
ASSERT_PASS=0
ASSERT_FAIL=0
ASSERT_SKIP=0

# 记录测试结果
declare -a TEST_RESULTS

# assert_eq - 检查两个值是否相等
# 用法: assert_eq <actual> <expected> [msg]
assert_eq() {
    local actual="$1"
    local expected="$2"
    local msg="${3:-}"
    
    if [[ "$actual" == "$expected" ]]; then
        ((ASSERT_PASS++))
        return 0
    else
        ((ASSERT_FAIL++))
        echo -e "${RED}❌ FAIL${NC}: Expected '$expected', got '$actual'"
        [[ -n "$msg" ]] && echo -e "${RED}   $msg${NC}"
        return 1
    fi
}

# assert_not_empty - 检查值非空
# 用法: assert_not_empty <value> [msg]
assert_not_empty() {
    local value="$1"
    local msg="${2:-Value should not be empty}"
    
    if [[ -n "$value" ]]; then
        ((ASSERT_PASS++))
        return 0
    else
        ((ASSERT_FAIL++))
        echo -e "${RED}❌ FAIL${NC}: $msg"
        return 1
    fi
}

# assert_exit_code - 检查命令退出码
# 用法: assert_exit_code <expected_code> <msg>
assert_exit_code() {
    local expected="$1"
    local msg="${2:-Command exit code}"
    local actual=$?
    
    if [[ "$actual" -eq "$expected" ]]; then
        ((ASSERT_PASS++))
        return 0
    else
        ((ASSERT_FAIL++))
        echo -e "${RED}❌ FAIL${NC}: $msg - Expected exit code $expected, got $actual"
        return 1
    fi
}

# assert_container_running - 检查容器是否运行
# 用法: assert_container_running <container_name>
assert_container_running() {
    local name="$1"
    local status
    status=$(docker inspect --format='{{.State.Running}}' "$name" 2>/dev/null)
    
    if [[ "$status" == "true" ]]; then
        ((ASSERT_PASS++))
        return 0
    else
        ((ASSERT_FAIL++))
        echo -e "${RED}❌ FAIL${NC}: Container '$name' is not running"
        return 1
    fi
}

# assert_container_healthy - 检查容器健康状态 (等待最多 60s)
# 用法: assert_container_healthy <container_name> [timeout]
assert_container_healthy() {
    local name="$1"
    local timeout="${2:-60}"
    local elapsed=0
    local health
    
    while [[ $elapsed -lt $timeout ]]; do
        health=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$name" 2>/dev/null)
        
        if [[ "$health" == "healthy" ]]; then
            ((ASSERT_PASS++))
            return 0
        elif [[ "$health" == "none" ]]; then
            # 容器没有 healthcheck，检查是否运行
            local running
            running=$(docker inspect --format='{{.State.Running}}' "$name" 2>/dev/null)
            if [[ "$running" == "true" ]]; then
                ((ASSERT_PASS++))
                return 0
            fi
        fi
        
        sleep 2
        ((elapsed+=2))
    done
    
    ((ASSERT_FAIL++))
    echo -e "${RED}❌ FAIL${NC}: Container '$name' is not healthy after ${timeout}s (status: $health)"
    return 1
}

# assert_http_200 - 检查 HTTP 端点返回 200
# 用法: assert_http_200 <url> [timeout]
assert_http_200() {
    local url="$1"
    local timeout="${2:-30}"
    local response
    
    response=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$timeout" "$url" 2>/dev/null)
    
    if [[ "$response" == "200" ]]; then
        ((ASSERT_PASS++))
        return 0
    else
        ((ASSERT_FAIL++))
        echo -e "${RED}❌ FAIL${NC}: GET $url returned $response (expected 200)"
        return 1
    fi
}

# assert_http_response - 检查 HTTP 响应包含指定模式
# 用法: assert_http_response <url> <pattern> [timeout]
assert_http_response() {
    local url="$1"
    local pattern="$2"
    local timeout="${3:-30}"
    local response
    
    response=$(curl -s --max-time "$timeout" "$url" 2>/dev/null)
    
    if echo "$response" | grep -q "$pattern"; then
        ((ASSERT_PASS++))
        return 0
    else
        ((ASSERT_FAIL++))
        echo -e "${RED}❌ FAIL${NC}: GET $url does not contain '$pattern'"
        return 1
    fi
}

# assert_json_value - 检查 JSON 值
# 用法: assert_json_value <json> <jq_path> <expected>
assert_json_value() {
    local json="$1"
    local jq_path="$2"
    local expected="$3"
    local actual
    
    actual=$(echo "$json" | jq -r "$jq_path" 2>/dev/null)
    
    if [[ "$actual" == "$expected" ]]; then
        ((ASSERT_PASS++))
        return 0
    else
        ((ASSERT_FAIL++))
        echo -e "${RED}❌ FAIL${NC}: JSON path '$jq_path' - Expected '$expected', got '$actual'"
        return 1
    fi
}

# assert_json_key_exists - 检查 JSON 键是否存在
# 用法: assert_json_key_exists <json> <jq_path>
assert_json_key_exists() {
    local json="$1"
    local jq_path="$2"
    local result
    
    result=$(echo "$json" | jq -e "$jq_path" >/dev/null 2>&1 && echo "yes" || echo "no")
    
    if [[ "$result" == "yes" ]]; then
        ((ASSERT_PASS++))
        return 0
    else
        ((ASSERT_FAIL++))
        echo -e "${RED}❌ FAIL${NC}: JSON path '$jq_path' does not exist"
        return 1
    fi
}

# assert_no_errors - 检查 JSON 中 errors 为空
# 用法: assert_no_errors <json>
assert_no_errors() {
    local json="$1"
    local errors
    
    errors=$(echo "$json" | jq -r '.errors // empty' 2>/dev/null)
    
    if [[ -z "$errors" || "$errors" == "null" || "$errors" == "[]" ]]; then
        ((ASSERT_PASS++))
        return 0
    else
        ((ASSERT_FAIL++))
        echo -e "${RED}❌ FAIL${NC}: JSON contains errors: $errors"
        return 1
    fi
}

# assert_file_contains - 检查文件包含指定模式
# 用法: assert_file_contains <file> <pattern>
assert_file_contains() {
    local file="$1"
    local pattern="$2"
    
    if grep -q "$pattern" "$file" 2>/dev/null; then
        ((ASSERT_PASS++))
        return 0
    else
        ((ASSERT_FAIL++))
        echo -e "${RED}❌ FAIL${NC}: File '$file' does not contain '$pattern'"
        return 1
    fi
}

# assert_no_latest_images - 检查 compose 文件不含 :latest 镜像标签
# 用法: assert_no_latest_images <dir>
assert_no_latest_images() {
    local dir="$1"
    local count
    
    count=$(grep -r 'image:.*:latest' "$dir" 2>/dev/null | wc -l)
    
    if [[ "$count" -eq 0 ]]; then
        ((ASSERT_PASS++))
        return 0
    else
        ((ASSERT_FAIL++))
        echo -e "${RED}❌ FAIL${NC}: Found $count :latest image tags in $dir"
        grep -r 'image:.*:latest' "$dir" 2>/dev/null
        return 1
    fi
}

# assert_skip - 跳过测试
# 用法: assert_skip [reason]
assert_skip() {
    local reason="${1:-No reason provided}"
    ((ASSERT_SKIP++))
    echo -e "${YELLOW}⊘ SKIP${NC}: $reason"
    return 0
}

# get_assert_stats - 获取断言统计
# 用法: get_assert_stats
get_assert_stats() {
    echo "PASS=$ASSERT_PASS FAIL=$ASSERT_FAIL SKIP=$ASSERT_SKIP"
}

# reset_assert_stats - 重置计数器
reset_assert_stats() {
    ASSERT_PASS=0
    ASSERT_FAIL=0
    ASSERT_SKIP=0
}
