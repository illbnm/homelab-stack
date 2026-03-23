#!/bin/bash
# report.sh - 测试结果输出 for HomeLab Stack Integration Tests
# 支持终端彩色输出和 JSON 报告

set -o pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# 测试结果数组
declare -a TEST_LOG=()
TEST_START_TIME=0

# 初始化报告
# 用法: init_report
init_report() {
    TEST_START_TIME=$(date +%s)
    TEST_LOG=()
    
    echo -e "${CYAN}${BOLD}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║   HomeLab Stack — Integration Tests    ║${NC}"
    echo -e "${CYAN}${BOLD}╚════════════════════════════════════════╝${NC}"
    echo ""
}

# 记录测试结果
# 用法: log_test <stack> <test_name> <status> [duration] [message]
log_test() {
    local stack="$1"
    local test_name="$2"
    local status="$3"  # PASS, FAIL, SKIP
    local duration="${4:-0}"
    local message="${5:-}"
    
    local icon status_color
    case "$status" in
        PASS)
            icon="✅"
            status_color="$GREEN"
            ;;
        FAIL)
            icon="❌"
            status_color="$RED"
            ;;
        SKIP)
            icon="⊘"
            status_color="$YELLOW"
            ;;
        *)
            icon="❓"
            status_color="$NC"
            ;;
    esac
    
    printf "[%-8s] ▶ %-35s ${status_color}%s %s${NC}" "$stack" "$test_name" "$icon" "$status"
    [[ $duration -gt 0 ]] && printf " (${duration}s)"
    echo ""
    
    [[ -n "$message" ]] && echo -e "   ${status_color}$message${NC}"
    
    # 添加到 JSON 日志
    TEST_LOG+=("{\"stack\":\"$stack\",\"test\":\"$test_name\",\"status\":\"$status\",\"duration\":$duration,\"message\":\"$message\"}")
}

# 打印分隔线
print_separator() {
    echo -e "${BLUE}──────────────────────────────────────${NC}"
}

# 打印最终报告
# 用法: finalize_report <pass_count> <fail_count> <skip_count> [output_dir]
finalize_report() {
    local pass_count="$1"
    local fail_count="$2"
    local skip_count="$3"
    local output_dir="${4:-tests/results}"
    
    local total=$((pass_count + fail_count + skip_count))
    local elapsed=$(($(date +%s) - TEST_START_TIME))
    
    print_separator
    
    echo -e "Results: ${GREEN}$pass_count passed${NC}, ${RED}$fail_count failed${NC}, ${YELLOW}$skip_count skipped${NC}"
    echo "Duration: ${elapsed}s"
    
    print_separator
    
    # 生成 JSON 报告
    mkdir -p "$output_dir"
    local report_file="$output_dir/report.json"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    cat > "$report_file" << EOF
{
  "timestamp": "$timestamp",
  "summary": {
    "total": $total,
    "passed": $pass_count,
    "failed": $fail_count,
    "skipped": $skip_count,
    "duration_seconds": $elapsed
  },
  "tests": [
    $(IFS=,; echo "${TEST_LOG[*]}")
  ]
}
EOF
    
    echo -e "${BLUE}JSON report written to: $report_file${NC}"
    
    # 如果有失败的测试，返回错误码
    [[ $fail_count -gt 0 ]] && return 1
    return 0
}

# 打印堆栈标题
# 用法: print_stack_header <stack_name>
print_stack_header() {
    local stack="$1"
    echo ""
    echo -e "${BOLD}${BLUE}═══ Stack: ${stack} ═══${NC}"
    echo ""
}

# 打印错误详情
# 用法: print_error_detail <message> <details>
print_error_detail() {
    local message="$1"
    local details="$2"
    
    echo -e "${RED}Error: $message${NC}"
    if [[ -n "$details" ]]; then
        echo -e "${YELLOW}Details:${NC}"
        echo "$details" | sed 's/^/  /'
    fi
    echo ""
}
