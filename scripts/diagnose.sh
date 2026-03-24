#!/usr/bin/env bash
# =============================================================================
# Diagnose — 一键诊断工具
# 收集系统信息、容器状态、日志，用于提交 Issue 时提供诊断报告
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_FILE="${1:-${ROOT_DIR}/diagnose-report.txt}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

exec > >(tee "$OUTPUT_FILE")
exec 2>&1

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

section() {
    echo ""
    echo "============================================================"
    echo "  $1"
    echo "============================================================"
}

main() {
    log "开始诊断报告生成..."
    log "输出文件: $OUTPUT_FILE"

    section "系统信息"
    echo "Hostname: $(hostname)"
    echo "OS: $(uname -s) $(uname -r) $(uname -m)"
    echo "发行版: $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2 || echo 'unknown')"
    echo "启动时间: $(uptime -s 2>/dev/null || uptime)"
    echo "语言环境: $LANG"

    section "硬件资源"
    echo "CPU: $(nproc) 核心"
    echo "内存总量: $(free -h | awk '/^Mem:/ {print $2}')"
    echo "内存使用: $(free -h | awk '/^Mem:/ {print $3}')"
    echo "磁盘总量: $(df -h / | awk 'NR==2 {print $2}')"
    echo "磁盘使用: $(df -h / | awk 'NR==2 {print $3}')"
    echo "磁盘可用: $(df -h / | awk 'NR==2 {print $4}')"

    section "Docker 版本"
    if command -v docker &>/dev/null; then
        docker version 2>/dev/null || echo "无法获取 Docker 版本"
    else
        echo "Docker 未安装"
    fi

    section "Docker Compose 版本"
    if docker compose version &>/dev/null; then
        docker compose version
    elif command -v docker-compose &>/dev/null; then
        docker-compose version
    else
        echo "Docker Compose 未安装"
    fi

    section "Docker 状态"
    if docker info &>/dev/null; then
        echo "Docker 守护进程: 运行中"
        echo "镜像数量: $(docker images -q 2>/dev/null | wc -l)"
        echo "容器数量: $(docker ps -aq 2>/dev/null | wc -l)"
        echo "运行中容器: $(docker ps -q 2>/dev/null | wc -l)"
        echo "暂停容器: $(docker ps --filter "status=paused" -q 2>/dev/null | wc -l)"
    else
        echo "Docker 守护进程: 未运行"
    fi

    section "所有容器状态"
    if command -v docker &>/dev/null; then
        docker compose -f "$ROOT_DIR/docker-compose.base.yml" ps 2>/dev/null || \
        docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || \
        echo "无法获取容器状态"
    fi

    section "最近错误日志 (各容器)"
    if command -v docker &>/dev/null; then
        for container in $(docker ps -aq 2>/dev/null); do
            name=$(docker inspect --format='{{.Name}}' "$container" 2>/dev/null | sed 's/^\///')
            echo ""
            echo "--- $name ---"
            docker logs --tail=20 "$container" 2>&1 | grep -iE "(error|fail|exception|critical)" | tail -10 || echo "无错误日志"
        done
    fi

    section "网络连通性"
    for host in "hub.docker.com" "github.com" "gcr.io" "ghcr.io"; do
        if timeout 5 curl -sf --max-time 10 "https://$host" &>/dev/null; then
            echo "[OK]   $host"
        else
            echo "[FAIL] $host"
        fi
    done

    section "配置文件检查"
    for f in "$ROOT_DIR/.env" "$ROOT_DIR/config/traefik/acme.json" "$ROOT_DIR/docker-compose.base.yml"; do
        if [[ -f "$f" ]]; then
            echo "存在: $f"
        else
            echo "缺失: $f"
        fi
    done

    section "目录权限"
    for d in "$ROOT_DIR/data" "$ROOT_DIR/config"; do
        if [[ -d "$d" ]]; then
            perms=$(stat -c '%a' "$d" 2>/dev/null || echo 'unknown')
            echo "$d: $perms"
        fi
    done

    section "诊断完成"
    log "报告已保存到: $OUTPUT_FILE"
    log "请将此文件内容粘贴到 Issue 中"
}

main "$@"
