#!/usr/bin/env bash
# =============================================================================
# Wait Healthy — Docker Compose 健康检查等待工具
# 等待所有容器通过健康检查后再继续
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; NC='\033[0m'

log_info()  { echo -e "${BLUE}[wait-healthy]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[wait-healthy]${NC} $*"; }
log_error() { echo -e "${RED}[wait-healthy]${NC} $*" >&2; }

COMPOSE_FILE=""
STACK_NAME=""
TIMEOUT=300
INTERVAL=5

usage() {
    cat <<EOF
用法: $0 [选项]

选项:
  --file <file>     指定 docker-compose 文件
  --stack <name>    指定 stack 名称 (查找对应的 compose 文件)
  --timeout <sec>   超时时间，默认 300 秒
  --interval <sec>  检查间隔，默认 5 秒
  --help            显示帮助

示例:
  $0 --file docker-compose.yml
  $0 --stack monitoring --timeout 600
  $0 --file docker-compose.yml --interval 10

EOF
}

get_compose_files() {
    if [[ -n "$COMPOSE_FILE" ]]; then
        echo "$COMPOSE_FILE"
    elif [[ -n "$STACK_NAME" ]]; then
        find "$ROOT_DIR" -maxdepth 2 -name "docker-compose.${STACK_NAME}.yml" -o -name "docker-compose.${STACK_NAME}.yaml" 2>/dev/null
    else
        find "$ROOT_DIR" -maxdepth 2 -name "docker-compose*.yml" -o -name "docker-compose*.yaml" 2>/dev/null | grep -v node_modules
    fi
}

get_container_health() {
    local compose_file="$1"
    docker compose -f "$compose_file" ps --format json 2>/dev/null | \
        python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if isinstance(data, list):
        for c in data:
            health = c.get('Health', '')
            name = c.get('Name', c.get('Service', ''))
            state = c.get('State', '')
            print(f'{name}|{state}|{health}')
    else:
        health = data.get('Health', '')
        name = data.get('Name', data.get('Service', ''))
        state = data.get('State', '')
        print(f'{name}|{state}|{health}')
except:
    pass
" 2>/dev/null || true
}

wait_for_stack() {
    local compose_file="$1"
    local elapsed=0
    local interval=$INTERVAL

    echo ""
    log_info "等待健康检查: $compose_file"
    echo "超时: ${TIMEOUT}s | 间隔: ${interval}s"
    echo ""

    while [[ $elapsed -lt $TIMEOUT ]]; do
        local all_healthy=true
        local unhealthy=()
        local container_info

        container_info=$(get_container_health "$compose_file")

        if [[ -z "$container_info" ]]; then
            log_warn "无法获取容器状态，容器可能未启动"
            sleep $interval
            elapsed=$((elapsed + interval))
            continue
        fi

        while IFS='|' read -r name state health; do
            [[ -z "$name" ]] && continue

            if [[ "$state" == "running" ]]; then
                if [[ -z "$health" ]] || [[ "$health" == "-" ]]; then
                    # 无健康检查的容器，默认健康
                    echo -e "  ${name}: ${GREEN}running${NC} (无健康检查)"
                elif [[ "$health" == "healthy" ]]; then
                    echo -e "  ${name}: ${GREEN}healthy${NC}"
                else
                    all_healthy=false
                    echo -e "  ${name}: ${YELLOW}${health}${NC}"
                    unhealthy+=("$name")
                fi
            elif [[ "$state" == "exited" ]] || [[ "$state" == "dead" ]]; then
                all_healthy=false
                echo -e "  ${name}: ${RED}${state}${NC}"
                unhealthy+=("$name")
            else
                all_healthy=false
                echo -e "  ${name}: ${YELLOW}${state}${NC}"
            fi
        done <<< "$container_info"

        if [[ "$all_healthy" == "true" ]]; then
            echo ""
            log_info "所有容器健康检查通过! (耗时: ${elapsed}s)"
            return 0
        fi

        echo -e "  等待中... (${elapsed}s / ${TIMEOUT}s)\n"
        sleep $interval
        elapsed=$((elapsed + interval))
    done

    echo ""
    log_error "超时! 以下容器未通过健康检查:"
    for c in "${unhealthy[@]}"; do
        echo "  - $c"
        echo "  最近日志:"
        docker compose -f "$compose_file" logs --tail=10 "$c" 2>/dev/null | sed 's/^/    /'
    done

    return 1
}

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --file|-f)  COMPOSE_FILE="$2"; shift 2 ;;
            --stack|-s) STACK_NAME="$2"; shift 2 ;;
            --timeout|-t) TIMEOUT="$2"; shift 2 ;;
            --interval|-i) INTERVAL="$2"; shift 2 ;;
            --help|-h)  usage; exit 0 ;;
            *)          log_error "未知选项: $1"; usage; exit 1 ;;
        esac
    done

    local compose_files
    mapfile -t compose_files < <(get_compose_files)

    if [[ ${#compose_files[@]} -eq 0 ]]; then
        log_error "未找到 docker-compose 文件"
        exit 2
    fi

    local failed=0
    for file in "${compose_files[@]}"; do
        if ! wait_for_stack "$file"; then
            ((failed++))
        fi
    done

    if [[ $failed -gt 0 ]]; then
        exit 1
    fi
    exit 0
}

main "$@"
