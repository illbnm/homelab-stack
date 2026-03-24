#!/usr/bin/env bash
# =============================================================================
# Connectivity Check — 网络连通性检测工具
# 检测 Docker Hub、GitHub、gcr.io、ghcr.io 等关键服务的可达性
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; NC='\033[0m'

declare -A CHECKS=(
    ["hub.docker.com"]="Docker Hub"
    ["github.com"]="GitHub"
    ["gcr.io"]="gcr.io"
    ["ghcr.io"]="ghcr.io"
    ["registry.k8s.io"]="k8s registry"
    ["quay.io"]="Quay.io"
    ["k8s-gcr.io"]="k8s.gcr.io"
    ["gcr.m.daocloud.io"]="DaoCloud Mirror"
    ["docker.m.daocloud.io"]="DaoCloud Docker Mirror"
)

check_host() {
    local host="$1"
    local start end elapsed
    start=$(date +%s%N)
    if curl -sf --connect-timeout 5 --max-time 15 "https://${host}" &>/dev/null; then
        end=$(date +%s%N)
        elapsed=$(( (end - start) / 1000000 ))
        echo "OK:${elapsed}ms"
    else
        echo "FAIL:timeout"
    fi
}

check_dns() {
    local domain="$1"
    if timeout 5 nslookup "$domain" &>/dev/null; then
        echo "OK"
    else
        echo "FAIL"
    fi
}

check_port() {
    local host="$1"
    local port="$2"
    if timeout 5 bash -c "echo >/dev/tcp/${host}/${port}" 2>/dev/null; then
        echo "OK"
    else
        echo "FAIL"
    fi
}

main() {
    echo ""
    echo "========================================"
    echo "  网络连通性检测"
    echo "========================================"
    echo ""
    echo -e "${BLUE}[DNS 解析]${NC}"
    for host in "${!CHECKS[@]}"; do
        name="${CHECKS[$host]}"
        result=$(check_dns "$host")
        if [[ "$result" == "OK" ]]; then
            echo -e "  [OK]   $name ($host)"
        else
            echo -e "  [FAIL] $name ($host)"
        fi
    done

    echo ""
    echo -e "${BLUE}[HTTPS 连通性]${NC}"
    local issues=0
    for host in "${!CHECKS[@]}"; do
        name="${CHECKS[$host]}"
        result=$(check_host "$host")
        status="${result%%:*}"
        latency="${result##*:}"
        if [[ "$status" == "OK" ]]; then
            if [[ "${latency%ms}" -lt 500 ]]; then
                echo -e "  [OK]   $name — 延迟 ${latency}"
            else
                echo -e "  [SLOW] $name — 延迟 ${latency}"
            fi
        else
            echo -e "  [FAIL] $name — 连接超时"
            ((issues++))
        fi
    done

    echo ""
    echo -e "${BLUE}[关键端口]${NC}"
    local ports=("443:HTTPS" "80:HTTP")
    for entry in "${ports[@]}"; do
        port="${entry%%:*}"
        desc="${entry##*:}"
        result=$(check_port "8.8.8.8" "$port" 2>/dev/null || echo "FAIL")
        if [[ "$result" == "OK" ]]; then
            echo -e "  [OK]   $desc ($port/tcp)"
        else
            echo -e "  [BLOCKED] $desc ($port/tcp)"
        fi
    done

    echo ""
    echo -e "${BLUE}[Docker Hub 连通性]${NC}"
    if docker pull hello-world &>/dev/null; then
        echo -e "  [OK]   Docker Hub 可达"
    else
        echo -e "  [FAIL] Docker Hub 不可达 — 建议运行 ./scripts/setup-cn-mirrors.sh"
        ((issues++))
    fi

    echo ""
    if [[ $issues -gt 0 ]]; then
        echo -e "${YELLOW}检测到 ${issues} 个问题，建议运行: ./scripts/setup-cn-mirrors.sh${NC}"
    else
        echo -e "${GREEN}所有检测通过!${NC}"
    fi
}
main "$@"
