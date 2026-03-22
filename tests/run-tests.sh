#!/bin/bash
# run-tests.sh - HomeLab Stack Integration Tests Entry Point
# 支持 --stack <name> 或 --all
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/lib/assert.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

TOTAL_PASSED=0
TOTAL_FAILED=0
TOTAL_SKIPPED=0
START_TIME=$(date +%s)

show_help() {
    cat << EOF
${CYAN}╔════════════════════════════════════════════════════╗${NC}
${CYAN}║     HomeLab Stack Integration Test Suite          ║${NC}
${CYAN}╚════════════════════════════════════════════════════╝${NC}

用法：$0 [选项]

选项:
  --stack <name>    运行指定 stack 测试 (base, media, storage, etc.)
  --all             运行所有可用测试
  --json            生成 JSON 报告
  --help            显示帮助信息

可用 Stacks:
  - base            基础设施 (Traefik, Portainer, Watchtower)
  - media           媒体栈 (Jellyfin, Sonarr, qBittorrent)
  - storage         存储栈 (Nextcloud, Samba)
  - monitoring      监控栈 (Prometheus, Grafana, Loki)
  - network         网络栈 (AdGuard, Unifi)
  - productivity    生产力工具 (Gitea, VSCode Server)
  - ai              AI 栈 (Ollama, Open WebUI)
  - sso             SSO (Authentik)
  - databases       数据库 (PostgreSQL, MySQL, Redis)
  - notifications   通知服务 (Gotify, ntfy)

示例:
  $0 --stack base              # 只运行 base 测试
  $0 --all                     # 运行所有测试
  $0 --stack base --json       # 运行并生成 JSON 报告

输出:
  - 终端彩色输出
  - JSON 报告 (tests/results/report.json)
  - 测试总结 (通过/失败/跳过)

依赖:
  - curl, jq, docker, docker compose (v2)
  - 无额外框架依赖（纯 bash）

EOF
}

run_stack_tests() {
    local stack="$1"
    local test_file="$SCRIPT_DIR/stacks/${stack}.test.sh"
    
    echo ""
    echo -e "${CYAN}════════════════════════════════════════${NC}"
    echo -e "${CYAN}  Running tests for: ${stack}${NC}"
    echo -e "${CYAN}════════════════════════════════════════${NC}"
    echo ""
    
    if [[ ! -f "$test_file" ]]; then
        echo -e "${YELLOW}⚠️  Test file not found: $test_file${NC}"
        echo -e "${YELLOW}   Skipping stack: $stack${NC}"
        ((TOTAL_SKIPPED++))
        return 0
    fi
    
    reset_counters
    source "$test_file"
    
    TOTAL_PASSED=$((TOTAL_PASSED + ASSERTIONS_PASSED))
    TOTAL_FAILED=$((TOTAL_FAILED + ASSERTIONS_FAILED))
    TOTAL_SKIPPED=$((TOTAL_SKIPPED + ASSERTIONS_SKIPPED))
}

run_all_tests() {
    echo -e "${BLUE}╔══════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  HomeLab Stack — Integration Tests  ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════╝${NC}"
    echo ""
    
    local stacks=("base" "media" "storage" "monitoring" "network" "productivity" "ai" "sso" "databases" "notifications")
    
    for stack in "${stacks[@]}"; do
        run_stack_tests "$stack"
    done
    
    print_final_summary
}

print_final_summary() {
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║            FINAL TEST SUMMARY                    ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "Results: ${GREEN}✅ ${TOTAL_PASSED} passed${NC}, ${RED}❌ ${TOTAL_FAILED} failed${NC}, ${YELLOW}⏭️ ${TOTAL_SKIPPED} skipped${NC}"
    echo -e "Duration: ${duration}s"
    echo ""
    
    # Generate JSON report
    generate_json_report "$SCRIPT_DIR/results" "all"
    
    [[ $TOTAL_FAILED -gt 0 ]] && return 1
    return 0
}

main() {
    local stack_name=""
    local run_all=false
    local generate_json=false
    
    if [[ $# -eq 0 ]]; then
        show_help
        exit 0
    fi
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --stack)
                stack_name="$2"
                shift 2
                ;;
            --all)
                run_all=true
                shift
                ;;
            --json)
                generate_json=true
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
    
    if [[ "$run_all" == true ]]; then
        run_all_tests
    elif [[ -n "$stack_name" ]]; then
        run_stack_tests "$stack_name"
        echo ""
        print_summary $TOTAL_PASSED $TOTAL_FAILED $TOTAL_SKIPPED
        if [[ "$generate_json" == true ]]; then
            generate_json_report "$SCRIPT_DIR/results" "$stack_name"
        fi
    else
        echo -e "${RED}Error: Please specify --stack <name> or --all${NC}"
        show_help
        exit 1
    fi
}

main "$@"
