#!/bin/bash
# run-tests.sh - HomeLab Stack Integration Tests 入口
# 用法:
#   ./tests/run-tests.sh --stack base     # 运行单个栈测试
#   ./tests/run-tests.sh --all            # 运行所有栈测试
#   ./tests/run-tests.sh --help           # 显示帮助

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
LIB_DIR="$SCRIPT_DIR/lib"
STACKS_DIR="$SCRIPT_DIR/stacks"
RESULTS_DIR="$SCRIPT_DIR/results"

# 加载库
source "$LIB_DIR/assert.sh"
source "$LIB_DIR/docker.sh"
source "$LIB_DIR/report.sh"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 全局统计
TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_SKIP=0
JSON_OUTPUT=false
VERBOSE=false

# 显示帮助
show_help() {
    cat << EOF
HomeLab Stack Integration Tests

用法:
  $0 [选项]

选项:
  --stack <name>    运行指定栈的测试 (base, media, storage, monitoring, etc.)
  --all             运行所有可用栈的测试
  --json            输出 JSON 格式结果
  --verbose         详细输出模式
  --help            显示此帮助信息

示例:
  $0 --stack base           # 测试基础栈
  $0 --all --json           # 测试所有栈并输出 JSON
  $0 --stack media --verbose  # 详细测试媒体栈

可用栈:
  base          - Traefik, Portainer, Watchtower
  media         - Jellyfin, Sonarr, Radarr, qBittorrent
  storage       - Nextcloud, Samba
  monitoring    - Prometheus, Grafana, cAdvisor
  network       - AdGuard, Unifi
  productivity  - Gitea, Ollama
  ai            - Ollama, Open WebUI
  sso           - Authentik
  databases     - PostgreSQL, MySQL, Redis
  notifications - Gotify, ntfy

EOF
}

# 解析参数
STACK_NAME=""
RUN_ALL=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --stack)
            STACK_NAME="$2"
            shift 2
            ;;
        --all)
            RUN_ALL=true
            shift
            ;;
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# 前置检查
echo -e "${BLUE}Running pre-flight checks...${NC}"

if ! check_docker; then
    echo -e "${RED}Error: Docker check failed${NC}"
    exit 1
fi

if ! check_docker_compose; then
    echo -e "${RED}Error: Docker Compose check failed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Docker and Docker Compose available${NC}"
echo ""

# 运行单个栈测试
run_stack_tests() {
    local stack="$1"
    local test_file="$STACKS_DIR/${stack}.test.sh"
    
    if [[ ! -f "$test_file" ]]; then
        echo -e "${YELLOW}Warning: Test file not found for stack '$stack': $test_file${NC}"
        ((TOTAL_SKIP++))
        return 0
    fi
    
    print_stack_header "$stack"
    
    # 加载栈特定的测试
    source "$test_file"
    
    # 运行测试函数
    if declare -f "test_${stack}_all" >/dev/null; then
        test_${stack}_all
    else
        echo -e "${YELLOW}No test_${stack}_all function found, running individual tests...${NC}"
        # 运行所有以 test_ 开头的函数
        for func in $(declare -F | grep "test_${stack}_" | awk '{print $3}'); do
            $func
        done
    fi
}

# 主逻辑
init_report

if [[ "$RUN_ALL" == true ]]; then
    echo -e "${BLUE}Running tests for all stacks...${NC}"
    
    # 查找所有测试文件
    for test_file in "$STACKS_DIR"/*.test.sh; do
        if [[ -f "$test_file" ]]; then
            stack_name=$(basename "$test_file" .test.sh)
            run_stack_tests "$stack_name"
        fi
    done
elif [[ -n "$STACK_NAME" ]]; then
    echo -e "${BLUE}Running tests for stack: $STACK_NAME${NC}"
    run_stack_tests "$STACK_NAME"
else
    echo -e "${YELLOW}No stack specified. Use --stack <name> or --all${NC}"
    show_help
    exit 1
fi

# 获取断言统计
stats=$(get_assert_stats)
eval "$stats"

TOTAL_PASS=$ASSERT_PASS
TOTAL_FAIL=$ASSERT_FAIL
TOTAL_SKIP=$ASSERT_SKIP

# 打印最终报告
finalize_report $TOTAL_PASS $TOTAL_FAIL $TOTAL_SKIP "$RESULTS_DIR"

# 退出码
if [[ $TOTAL_FAIL -gt 0 ]]; then
    exit 1
fi
exit 0
