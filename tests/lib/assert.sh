#!/usr/bin/env bash
# assert.sh — 断言库 for HomeLab Stack Integration Tests
# 遵循 PUA 压力升级原则：穷尽所有方案才允许 FAIL

set -euo pipefail

# ─── 全局配置 ────────────────────────────────────────────────
ASSERT_FAIL_COUNT=0
ASSERT_PASS_COUNT=0
ASSERT_SKIP_COUNT=0
ASSERT_TEST_NAME=""
ASSERT_JSON_RESULTS=()

# ─── 彩色输出 ─────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
DIM='\033[2m'

_pass() { echo -e "${GREEN}✅ PASS${NC} ($1)"; ((PASS_COUNT++)); }
_fail() { echo -e "${RED}❌ FAIL${NC} ($1)"; ((FAIL_COUNT++)); }
_skip() { echo -e "${YELLOW}⏭️  SKIP${NC} ($1)"; ((SKIP_COUNT++)); }

# ─── 核心断言 ────────────────────────────────────────────────

# assert_eq <actual> <expected> [message]
assert_eq() {
    local actual="$1" expected="$2" msg="${3:-}"
    local duration=$(($3 ? 0 : 0))
    local test_name="${ASSERT_TEST_NAME:-unknown}"
    local stack="${STACK_NAME:-unknown}"
    
    if [[ "$actual" == "$expected" ]]; then
        ((ASSERT_PASS_COUNT++))
        echo -e "[${stack}] ▶ ${test_name} ${GREEN}✅ PASS${NC} (${actual} == ${expected})"
        ASSERT_JSON_RESULTS+=("{\"stack\":\"$stack\",\"test\":\"$test_name\",\"status\":\"PASS\",\"expected\":\"$expected\",\"actual\":\"$actual\"}")
    else
        ((ASSERT_FAIL_COUNT++))
        echo -e "[${stack}] ▶ ${test_name} ${RED}❌ FAIL${NC} (expected: $expected, got: $actual)${msg:+: $msg}"
        ASSERT_JSON_RESULTS+=("{\"stack\":\"$stack\",\"test\":\"$test_name\",\"status\":\"FAIL\",\"expected\":\"$expected\",\"actual\":\"$actual\"}")
    fi
}

# assert_not_empty <value> [message]
assert_not_empty() {
    local value="$1" msg="${2:-}"
    local test_name="${ASSERT_TEST_NAME:-unknown}"
    local stack="${STACK_NAME:-unknown}"
    
    if [[ -n "$value" ]]; then
        ((ASSERT_PASS_COUNT++))
        echo -e "[${stack}] ▶ ${test_name} ${GREEN}✅ PASS${NC} (value not empty)"
        ASSERT_JSON_RESULTS+=("{\"stack\":\"$stack\",\"test\":\"$test_name\",\"status\":\"PASS\"}")
    else
        ((ASSERT_FAIL_COUNT++))
        echo -e "[${stack}] ▶ ${test_name} ${RED}❌ FAIL${NC}${msg:+: $msg}"
        ASSERT_JSON_RESULTS+=("{\"stack\":\"$stack\",\"test\":\"$test_name\",\"status\":\"FAIL\"}")
    fi
}

# assert_exit_code <code> [message]
assert_exit_code() {
    local expected_code="$1" msg="${2:-}"
    local actual_code="$?"
    assert_eq "$actual_code" "$expected_code" "$msg"
}

# assert_contains <haystack> <needle>
assert_contains() {
    local haystack="$1" needle="$2"
    local test_name="${ASSERT_TEST_NAME:-unknown}"
    local stack="${STACK_NAME:-unknown}"
    
    if echo "$haystack" | grep -q "$needle"; then
        ((ASSERT_PASS_COUNT++))
        echo -e "[${stack}] ▶ ${test_name} ${GREEN}✅ PASS${NC} ('$needle' found)"
        ASSERT_JSON_RESULTS+=("{\"stack\":\"$stack\",\"test\":\"$test_name\",\"status\":\"PASS\"}")
    else
        ((ASSERT_FAIL_COUNT++))
        echo -e "[${stack}] ▶ ${test_name} ${RED}❌ FAIL${NC} ('$needle' not found in: $haystack)"
        ASSERT_JSON_RESULTS+=("{\"stack\":\"$stack\",\"test\":\"$test_name\",\"status\":\"FAIL\"}")
    fi
}

# assert_not_contains <haystack> <needle>
assert_not_contains() {
    local haystack="$1" needle="$2"
    local test_name="${ASSERT_TEST_NAME:-unknown}"
    local stack="${STACK_NAME:-unknown}"
    
    if ! echo "$haystack" | grep -q "$needle"; then
        ((ASSERT_PASS_COUNT++))
        echo -e "[${stack}] ▶ ${test_name} ${GREEN}✅ PASS${NC} ('$needle' not found)"
        ASSERT_JSON_RESULTS+=("{\"stack\":\"$stack\",\"test\":\"$test_name\",\"status\":\"PASS\"}")
    else
        ((ASSERT_FAIL_COUNT++))
        echo -e "[${stack}] ▶ ${test_name} ${RED}❌ FAIL${NC} ('$needle' found but should not be)"
        ASSERT_JSON_RESULTS+=("{\"stack\":\"$stack\",\"test\":\"$test_name\",\"status\":\"FAIL\"}")
    fi
}

# ─── Docker 专用断言 ─────────────────────────────────────────

# assert_container_running <name>
assert_container_running() {
    local name="$1"
    local test_name="Container $name running"
    local stack="${STACK_NAME:-unknown}"
    
    if docker ps --format '{{.Names}}' | grep -q "^${name}$"; then
        ((ASSERT_PASS_COUNT++))
        echo -e "[${stack}] ▶ ${test_name} ${GREEN}✅ PASS${NC}"
        ASSERT_JSON_RESULTS+=("{\"stack\":\"$stack\",\"test\":\"$test_name\",\"status\":\"PASS\",\"container\":\"$name\"}")
    else
        ((ASSERT_FAIL_COUNT++))
        echo -e "[${stack}] ▶ ${test_name} ${RED}❌ FAIL${NC} (container '$name' not running)"
        ASSERT_JSON_RESULTS+=("{\"stack\":\"$stack\",\"test\":\"$test_name\",\"status\":\"FAIL\",\"container\":\"$name\"}")
    fi
}

# assert_container_healthy <name> [timeout=60]
assert_container_healthy() {
    local name="$1"
    local timeout="${2:-60}"
    local test_name="Container $name healthy"
    local stack="${STACK_NAME:-unknown}"
    local elapsed=0
    local interval=5
    
    # 先检查是否在运行
    if ! docker ps --format '{{.Names}}' | grep -q "^${name}$"; then
        ((ASSERT_FAIL_COUNT++))
        echo -e "[${stack}] ▶ ${test_name} ${RED}❌ FAIL${NC} (container not running)"
        return 1
    fi
    
    # 检查 healthcheck 状态
    while ((elapsed < timeout)); do
        local status=$(docker inspect --format '{{.State.Health.Status}}' "$name" 2>/dev/null || echo "none")
        
        if [[ "$status" == "healthy" ]]; then
            ((ASSERT_PASS_COUNT++))
            echo -e "[${stack}] ▶ ${test_name} ${GREEN}✅ PASS${NC} (${elapsed}s)"
            ASSERT_JSON_RESULTS+=("{\"stack\":\"$stack\",\"test\":\"$test_name\",\"status\":\"PASS\",\"container\":\"$name\",\"elapsed\":$elapsed}")
            return 0
        elif [[ "$status" == "unhealthy" ]]; then
            ((ASSERT_FAIL_COUNT++))
            echo -e "[${stack}] ▶ ${test_name} ${RED}❌ FAIL${NC} (container unhealthy after ${elapsed}s)"
            return 1
        fi
        
        sleep $interval
        ((elapsed += interval))
    done
    
    # 超时：检查是否根本没有 healthcheck
    local has_healthcheck=$(docker inspect --format '{{.Config.Healthcheck}}' "$name" 2>/dev/null)
    if [[ "$has_healthcheck" == "<nil>" || -z "$has_healthcheck" ]]; then
        # 无 healthcheck，标记为 SKIP
        ((ASSERT_SKIP_COUNT++))
        echo -e "[${stack}] ▶ ${test_name} ${YELLOW}⏭️  SKIP${NC} (no healthcheck defined)"
    else
        ((ASSERT_FAIL_COUNT++))
        echo -e "[${stack}] ▶ ${test_name} ${RED}❌ FAIL${NC} (timeout after ${timeout}s, status: $status)"
    fi
    return 1
}

# assert_container_not_running <name>
assert_container_not_running() {
    local name="$1"
    local test_name="Container $name not running"
    local stack="${STACK_NAME:-unknown}"
    
    if ! docker ps --format '{{.Names}}' | grep -q "^${name}$"; then
        ((ASSERT_PASS_COUNT++))
        echo -e "[${stack}] ▶ ${test_name} ${GREEN}✅ PASS${NC}"
        ASSERT_JSON_RESULTS+=("{\"stack\":\"$stack\",\"test\":\"$test_name\",\"status\":\"PASS\",\"container\":\"$name\"}")
    else
        ((ASSERT_FAIL_COUNT++))
        echo -e "[${stack}] ▶ ${test_name} ${RED}❌ FAIL${NC} (container '$name' is still running)"
        ASSERT_JSON_RESULTS+=("{\"stack\":\"$stack\",\"test\":\"$test_name\",\"status\":\"FAIL\",\"container\":\"$name\"}")
    fi
}

# ─── HTTP 专用断言 ───────────────────────────────────────────

# assert_http_200 <url> [timeout=30]
assert_http_200() {
    local url="$1"
    local timeout="${2:-30}"
    local test_name="HTTP 200 $url"
    local stack="${STACK_NAME:-unknown}"
    local response
    local http_code
    
    response=$(curl -sS -o /dev/null -w "%{http_code}" --max-time "$timeout" "$url" 2>/dev/null || echo "000")
    http_code="$response"
    
    if [[ "$http_code" == "200" ]]; then
        ((ASSERT_PASS_COUNT++))
        echo -e "[${stack}] ▶ ${test_name} ${GREEN}✅ PASS${NC}"
        ASSERT_JSON_RESULTS+=("{\"stack\":\"$stack\",\"test\":\"$test_name\",\"status\":\"PASS\",\"url\":\"$url\",\"http_code\":200}")
    else
        ((ASSERT_FAIL_COUNT++))
        echo -e "[${stack}] ▶ ${test_name} ${RED}❌ FAIL${NC} (expected: 200, got: $http_code)"
        ASSERT_JSON_RESULTS+=("{\"stack\":\"$stack\",\"test\":\"$test_name\",\"status\":\"FAIL\",\"url\":\"$url\",\"http_code\":$http_code}")
    fi
}

# assert_http_response <url> <pattern> [timeout=30]
assert_http_response() {
    local url="$1" pattern="$2" timeout="${3:-30}"
    local test_name="HTTP response $url contains '$pattern'"
    local stack="${STACK_NAME:-unknown}"
    local response
    
    response=$(curl -sS --max-time "$timeout" "$url" 2>/dev/null || echo "")
    
    if echo "$response" | grep -q "$pattern"; then
        ((ASSERT_PASS_COUNT++))
        echo -e "[${stack}] ▶ ${test_name} ${GREEN}✅ PASS${NC}"
        ASSERT_JSON_RESULTS+=("{\"stack\":\"$stack\",\"test\":\"$test_name\",\"status\":\"PASS\",\"url\":\"$url\"}")
    else
        ((ASSERT_FAIL_COUNT++))
        echo -e "[${stack}] ▶ ${test_name} ${RED}❌ FAIL${NC} (pattern '$pattern' not found)"
        ASSERT_JSON_RESULTS+=("{\"stack\":\"$stack\",\"test\":\"$test_name\",\"status\":\"FAIL\",\"url\":\"$url\"}")
    fi
}

# assert_http_status <url> <expected_code> [timeout=30]
assert_http_status() {
    local url="$1" expected="$2" timeout="${3:-30}"
    local test_name="HTTP $url == $expected"
    local stack="${STACK_NAME:-unknown}"
    local http_code
    
    http_code=$(curl -sS -o /dev/null -w "%{http_code}" --max-time "$timeout" "$url" 2>/dev/null || echo "000")
    
    if [[ "$http_code" == "$expected" ]]; then
        ((ASSERT_PASS_COUNT++))
        echo -e "[${stack}] ▶ ${test_name} ${GREEN}✅ PASS${NC}"
        ASSERT_JSON_RESULTS+=("{\"stack\":\"$stack\",\"test\":\"$test_name\",\"status\":\"PASS\",\"url\":\"$url\",\"http_code\":$expected}")
    else
        ((ASSERT_FAIL_COUNT++))
        echo -e "[${stack}] ▶ ${test_name} ${RED}❌ FAIL${NC} (expected: $expected, got: $http_code)"
        ASSERT_JSON_RESULTS+=("{\"stack\":\"$stack\",\"test\":\"$test_name\",\"status\":\"FAIL\",\"url\":\"$url\",\"http_code\":$http_code}")
    fi
}

# assert_json_value <json> <jq_path> <expected>
assert_json_value() {
    local json="$1" jq_path="$2" expected="$3"
    local test_name="JSON $jq_path == $expected"
    local stack="${STACK_NAME:-unknown}"
    local actual
    
    actual=$(echo "$json" | jq -r "$jq_path" 2>/dev/null || echo "null")
    
    if [[ "$actual" == "$expected" ]]; then
        ((ASSERT_PASS_COUNT++))
        echo -e "[${stack}] ▶ ${test_name} ${GREEN}✅ PASS${NC}"
        ASSERT_JSON_RESULTS+=("{\"stack\":\"$stack\",\"test\":\"$test_name\",\"status\":\"PASS\"}")
    else
        ((ASSERT_FAIL_COUNT++))
        echo -e "[${stack}] ▶ ${test_name} ${RED}❌ FAIL${NC} (expected: $expected, got: $actual)"
        ASSERT_JSON_RESULTS+=("{\"stack\":\"$stack\",\"test\":\"$test_name\",\"status\":\"FAIL\"}")
    fi
}

# assert_json_key_exists <json> <jq_path>
assert_json_key_exists() {
    local json="$1" jq_path="$2"
    local test_name="JSON key exists $jq_path"
    local stack="${STACK_NAME:-unknown}"
    local value
    
    value=$(echo "$json" | jq -r "$jq_path" 2>/dev/null || echo "null")
    
    if [[ "$value" != "null" && -n "$value" ]]; then
        ((ASSERT_PASS_COUNT++))
        echo -e "[${stack}] ▶ ${test_name} ${GREEN}✅ PASS${NC}"
        ASSERT_JSON_RESULTS+=("{\"stack\":\"$stack\",\"test\":\"$test_name\",\"status\":\"PASS\"}")
    else
        ((ASSERT_FAIL_COUNT++))
        echo -e "[${stack}] ▶ ${test_name} ${RED}❌ FAIL${NC} (key '$jq_path' not found or null)"
        ASSERT_JSON_RESULTS+=("{\"stack\":\"$stack\",\"test\":\"$test_name\",\"status\":\"FAIL\"}")
    fi
}

# assert_no_errors <json>
assert_no_errors() {
    local json="$1"
    local test_name="JSON response has no errors"
    local stack="${STACK_NAME:-unknown}"
    local errors
    
    errors=$(echo "$json" | jq -r '.errors // [] | if type == "array" then length else 1 end' 2>/dev/null || echo "0")
    
    if [[ "$errors" == "0" || "$errors" == "null" ]]; then
        ((ASSERT_PASS_COUNT++))
        echo -e "[${stack}] ▶ ${test_name} ${GREEN}✅ PASS${NC}"
        ASSERT_JSON_RESULTS+=("{\"stack\":\"$stack\",\"test\":\"$test_name\",\"status\":\"PASS\"}")
    else
        ((ASSERT_FAIL_COUNT++))
        echo -e "[${stack}] ▶ ${test_name} ${RED}❌ FAIL${NC} (found $errors error(s))"
        ASSERT_JSON_RESULTS+=("{\"stack\":\"$stack\",\"test\":\"$test_name\",\"status\":\"FAIL\"}")
    fi
}

# assert_file_contains <file> <pattern>
assert_file_contains() {
    local file="$1" pattern="$2"
    local test_name="File $file contains '$pattern'"
    local stack="${STACK_NAME:-unknown}"
    
    if [[ ! -f "$file" ]]; then
        ((ASSERT_FAIL_COUNT++))
        echo -e "[${stack}] ▶ ${test_name} ${RED}❌ FAIL${NC} (file not found: $file)"
        return 1
    fi
    
    if grep -q "$pattern" "$file" 2>/dev/null; then
        ((ASSERT_PASS_COUNT++))
        echo -e "[${stack}] ▶ ${test_name} ${GREEN}✅ PASS${NC}"
        ASSERT_JSON_RESULTS+=("{\"stack\":\"$stack\",\"test\":\"$test_name\",\"status\":\"PASS\"}")
    else
        ((ASSERT_FAIL_COUNT++))
        echo -e "[${stack}] ▶ ${test_name} ${RED}❌ FAIL${NC} (pattern not found)"
        ASSERT_JSON_RESULTS+=("{\"stack\":\"$stack\",\"test\":\"$test_name\",\"status\":\"FAIL\"}")
    fi
}

# assert_no_latest_images <dir>
assert_no_latest_images() {
    local dir="$1"
    local test_name="No :latest image tags in $dir"
    local stack="${STACK_NAME:-unknown}"
    local count
    
    count=$(grep -r 'image:.*:latest' "$dir" 2>/dev/null | wc -l || echo "0")
    
    if [[ "$count" -eq 0 ]]; then
        ((ASSERT_PASS_COUNT++))
        echo -e "[${stack}] ▶ ${test_name} ${GREEN}✅ PASS${NC}"
        ASSERT_JSON_RESULTS+=("{\"stack\":\"$stack\",\"test\":\"$test_name\",\"status\":\"PASS\"}")
    else
        ((ASSERT_FAIL_COUNT++))
        echo -e "[${stack}] ▶ ${test_name} ${RED}❌ FAIL${NC} (found $count :latest tags)"
        grep -r 'image:.*:latest' "$dir" | head -5 | while read line; do
            echo -e "       ${DIM}$line${NC}"
        done
        ASSERT_JSON_RESULTS+=("{\"stack\":\"$stack\",\"test\":\"$test_name\",\"status\":\"FAIL\",\"count\":$count}")
    fi
}

# ─── 统计与报告 ──────────────────────────────────────────────

# assert_summary — 输出最终统计
assert_summary() {
    local total=$((ASSERT_PASS_COUNT + ASSERT_FAIL_COUNT + ASSERT_SKIP_COUNT))
    echo ""
    echo "──────────────────────────────────────"
    echo -e "Results: ${GREEN}${ASSERT_PASS_COUNT} passed${NC}, ${RED}${ASSERT_FAIL_COUNT} failed${NC}, ${YELLOW}${ASSERT_SKIP_COUNT} skipped${NC}"
    echo -e "Total: $total tests"
    echo "──────────────────────────────────────"
    
    if [[ $ASSERT_FAIL_COUNT -gt 0 ]]; then
        return 1
    fi
    return 0
}

# assert_to_json  — 导出 JSON 报告
assert_to_json() {
    local output_file="${1:-tests/results/report.json}"
    mkdir -p "$(dirname "$output_file")"
    
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local status="success"
    [[ $ASSERT_FAIL_COUNT -gt 0 ]] && status="failed"
    
    cat > "$output_file" <<EOF
{
  "timestamp": "$timestamp",
  "summary": {
    "passed": $ASSERT_PASS_COUNT,
    "failed": $ASSERT_FAIL_COUNT,
    "skipped": $ASSERT_SKIP_COUNT,
    "total": $((ASSERT_PASS_COUNT + ASSERT_FAIL_COUNT + ASSERT_SKIP_COUNT))
  },
  "status": "$status",
  "results": [
$(IFS=','; echo "${ASSERT_JSON_RESULTS[*]}")
  ]
}
EOF
    echo -e "${CYAN}JSON report: $output_file${NC}"
}
