#!/bin/bash
# report.sh - 测试报告生成 for HomeLab Stack 集成测试

set -u

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 测试结果存储
declare -a TEST_RESULTS=()
TEST_START_TIME=0

# 初始化报告
init_report() {
    TEST_RESULTS=()
    TEST_START_TIME=$(date +%s)
}

# 记录测试结果
record_result() {
    local stack="$1"
    local test="$2"
    local status="$3"
    local duration="$4"
    local message="${5:-}"
    
    TEST_RESULTS+=("{\"stack\":\"$stack\",\"test\":\"$test\",\"status\":\"$status\",\"duration\":\"$duration\",\"message\":\"$message\"}")
}

# 打印测试头
print_header() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  HomeLab Stack — Integration Tests     ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
    echo ""
}

# 打印栈头
print_stack_header() {
    local stack="$1"
    echo ""
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BLUE}Stack: ${stack}${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
}

# 打印测试结果摘要
print_summary() {
    local passed="$1"
    local failed="$2"
    local skipped="$3"
    local total="$4"
    local duration="$5"
    
    echo ""
    echo -e "${CYAN}──────────────────────────────────────────────────${NC}"
    echo -e "${CYAN}Results:${NC}"
    
    if [[ $failed -eq 0 ]]; then
        echo -e "  ${GREEN}✅ $passed passed${NC}"
    else
        echo -e "  ${GREEN}✅ $passed passed${NC}"
        echo -e "  ${RED}❌ $failed failed${NC}"
    fi
    
    if [[ $skipped -gt 0 ]]; then
        echo -e "  ${YELLOW}⊗ $skipped skipped${NC}"
    fi
    
    echo -e "  📊 Total: $total tests"
    echo -e "  ⏱️  Duration: ${duration}s"
    echo -e "${CYAN}──────────────────────────────────────────────────${NC}"
    echo ""
}

# 生成 JSON 报告
generate_json_report() {
    local output_file="$1"
    local passed="$2"
    local failed="$3"
    local skipped="$4"
    local total="$5"
    local duration="$6"
    local stack="${7:-all}"
    
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # 创建输出目录
    mkdir -p "$(dirname "$output_file")"
    
    # 构建 JSON
    cat > "$output_file" << EOF
{
  "timestamp": "$timestamp",
  "stack": "$stack",
  "summary": {
    "passed": $passed,
    "failed": $failed,
    "skipped": $skipped,
    "total": $total,
    "duration_seconds": $duration
  },
  "tests": [
EOF
    
    # 添加测试结果
    local first=true
    for result in "${TEST_RESULTS[@]}"; do
        if [[ "$first" == "true" ]]; then
            echo "    $result" >> "$output_file"
            first=false
        else
            echo "    ,$result" >> "$output_file"
        fi
    done
    
    cat >> "$output_file" << EOF
  ]
}
EOF
    
    echo "📄 JSON report written to: $output_file"
}

# 生成 JUnit XML 报告 (用于 CI)
generate_junit_report() {
    local output_file="$1"
    local passed="$2"
    local failed="$3"
    local skipped="$4"
    local total="$5"
    local duration="$6"
    local stack="${7:-all}"
    
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    mkdir -p "$(dirname "$output_file")"
    
    cat > "$output_file" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<testsuites name="HomeLab Stack Tests" tests="$total" failures="$failed" skipped="$skipped" time="$duration" timestamp="$timestamp">
  <testsuite name="$stack" tests="$total" failures="$failed" skipped="$skipped" time="$duration">
EOF
    
    for result in "${TEST_RESULTS[@]}"; do
        local test_name=$(echo "$result" | jq -r '.test')
        local status=$(echo "$result" | jq -r '.status')
        local test_duration=$(echo "$result" | jq -r '.duration')
        local message=$(echo "$result" | jq -r '.message')
        
        echo "    <testcase name=\"$test_name\" time=\"$test_duration\">" >> "$output_file"
        
        if [[ "$status" == "FAIL" ]]; then
            echo "      <failure message=\"$message\"/>" >> "$output_file"
        elif [[ "$status" == "SKIP" ]]; then
            echo "      <skipped/>" >> "$output_file"
        fi
        
        echo "    </testcase>" >> "$output_file"
    done
    
    cat >> "$output_file" << EOF
  </testsuite>
</testsuites>
EOF
    
    echo "📄 JUnit report written to: $output_file"
}

# 打印失败详情
print_failures() {
    echo ""
    echo -e "${RED}════════════════════════════════════════${NC}"
    echo -e "${RED}Failed Tests Detail${NC}"
    echo -e "${RED}════════════════════════════════════════${NC}"
    
    for result in "${TEST_RESULTS[@]}"; do
        local status=$(echo "$result" | jq -r '.status')
        if [[ "$status" == "FAIL" ]]; then
            local test=$(echo "$result" | jq -r '.test')
            local message=$(echo "$result" | jq -r '.message')
            echo -e "${RED}❌ $test${NC}"
            echo -e "   → $message"
            echo ""
        fi
    done
}

# 检查测试是否全部通过
all_passed() {
    local failed="$1"
    [[ $failed -eq 0 ]]
}
