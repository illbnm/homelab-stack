#!/bin/bash
# assert.sh - 断言库 for HomeLab Stack 集成测试
# 提供常用断言函数，支持彩色输出和 JSON 报告

set -u

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 计数器
ASSERT_TOTAL=0
ASSERT_PASSED=0
ASSERT_FAILED=0
ASSERT_SKIPPED=0

# 当前测试栈
CURRENT_STACK=""

# 初始化计数器
init_assertions() {
    ASSERT_TOTAL=0
    ASSERT_PASSED=0
    ASSERT_FAILED=0
    ASSERT_SKIPPED=0
}

# 记录断言结果
_record_assertion() {
    local status="$1"
    local name="$2"
    local duration="$3"
    local message="$4"
    
    ((ASSERT_TOTAL++))
    
    case "$status" in
        "PASS")
            ((ASSERT_PASSED++))
            echo -e "[${CURRENT_STACK}] ▶ ${name} ${GREEN}✅ PASS${NC} (${duration}s)"
            ;;
        "FAIL")
            ((ASSERT_FAILED++))
            echo -e "[${CURRENT_STACK}] ▶ ${name} ${RED}❌ FAIL${NC} (${duration}s)"
            echo -e "  ${RED}→ ${message}${NC}"
            ;;
        "SKIP")
            ((ASSERT_SKIPPED++))
            echo -e "[${CURRENT_STACK}] ▶ ${name} ${YELLOW}⊗ SKIP${NC}"
            ;;
    esac
}

# assert_eq <actual> <expected> [msg]
assert_eq() {
    local actual="$1"
    local expected="$2"
    local msg="${3:-}"
    local start_time=$(date +%s.%N)
    
    if [[ "$actual" == "$expected" ]]; then
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
        _record_assertion "PASS" "$msg" "$duration"
        return 0
    else
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
        _record_assertion "FAIL" "$msg" "$duration" "Expected: '$expected', Got: '$actual'"
        return 1
    fi
}

# assert_not_empty <value> [msg]
assert_not_empty() {
    local value="$1"
    local msg="${2:-Value not empty}"
    local start_time=$(date +%s.%N)
    
    if [[ -n "$value" ]]; then
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
        _record_assertion "PASS" "$msg" "$duration"
        return 0
    else
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
        _record_assertion "FAIL" "$msg" "$duration" "Value is empty"
        return 1
    fi
}

# assert_exit_code <expected_code> <command> [msg]
assert_exit_code() {
    local expected="$1"
    shift
    local cmd="$*"
    local start_time=$(date +%s.%N)
    
    eval "$cmd" > /dev/null 2>&1
    local actual=$?
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
    
    if [[ "$actual" -eq "$expected" ]]; then
        _record_assertion "PASS" "$cmd" "$duration"
        return 0
    else
        _record_assertion "FAIL" "$cmd" "$duration" "Expected exit code: $expected, Got: $actual"
        return 1
    fi
}

# assert_container_running <name>
assert_container_running() {
    local name="$1"
    local start_time=$(date +%s.%N)
    
    local status=$(docker inspect --format='{{.State.Status}}' "$name" 2>/dev/null)
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
    
    if [[ "$status" == "running" ]]; then
        _record_assertion "PASS" "$name running" "$duration"
        return 0
    else
        _record_assertion "FAIL" "$name running" "$duration" "Container status: ${status:-not found}"
        return 1
    fi
}

# assert_container_healthy <name> [timeout=60]
assert_container_healthy() {
    local name="$1"
    local timeout="${2:-60}"
    local start_time=$(date +%s)
    
    while true; do
        local health=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$name" 2>/dev/null)
        local status=$(docker inspect --format='{{.State.Status}}' "$name" 2>/dev/null)
        
        if [[ "$status" != "running" ]]; then
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            _record_assertion "FAIL" "$name healthy" "${duration}s" "Container not running"
            return 1
        fi
        
        if [[ "$health" == "healthy" || "$health" == "none" ]]; then
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            _record_assertion "PASS" "$name healthy" "${duration}s"
            return 0
        fi
        
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        if [[ $elapsed -ge $timeout ]]; then
            _record_assertion "FAIL" "$name healthy" "${timeout}s" "Timeout waiting for healthy status (current: $health)"
            return 1
        fi
        
        sleep 2
    done
}

# assert_http_200 <url> [timeout=30]
assert_http_200() {
    local url="$1"
    local timeout="${2:-30}"
    local start_time=$(date +%s.%N)
    
    local http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$timeout" "$url" 2>/dev/null)
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
    
    if [[ "$http_code" == "200" ]]; then
        _record_assertion "PASS" "HTTP 200 $url" "$duration"
        return 0
    else
        _record_assertion "FAIL" "HTTP 200 $url" "$duration" "Expected: 200, Got: ${http_code:-connection failed}"
        return 1
    fi
}

# assert_http_response <url> <pattern> [msg]
assert_http_response() {
    local url="$1"
    local pattern="$2"
    local msg="${3:-HTTP response contains $pattern}"
    local start_time=$(date +%s.%N)
    
    local response=$(curl -s --max-time 30 "$url" 2>/dev/null)
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
    
    if echo "$response" | grep -q "$pattern"; then
        _record_assertion "PASS" "$msg" "$duration"
        return 0
    else
        _record_assertion "FAIL" "$msg" "$duration" "Pattern '$pattern' not found in response"
        return 1
    fi
}

# assert_json_value <json> <jq_path> <expected> [msg]
assert_json_value() {
    local json="$1"
    local jq_path="$2"
    local expected="$3"
    local msg="${4:-JSON value at $jq_path}"
    local start_time=$(date +%s.%N)
    
    local actual=$(echo "$json" | jq -r "$jq_path" 2>/dev/null)
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
    
    if [[ "$actual" == "$expected" ]]; then
        _record_assertion "PASS" "$msg" "$duration"
        return 0
    else
        _record_assertion "FAIL" "$msg" "$duration" "Expected: '$expected', Got: '$actual'"
        return 1
    fi
}

# assert_json_key_exists <json> <jq_path> [msg]
assert_json_key_exists() {
    local json="$1"
    local jq_path="$2"
    local msg="${3:-JSON key exists at $jq_path}"
    local start_time=$(date +%s.%N)
    
    local result=$(echo "$json" | jq -e "$jq_path" > /dev/null 2>&1; echo $?)
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
    
    if [[ "$result" == "0" ]]; then
        _record_assertion "PASS" "$msg" "$duration"
        return 0
    else
        _record_assertion "FAIL" "$msg" "$duration" "Key '$jq_path' not found"
        return 1
    fi
}

# assert_no_errors <json> [msg]
assert_no_errors() {
    local json="$1"
    local msg="${2:-No errors in response}"
    local start_time=$(date +%s.%N)
    
    local has_errors=$(echo "$json" | jq -e '.errors' > /dev/null 2>&1; echo $?)
    local errors_count=$(echo "$json" | jq '.errors | length' 2>/dev/null)
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
    
    if [[ "$has_errors" != "0" || "$errors_count" == "0" || "$errors_count" == "null" ]]; then
        _record_assertion "PASS" "$msg" "$duration"
        return 0
    else
        _record_assertion "FAIL" "$msg" "$duration" "Found $errors_count errors"
        return 1
    fi
}

# assert_file_contains <file> <pattern> [msg]
assert_file_contains() {
    local file="$1"
    local pattern="$2"
    local msg="${3:-File $file contains $pattern}"
    local start_time=$(date +%s.%N)
    
    if [[ ! -f "$file" ]]; then
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
        _record_assertion "FAIL" "$msg" "$duration" "File not found: $file"
        return 1
    fi
    
    if grep -q "$pattern" "$file" 2>/dev/null; then
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
        _record_assertion "PASS" "$msg" "$duration"
        return 0
    else
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
        _record_assertion "FAIL" "$msg" "$duration" "Pattern '$pattern' not found in $file"
        return 1
    fi
}

# assert_no_latest_images <dir>
assert_no_latest_images() {
    local dir="$1"
    local start_time=$(date +%s.%N)
    
    local count=$(grep -r 'image:.*:latest' "$dir" 2>/dev/null | wc -l)
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
    
    if [[ "$count" -eq 0 ]]; then
        _record_assertion "PASS" "No :latest tags in $dir" "$duration"
        return 0
    else
        _record_assertion "FAIL" "No :latest tags in $dir" "$duration" "Found $count images with :latest tag"
        return 1
    fi
}

# assert_compose_valid <file>
assert_compose_valid() {
    local file="$1"
    local start_time=$(date +%s.%N)
    
    local output=$(docker compose -f "$file" config --quiet 2>&1)
    local exit_code=$?
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
    
    if [[ $exit_code -eq 0 ]]; then
        _record_assertion "PASS" "Compose valid: $file" "$duration"
        return 0
    else
        _record_assertion "FAIL" "Compose valid: $file" "$duration" "$output"
        return 1
    fi
}

# 获取断言统计
get_assertion_stats() {
    echo "$ASSERT_PASSED $ASSERT_FAILED $ASSERT_SKIPPED $ASSERT_TOTAL"
}
