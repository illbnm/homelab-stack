#!/bin/bash
# run-tests.sh - HomeLab Stack 集成测试入口
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/lib/assert.sh"
source "$SCRIPT_DIR/lib/report.sh"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 全局变量
START_TIME=$(date +%s)
TOTAL_ASSERTIONS_PASSED=0
TOTAL_ASSERTIONS_FAILED=0
TOTAL_ASSERTIONS_SKIPPED=0

show_help() {
    cat << EOF
╔════════════════════════════════════════════════════╗
║   HomeLab Stack Integration Tests                  ║
╚════════════════════════════════════════════════════╝

用法：$0 [选项]

选项:
  --stack <name>    运行指定 stack 测试 (base, media, storage, monitoring, 
                    network, productivity, ai, sso, databases, notifications)
  --all             运行所有测试
  --json            输出 JSON 报告
  --help            显示帮助

可用 Stack:
  base          - 基础设施 (Traefik, Portainer, Watchtower)
  media         - 媒体栈 (Jellyfin, Sonarr, Radarr, qBittorrent)
  storage       - 存储栈 (Nextcloud, Samba, Syncthing)
  monitoring    - 监控栈 (Grafana, Prometheus, Alertmanager)
  network       - 网络栈 (AdGuard, Pi-hole, WireGuard)
  productivity  - 生产力工具 (Gitea, n8n, Paperless)
  ai            - AI 栈 (Ollama, Open WebUI, LocalAI)
  sso           - SSO (Authentik)
  databases     - 数据库 (PostgreSQL, MySQL, MongoDB, Redis)
  notifications - 通知 (Gotify, ntfy, Apprise)

示例:
  $0 --stack base              # 运行 base stack 测试
  $0 --all                     # 运行所有测试
  $0 --stack media --json      # 运行 media 测试并输出 JSON 报告

EOF
}

run_stack_tests() {
    local stack="$1"
    local test_file="$SCRIPT_DIR/stacks/${stack}.test.sh"
    
    if [[ ! -f "$test_file" ]]; then
        echo -e "${YELLOW}⚠️  Test file not found: $test_file${NC}"
        return 0
    fi
    
    echo -e "${CYAN}Running tests for stack: ${BLUE}$stack${NC}"
    echo ""
    
    # 重置计数器
    reset_counters
    
    #  sourcing 测试文件并运行
    source "$test_file"
    
    # 运行对应的测试函数
    local test_func="run_${stack}_tests"
    if declare -f "$test_func" > /dev/null; then
        $test_func
    else
        echo -e "${RED}❌ Test function not found: $test_func${NC}"
        return 1
    fi
    
    # 累加结果
    TOTAL_ASSERTIONS_PASSED=$((TOTAL_ASSERTIONS_PASSED + ASSERTIONS_PASSED))
    TOTAL_ASSERTIONS_FAILED=$((TOTAL_ASSERTIONS_FAILED + ASSERTIONS_FAILED))
    TOTAL_ASSERTIONS_SKIPPED=$((TOTAL_ASSERTIONS_SKIPPED + ASSERTIONS_SKIPPED))
}

run_all_tests() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}   ${BLUE}HomeLab Stack — Full Integration Tests${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    local stacks=("base" "media" "storage" "monitoring" "network" 
                  "productivity" "ai" "sso" "databases" "notifications")
    
    for stack in "${stacks[@]}"; do
        run_stack_tests "$stack"
        echo ""
        echo -e "${BLUE}──────────────────────────────────────────────────────${NC}"
        echo ""
    done
    
    # 运行 E2E 测试
    echo -e "${CYAN}Running E2E tests...${NC}"
    run_e2e_tests
}

run_e2e_tests() {
    local e2e_dir="$SCRIPT_DIR/e2e"
    
    if [[ ! -d "$e2e_dir" ]]; then
        echo -e "${YELLOW}⚠️  E2E directory not found${NC}"
        return 0
    fi
    
    reset_counters
    
    for test_file in "$e2e_dir"/*.test.sh; do
        if [[ -f "$test_file" ]]; then
            source "$test_file"
            
            # 获取测试文件名（不含路径和扩展名）
            local test_name=$(basename "$test_file" .test.sh)
            local test_func="run_${test_name//-/_}_tests"
            
            if declare -f "$test_func" > /dev/null; then
                $test_func
            fi
        fi
    done
    
    # 累加结果
    TOTAL_ASSERTIONS_PASSED=$((TOTAL_ASSERTIONS_PASSED + ASSERTIONS_PASSED))
    TOTAL_ASSERTIONS_FAILED=$((TOTAL_ASSERTIONS_FAILED + ASSERTIONS_FAILED))
    TOTAL_ASSERTIONS_SKIPPED=$((TOTAL_ASSERTIONS_SKIPPED + ASSERTIONS_SKIPPED))
}

print_final_summary() {
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}   ${BLUE}Final Test Summary${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "Results: ${GREEN}✅ ${TOTAL_ASSERTIONS_PASSED} passed${NC}, ${RED}❌ ${TOTAL_ASSERTIONS_FAILED} failed${NC}, ${YELLOW}⏭️ ${TOTAL_ASSERTIONS_SKIPPED} skipped${NC}"
    echo -e "Duration: ${duration}s"
    echo ""
    
    if [[ $TOTAL_ASSERTIONS_FAILED -gt 0 ]]; then
        echo -e "${RED}❌ Some tests failed!${NC}"
        return 1
    else
        echo -e "${GREEN}✅ All tests passed!${NC}"
        return 0
    fi
}

generate_json_report() {
    local output_dir="$SCRIPT_DIR/results"
    mkdir -p "$output_dir"
    
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    local json_file="$output_dir/report_$(date +%Y%m%d_%H%M%S).json"
    
    cat > "$json_file" << EOF
{
  "timestamp": "$timestamp",
  "duration": $duration,
  "summary": {
    "total": $((TOTAL_ASSERTIONS_PASSED + TOTAL_ASSERTIONS_FAILED + TOTAL_ASSERTIONS_SKIPPED)),
    "passed": $TOTAL_ASSERTIONS_PASSED,
    "failed": $TOTAL_ASSERTIONS_FAILED,
    "skipped": $TOTAL_ASSERTIONS_SKIPPED
  }
}
EOF
    
    echo -e "${BLUE}📄 JSON report written to:${NC} $json_file"
}

main() {
    local stack_name=""
    local run_all=false
    local output_json=false
    
    # 检查依赖
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}❌ Docker not found${NC}"
        exit 1
    fi
    
    if ! command -v curl &> /dev/null; then
        echo -e "${RED}❌ curl not found${NC}"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}❌ jq not found${NC}"
        exit 1
    fi
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --stack) stack_name="$2"; shift 2 ;;
            --all) run_all=true; shift ;;
            --json) output_json=true; shift ;;
            --help) show_help; exit 0 ;;
            *) echo -e "${RED}Unknown option: $1${NC}"; show_help; exit 1 ;;
        esac
    done
    
    if [[ "$run_all" == true ]]; then
        run_all_tests
    elif [[ -n "$stack_name" ]]; then
        run_stack_tests "$stack_name"
    else
        echo -e "${RED}Usage: $0 --stack <name> | --all | --help${NC}"
        exit 1
    fi
    
    print_final_summary
    
    if [[ "$output_json" == true ]]; then
        generate_json_report
    fi
    
    # 返回退出码
    [[ $TOTAL_ASSERTIONS_FAILED -gt 0 ]] && exit 1
    exit 0
}

main "$@"
