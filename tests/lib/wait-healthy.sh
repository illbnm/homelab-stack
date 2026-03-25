#!/bin/bash
# wait-healthy.sh - 等待所有容器健康
# 用于 CI 环境中等待服务启动完成

set -u

TIMEOUT=120
INTERVAL=5

print_help() {
    cat << EOF
等待所有 Docker 容器健康

用法:
  $(basename "$0") [选项]

选项:
  --timeout <seconds>   超时时间 (默认：120)
  --interval <seconds>  检查间隔 (默认：5)
  --help                显示此帮助信息

EOF
}

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        --interval)
            INTERVAL="$2"
            shift 2
            ;;
        --help)
            print_help
            exit 0
            ;;
        *)
            echo "❌ 未知选项：$1"
            exit 1
            ;;
    esac
done

echo "⏳ 等待容器健康 (超时：${TIMEOUT}s)..."

start_time=$(date +%s)

while true; do
    current_time=$(date +%s)
    elapsed=$((current_time - start_time))
    
    if [[ $elapsed -ge $TIMEOUT ]]; then
        echo "❌ 超时：等待 ${TIMEOUT}s 后仍有容器未健康"
        docker ps --format "table {{.Names}}\t{{.Status}}"
        exit 1
    fi
    
    # 检查所有运行中的容器
    unhealthy=0
    while IFS= read -r container; do
        if [[ -z "$container" ]]; then
            continue
        fi
        
        health=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container" 2>/dev/null)
        status=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null)
        
        if [[ "$status" != "running" ]]; then
            echo "  ❌ $container: $status"
            unhealthy=$((unhealthy + 1))
        elif [[ "$health" == "starting" || "$health" == "unhealthy" ]]; then
            echo "  ⏳ $container: $health"
            unhealthy=$((unhealthy + 1))
        fi
    done < <(docker ps --format '{{.Names}}')
    
    if [[ $unhealthy -eq 0 ]]; then
        echo "✅ 所有容器健康!"
        exit 0
    fi
    
    sleep $INTERVAL
done
