#!/usr/bin/env bash
# Test runner for homelab stack
# basic usage: ./tests/run-tests.sh --stack base

set -euo pipefail

# colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# setup dirs
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# load libs
source "$SCRIPT_DIR/lib/assert.sh"
source "$SCRIPT_DIR/lib/docker.sh"
source "$SCRIPT_DIR/lib/report.sh"

# stacks we can test
AVAILABLE_STACKS=(
    "base"
    "media"
    "storage"
    "monitoring"
    "network"
    "productivity"
    "ai"
    "sso"
    "databases"
    "notifications"
)

# 显示帮助
show_help() {
    cat <<EOF
HomeLab Stack - Integration Test Runner

用法:
    $0 --stack <name>         测试特定栈
    $0 --all                  测试所有栈
    $0 --list                 列出所有可用栈
    $0 --help                 显示此帮助信息

选项:
    --stack <name>            测试指定栈
    --all                     测试所有栈
    --json                    输出JSON格式报告
    --list                    列出可用栈
    --help                    显示帮助

示例:
    $0 --stack base           测试base栈
    $0 --all --json           测试所有栈并生成JSON报告

环境变量:
    GRAFANA_ADMIN_PASSWORD    Grafana管理员密码
    SONARR_API_KEY            Sonarr API密钥
    RADARR_API_KEY            Radarr API密钥
    NEXTCLOUD_ADMIN_PASSWORD  Nextcloud管理员密码

EOF
    exit 0
}

# 列出可用栈
list_stacks() {
    echo "可用的测试栈:"
    echo ""
    for stack in "${AVAILABLE_STACKS[@]}"; do
        if [[ -f "$PROJECT_ROOT/stacks/$stack/docker-compose.yml" ]]; then
            echo "  ✓ $stack"
        else
            echo "  ✗ $stack (未配置)"
        fi
    done
    exit 0
}

# 运行单个栈的测试
run_stack_tests() {
    local stack_name="$1"

    if [[ ! -f "$PROJECT_ROOT/stacks/$stack_name/docker-compose.yml" ]]; then
        echo -e "${RED}错误: 栈 '$stack_name' 不存在或未配置${NC}"
        return 1
    fi

    local test_file="$SCRIPT_DIR/stacks/$stack_name.test.sh"

    if [[ ! -f "$test_file" ]]; then
        echo -e "${YELLOW}警告: 栈 '$stack_name' 没有测试文件${NC}"
        return 0
    fi

    echo -e "${BLUE}运行 $stack_name 栈测试...${NC}"
    bash "$test_file"
}

# 运行所有栈的测试
run_all_tests() {
    local json_output="${1:-false}"

    echo ""
    echo "╔══════════════════════════════════════╗"
    echo "║   HomeLab Stack — Integration Tests  ║"
    echo "╚══════════════════════════════════════╝"
    echo ""

    # 初始化报告
    if [[ "$json_output" == "true" ]]; then
        init_report
    fi

    local start_time
    start_time=$(date +%s)

    local total_passed=0
    local total_failed=0
    local total_skipped=0

    for stack in "${AVAILABLE_STACKS[@]}"; do
        if [[ -f "$PROJECT_ROOT/stacks/$stack/docker-compose.yml" ]]; then
            run_stack_tests "$stack" || true

            # 累计测试结果
            total_passed=$((total_passed + TESTS_PASSED))
            total_failed=$((total_failed + TESTS_FAILED))
            total_skipped=$((total_skipped + TESTS_SKIPPED))

            # 重置计数器
            TESTS_PASSED=0
            TESTS_FAILED=0
            TESTS_SKIPPED=0
        fi
    done

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    # 打印最终报告
    print_terminal_report "$total_passed" "$total_failed" "$total_skipped" "$duration"

    # 更新JSON报告
    if [[ "$json_output" == "true" ]]; then
        update_summary "$total_passed" "$total_failed" "$total_skipped"
        generate_html_report
    fi

    # 返回退出码
    if [[ "$total_failed" -gt 0 ]]; then
        return 1
    else
        return 0
    fi
}

# 主函数
main() {
    local stack_name=""
    local test_all=false
    local json_output=false

    # 解析参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --stack)
                stack_name="$2"
                shift 2
                ;;
            --all)
                test_all=true
                shift
                ;;
            --json)
                json_output=true
                shift
                ;;
            --list)
                list_stacks
                ;;
            --help|-h)
                show_help
                ;;
            *)
                echo -e "${RED}未知选项: $1${NC}"
                show_help
                ;;
        esac
    done

    # 切换到项目根目录
    cd "$PROJECT_ROOT"

    # 运行测试
    if [[ "$test_all" == "true" ]]; then
        run_all_tests "$json_output"
    elif [[ -n "$stack_name" ]]; then
        run_stack_tests "$stack_name"
    else
        echo -e "${RED}错误: 请指定 --stack <name> 或 --all${NC}"
        show_help
    fi
}

# 运行主函数
main "$@"
