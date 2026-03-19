#!/bin/bash
# report.sh - 结果输出 (JSON + 终端彩色) for HomeLab Stack Integration Tests
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 测试结果数组
declare -a TEST_RESULTS=()
declare -i TOTAL_TESTS=0
declare -i PASSED_TESTS=0
declare -i FAILED_TESTS=0
declare -i SKIPPED_TESTS=0

# 记录测试结果
record_result() {
    local test_name="$1"
    local status="$2"  # PASS, FAIL, SKIP
    local duration="$3"
    local message="${4:-}"
    
    ((TOTAL_TESTS++))
    
    case "$status" in
        PASS) ((PASSED_TESTS++)) ;;
        FAIL) ((FAILED_TESTS++)) ;;
        SKIP) ((SKIPPED_TESTS++)) ;;
    esac
    
    TEST_RESULTS+=("{\"name\":\"$test_name\",\"status\":\"$status\",\"duration\":\"$duration\",\"message\":\"$message\"}")
}

# 打印单个测试结果
print_test_result() {
    local stack="$1"
    local test_name="$2"
    local status="$3"
    local duration="$4"
    
    case "$status" in
        PASS)
            echo -e "${GREEN}✅ PASS${NC} (${duration}s)"
            ;;
        FAIL)
            echo -e "${RED}❌ FAIL${NC} (${duration}s)"
            ;;
        SKIP)
            echo -e "${YELLOW}⏭️ SKIP${NC} (${duration}s)"
            ;;
    esac
}

# 打印测试头
print_header() {
    local title="$1"
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}   ${BLUE}${title}${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# 打印测试分隔线
print_separator() {
    echo -e "${BLUE}──────────────────────────────────────────────────────${NC}"
}

# 打印最终摘要
print_summary() {
    local duration="${1:-0}"
    
    echo ""
    print_separator
    echo -e "Results: ${GREEN}✅ ${PASSED_TESTS} passed${NC}, ${RED}❌ ${FAILED_TESTS} failed${NC}, ${YELLOW}⏭️ ${SKIPPED_TESTS} skipped${NC}"
    echo -e "Total: ${TOTAL_TESTS} tests"
    echo -e "Duration: ${duration}s"
    print_separator
    echo ""
}

# 生成 JSON 报告
generate_json_report() {
    local output_dir="$1"
    local stack_name="${2:-all}"
    local duration="${3:-0}"
    
    mkdir -p "$output_dir"
    
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local json_file="$output_dir/report_${stack_name}_$(date +%Y%m%d_%H%M%S).json"
    
    cat > "$json_file" << EOF
{
  "timestamp": "$timestamp",
  "stack": "$stack_name",
  "duration": $duration,
  "summary": {
    "total": $TOTAL_TESTS,
    "passed": $PASSED_TESTS,
    "failed": $FAILED_TESTS,
    "skipped": $SKIPPED_TESTS
  },
  "tests": [
    $(IFS=,; echo "${TEST_RESULTS[*]}")
  ]
}
EOF
    
    echo -e "${BLUE}📄 JSON report written to:${NC} $json_file"
}

# 重置计数器
reset_counters() {
    TEST_RESULTS=()
    TOTAL_TESTS=0
    PASSED_TESTS=0
    FAILED_TESTS=0
    SKIPPED_TESTS=0
}

# 导出所有函数
export -f record_result print_test_result print_header print_separator print_summary
export -f generate_json_report reset_counters
