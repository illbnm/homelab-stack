#!/bin/bash
# run-tests.sh - HomeLab Stack 集成测试入口
# 支持 --stack <name> 或 --all 运行测试

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# 导入库
source "$SCRIPT_DIR/lib/assert.sh"
source "$SCRIPT_DIR/lib/docker.sh"
source "$SCRIPT_DIR/lib/report.sh"

# 默认配置
RUN_STACK=""
RUN_ALL=false
JSON_OUTPUT=false
JUNIT_OUTPUT=false
VERBOSE=false
CN_MODE=false

# 打印帮助
print_help() {
    cat << EOF
HomeLab Stack Integration Tests

用法：
  $(basename "$0") [选项]

选项:
  --stack <name>    运行指定栈的测试 (base, media, storage, monitoring, network, 
                    productivity, ai, home-automation, sso, dashboard, notifications, databases)
  --all             运行所有可用栈的测试
  --json            输出 JSON 格式报告
  --junit           输出 JUnit XML 格式报告 (用于 CI)
  --cn              启用中国网络适配测试
  --verbose, -v     详细输出模式
  --help, -h        显示此帮助信息

示例:
  $(basename "$0") --stack base           # 仅测试基础栈
  $(basename "$0") --all --json           # 测试所有栈并输出 JSON 报告
  $(basename "$0") --stack sso --junit    # 测试 SSO 栈并输出 JUnit 报告

可用栈:
  base            - 基础设施 (Traefik, Portainer, Watchtower)
  media           - 媒体栈 (Jellyfin, Sonarr, Radarr, etc.)
  storage         - 存储栈 (Nextcloud, MinIO, FileBrowser)
  monitoring      - 监控栈 (Grafana, Prometheus, Loki)
  network         - 网络栈 (AdGuard, WireGuard, Nginx Proxy Manager)
  productivity    - 生产力工具 (Gitea, Vaultwarden, Outline)
  ai              - AI 栈 (Ollama, Open WebUI, LocalAI)
  home-automation - 智能家居 (Home Assistant, Node-RED, Zigbee2MQTT)
  sso             - 单点登录 (Authentik)
  dashboard       - 仪表板 (Homepage, Heimdall)
  notifications   - 通知服务 (Gotify, Ntfy, Apprise)
  databases       - 数据库 (PostgreSQL, Redis, MariaDB)

输出:
  测试结果会输出到终端，同时可生成 JSON/JUnit 报告
  默认报告路径：tests/results/report.json
  JUnit 报告路径：tests/results/junit.xml

依赖:
  - curl
  - jq
  - docker
  - docker compose (v2)

EOF
}

# 解析参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --stack)
                RUN_STACK="$2"
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
            --junit)
                JUNIT_OUTPUT=true
                shift
                ;;
            --cn)
                CN_MODE=true
                shift
                ;;
            --verbose|-v)
                VERBOSE=true
                shift
                ;;
            --help|-h)
                print_help
                exit 0
                ;;
            *)
                echo "❌ 未知选项：$1"
                echo "使用 --help 查看用法"
                exit 1
                ;;
        esac
    done
}

# 检查依赖
check_dependencies() {
    local missing=()
    
    for cmd in curl jq docker; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if ! docker compose version &> /dev/null; then
        missing+=("docker compose v2")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "❌ 缺少依赖：${missing[*]}"
        echo "请安装后重试"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        echo "❌ Docker 未运行"
        exit 1
    fi
}

# 运行基础栈测试
run_base_tests() {
    CURRENT_STACK="base"
    print_stack_header "$CURRENT_STACK"
    
    source "$SCRIPT_DIR/stacks/base.test.sh"
    
    test_traefik_running
    test_traefik_health
    test_traefik_dashboard
    test_portainer_running
    test_portainer_http
    test_watchtower_running
    test_compose_syntax_base
    test_no_latest_tags_base
}

# 运行媒体栈测试
run_media_tests() {
    CURRENT_STACK="media"
    print_stack_header "$CURRENT_STACK"
    
    if [[ -f "$SCRIPT_DIR/stacks/media.test.sh" ]]; then
        source "$SCRIPT_DIR/stacks/media.test.sh"
        
        test_jellyfin_running
        test_jellyfin_http
        test_sonarr_running
        test_sonarr_api
        test_radarr_running
        test_qbittorrent_running
    else
        echo -e "${YELLOW}⚠️  Media tests not implemented yet${NC}"
    fi
}

# 运行存储栈测试
run_storage_tests() {
    CURRENT_STACK="storage"
    print_stack_header "$CURRENT_STACK"
    
    if [[ -f "$SCRIPT_DIR/stacks/storage.test.sh" ]]; then
        source "$SCRIPT_DIR/stacks/storage.test.sh"
        
        test_nextcloud_running
        test_nextcloud_http
        test_minio_running
        test_minio_http
    else
        echo -e "${YELLOW}⚠️  Storage tests not implemented yet${NC}"
    fi
}

# 运行监控栈测试
run_monitoring_tests() {
    CURRENT_STACK="monitoring"
    print_stack_header "$CURRENT_STACK"
    
    if [[ -f "$SCRIPT_DIR/stacks/monitoring.test.sh" ]]; then
        source "$SCRIPT_DIR/stacks/monitoring.test.sh"
        
        test_grafana_running
        test_grafana_http
        test_prometheus_running
        test_prometheus_http
        test_prometheus_scrape
    else
        echo -e "${YELLOW}⚠️  Monitoring tests not implemented yet${NC}"
    fi
}

# 运行网络栈测试
run_network_tests() {
    CURRENT_STACK="network"
    print_stack_header "$CURRENT_STACK"
    
    if [[ -f "$SCRIPT_DIR/stacks/network.test.sh" ]]; then
        source "$SCRIPT_DIR/stacks/network.test.sh"
        
        test_adguard_running
        test_adguard_http
        test_wireguard_running
    else
        echo -e "${YELLOW}⚠️  Network tests not implemented yet${NC}"
    fi
}

# 运行生产力栈测试
run_productivity_tests() {
    CURRENT_STACK="productivity"
    print_stack_header "$CURRENT_STACK"
    
    if [[ -f "$SCRIPT_DIR/stacks/productivity.test.sh" ]]; then
        source "$SCRIPT_DIR/stacks/productivity.test.sh"
        
        test_gitea_running
        test_gitea_api
        test_vaultwarden_running
    else
        echo -e "${YELLOW}⚠️  Productivity tests not implemented yet${NC}"
    fi
}

# 运行 AI 栈测试
run_ai_tests() {
    CURRENT_STACK="ai"
    print_stack_header "$CURRENT_STACK"
    
    if [[ -f "$SCRIPT_DIR/stacks/ai.test.sh" ]]; then
        source "$SCRIPT_DIR/stacks/ai.test.sh"
        
        test_ollama_running
        test_ollama_api
        test_openwebui_running
    else
        echo -e "${YELLOW}⚠️  AI tests not implemented yet${NC}"
    fi
}

# 运行 SSO 栈测试
run_sso_tests() {
    CURRENT_STACK="sso"
    print_stack_header "$CURRENT_STACK"
    
    if [[ -f "$SCRIPT_DIR/stacks/sso.test.sh" ]]; then
        source "$SCRIPT_DIR/stacks/sso.test.sh"
        
        test_authentik_running
        test_authentik_http
        test_authentik_api
    else
        echo -e "${YELLOW}⚠️  SSO tests not implemented yet${NC}"
    fi
}

# 运行数据库栈测试
run_databases_tests() {
    CURRENT_STACK="databases"
    print_stack_header "$CURRENT_STACK"
    
    if [[ -f "$SCRIPT_DIR/stacks/databases.test.sh" ]]; then
        source "$SCRIPT_DIR/stacks/databases.test.sh"
        
        test_postgres_running
        test_redis_running
        test_mariadb_running
    else
        echo -e "${YELLOW}⚠️  Databases tests not implemented yet${NC}"
    fi
}

# 运行通知栈测试
run_notifications_tests() {
    CURRENT_STACK="notifications"
    print_stack_header "$CURRENT_STACK"
    
    if [[ -f "$SCRIPT_DIR/stacks/notifications.test.sh" ]]; then
        source "$SCRIPT_DIR/stacks/notifications.test.sh"
        
        test_gotify_running
        test_ntfy_running
        test_apprise_running
    else
        echo -e "${YELLOW}⚠️  Notifications tests not implemented yet${NC}"
    fi
}

# 运行中国网络适配测试
run_cn_tests() {
    CURRENT_STACK="cn-adaptation"
    print_stack_header "$CURRENT_STACK"
    
    if [[ -f "$SCRIPT_DIR/stacks/cn-adaptation.test.sh" ]]; then
        source "$SCRIPT_DIR/stacks/cn-adaptation.test.sh"
        
        test_cn_image_replacement
        test_docker_mirror_config
    else
        echo -e "${YELLOW}⚠️  CN adaptation tests not implemented yet${NC}"
    fi
}

# 运行端到端测试
run_e2e_tests() {
    CURRENT_STACK="e2e"
    print_stack_header "$CURRENT_STACK"
    
    if [[ -f "$SCRIPT_DIR/e2e/sso-flow.test.sh" ]]; then
        source "$SCRIPT_DIR/e2e/sso-flow.test.sh"
        test_sso_grafana_login
    fi
    
    if [[ -f "$SCRIPT_DIR/e2e/backup-restore.test.sh" ]]; then
        source "$SCRIPT_DIR/e2e/backup-restore.test.sh"
        test_backup_restore
    fi
}

# 运行所有测试
run_all_tests() {
    run_base_tests
    run_media_tests
    run_storage_tests
    run_monitoring_tests
    run_network_tests
    run_productivity_tests
    run_ai_tests
    run_sso_tests
    run_databases_tests
    run_notifications_tests
    
    if [[ "$CN_MODE" == "true" ]]; then
        run_cn_tests
    fi
}

# 主函数
main() {
    parse_args "$@"
    
    print_header
    
    echo "🔍 检查依赖..."
    check_dependencies
    echo "✅ 依赖检查通过"
    echo ""
    
    init_assertions
    init_report
    
    local start_time=$(date +%s)
    
    if [[ -n "$RUN_STACK" ]]; then
        case "$RUN_STACK" in
            base)
                run_base_tests
                ;;
            media)
                run_media_tests
                ;;
            storage)
                run_storage_tests
                ;;
            monitoring)
                run_monitoring_tests
                ;;
            network)
                run_network_tests
                ;;
            productivity)
                run_productivity_tests
                ;;
            ai)
                run_ai_tests
                ;;
            sso)
                run_sso_tests
                ;;
            databases)
                run_databases_tests
                ;;
            notifications)
                run_notifications_tests
                ;;
            home-automation)
                echo -e "${YELLOW}⚠️  Home Automation tests not implemented yet${NC}"
                ;;
            dashboard)
                echo -e "${YELLOW}⚠️  Dashboard tests not implemented yet${NC}"
                ;;
            *)
                echo "❌ 未知栈：$RUN_STACK"
                echo "使用 --help 查看可用栈"
                exit 1
                ;;
        esac
    elif [[ "$RUN_ALL" == "true" ]]; then
        run_all_tests
    else
        echo "❌ 请指定 --stack <name> 或 --all"
        echo "使用 --help 查看用法"
        exit 1
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    local stats=$(get_assertion_stats)
    local passed=$(echo "$stats" | cut -d' ' -f1)
    local failed=$(echo "$stats" | cut -d' ' -f2)
    local skipped=$(echo "$stats" | cut -d' ' -f3)
    local total=$(echo "$stats" | cut -d' ' -f4)
    
    print_summary "$passed" "$failed" "$skipped" "$total" "$duration"
    
    if [[ $failed -gt 0 ]]; then
        print_failures
    fi
    
    # 生成报告
    local results_dir="$SCRIPT_DIR/results"
    mkdir -p "$results_dir"
    
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        generate_json_report "$results_dir/report.json" "$passed" "$failed" "$skipped" "$total" "$duration" "${RUN_STACK:-all}"
    fi
    
    if [[ "$JUNIT_OUTPUT" == "true" ]]; then
        generate_junit_report "$results_dir/junit.xml" "$passed" "$failed" "$skipped" "$total" "$duration" "${RUN_STACK:-all}"
    fi
    
    # 返回退出码
    if [[ $failed -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

# 执行主函数
main "$@"
