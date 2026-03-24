#!/usr/bin/env bash
# run-tests.sh - Homelab 集成测试主运行器
# 执行所有 Stack 的集成测试并生成报告

set -euo pipefail

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# 加载库
source "$SCRIPT_DIR/lib/assert.sh"
source "$SCRIPT_DIR/lib/docker.sh"

# 配置
REPORT_DIR="$SCRIPT_DIR/reports"
JUNIT_REPORT="$REPORT_DIR/junit.xml"
TEST_RESULTS=()
START_TIME=$(date +%s)

# 打印横幅
print_banner() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║         Homelab Integration Test Framework                ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# 打印测试头
print_test_header() {
    local name="$1"
    echo -e "\n${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${BLUE}  测试：$name${NC}"
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# 打印测试结果摘要
print_summary() {
    local total=$1
    local passed=$2
    local failed=$3
    local skipped=$4
    local duration=$5
    
    echo -e "\n${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${CYAN}  测试摘要${NC}"
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  总计：  $total"
    echo -e "  ${GREEN}通过：  $passed${NC}"
    echo -e "  ${RED}失败：  $failed${NC}"
    echo -e "  ${YELLOW}跳过：  $skipped${NC}"
    echo -e "  耗时：  ${duration}s"
    echo ""
    
    if [[ $failed -eq 0 ]]; then
        echo -e "${GREEN}${BOLD}  ✓ 所有测试通过！${NC}"
    else
        echo -e "${RED}${BOLD}  ✗ 有测试失败${NC}"
    fi
}

# 生成 JUnit XML 报告
generate_junit_report() {
    local report_file="$1"
    shift
    local results=("$@")
    
    mkdir -p "$(dirname "$report_file")"
    
    local total=${#results[@]}
    local passed=0
    local failed=0
    local skipped=0
    local failures=""
    
    for result in "${results[@]}"; do
        local name=$(echo "$result" | cut -d'|' -f1)
        local status=$(echo "$result" | cut -d'|' -f2)
        local message=$(echo "$result" | cut -d'|' -f3-)
        
        case "$status" in
            PASS) ((passed++)) ;;
            FAIL) 
                ((failed++))
                failures+="      <failure message=\"$message\">$message</failure>"$'\n'
                ;;
            SKIP) ((skipped++)) ;;
        esac
    done
    
    cat > "$report_file" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="Homelab Integration Tests" tests="$total" failures="$failed" skipped="$skipped" timestamp="$(date -Iseconds)">
$(for result in "${results[@]}"; do
    name=$(echo "$result" | cut -d'|' -f1)
    status=$(echo "$result" | cut -d'|' -f2)
    message=$(echo "$result" | cut -d'|' -f3-)
    classname=$(echo "$name" | cut -d'.' -f1)
    
    echo "    <testcase name=\"$name\" classname=\"$classname\">"
    if [[ "$status" == "FAIL" ]]; then
        echo "      <failure message=\"$message\">$message</failure>"
    elif [[ "$status" == "SKIP" ]]; then
        echo "      <skipped message=\"$message\"/>"
    fi
    echo "    </testcase>"
done)
</testsuite>
EOF
    
    echo -e "${GREEN}✓ JUnit 报告已生成：$report_file${NC}"
}

# 运行单个测试文件
run_test_file() {
    local test_file="$1"
    local test_name=$(basename "$test_file" .test.sh)
    
    print_test_header "$test_name"
    
    # 重置计数器
    reset_counters
    
    # 源测试文件 (它会调用断言函数)
    if bash "$test_file"; then
        local stats=$(get_assertion_stats)
        local passed=$(echo "$stats" | grep "passed=" | cut -d'=' -f2)
        local failed=$(echo "$stats" | grep "failed=" | cut -d'=' -f2)
        
        if [[ $failed -eq 0 ]]; then
            TEST_RESULTS+=("$test_name|PASS|所有断言通过")
            return 0
        else
            TEST_RESULTS+=("$test_name|FAIL|$failed 个断言失败")
            return 1
        fi
    else
        TEST_RESULTS+=("$test_name|FAIL|测试执行失败")
        return 1
    fi
}

# 主函数
main() {
    print_banner
    
    # 检查 Docker
    echo -e "${BLUE}检查环境...${NC}"
    if ! check_docker; then
        echo -e "${RED}错误：Docker 不可用，无法运行测试${NC}"
        exit 1
    fi
    
    # 查找所有测试文件
    local test_files=()
    while IFS= read -r -d '' file; do
        test_files+=("$file")
    done < <(find "$SCRIPT_DIR/stacks" -name "*.test.sh" -type f -print0 2>/dev/null | sort -z)
    
    if [[ ${#test_files[@]} -eq 0 ]]; then
        echo -e "${YELLOW}警告：未找到测试文件${NC}"
        echo "请在 tests/stacks/ 目录下创建 *.test.sh 文件"
        exit 0
    fi
    
    echo -e "${BLUE}找到 ${#test_files[@]} 个测试文件${NC}"
    
    # 运行所有测试
    local total_tests=${#test_files[@]}
    local passed_tests=0
    local failed_tests=0
    local skipped_tests=0
    
    for test_file in "${test_files[@]}"; do
        if run_test_file "$test_file"; then
            ((passed_tests++))
        else
            ((failed_tests++))
        fi
    done
    
    # 计算耗时
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    
    # 打印摘要
    print_summary "$total_tests" "$passed_tests" "$failed_tests" "$skipped_tests" "$duration"
    
    # 生成 JUnit 报告
    generate_junit_report "$JUNIT_REPORT" "${TEST_RESULTS[@]}"
    
    # 返回退出码
    if [[ $failed_tests -gt 0 ]]; then
        exit 1
    fi
    exit 0
}

# 运行主函数
main "$@"
