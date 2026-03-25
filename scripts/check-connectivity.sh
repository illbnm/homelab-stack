#!/bin/bash
# check-connectivity.sh - Check network connectivity for homelab deployment
# Usage: ./scripts/check-connectivity.sh [--verbose]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

VERBOSE=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--verbose]"
            echo ""
            echo "Checks:"
            echo "  - Docker Hub connectivity"
            echo "  - GitHub connectivity"
            echo "  - gcr.io connectivity"
            echo "  - ghcr.io connectivity"
            echo "  - DNS resolution"
            echo "  - Common outbound ports"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

OK=0
WARN=0
FAIL=0

check_service() {
    local name="$1"
    local host="$2"
    local port="${3:-443}"
    local timeout="${4:-5}"

    local start_time=$(date +%s%3N)
    local result=$(curl -sf --connect-timeout "$timeout" --max-time "$timeout" "https://${host}" -o /dev/null 2>&1)
    local exit_code=$?
    local end_time=$(date +%s%3N)
    local latency=$((end_time - start_time))

    if [ $exit_code -eq 0 ]; then
        if [ $latency -gt 500 ]; then
            echo -e "  ${YELLOW}[SLOW]${NC} ${name} (${host}) — 延迟 ${latency}ms"
            ((WARN++)) || true
            return 1
        else
            echo -e "  ${GREEN}[OK]${NC} ${name} (${host}) — 延迟 ${latency}ms"
            ((OK++)) || true
            return 0
        fi
    else
        echo -e "  ${RED}[FAIL]${NC} ${name} (${host}) — 连接失败"
        ((FAIL++)) || true
        return 1
    fi
}

check_port() {
    local name="$1"
    local host="$2"
    local port="$3"
    local timeout="${4:-5}"

    if timeout "$timeout" bash -c "echo >/dev/tcp/${host}/${port}" 2>/dev/null; then
        echo -e "  ${GREEN}[OK]${NC} ${name} (${host}:${port})"
        ((OK++)) || true
        return 0
    else
        echo -e "  ${RED}[FAIL]${NC} ${name} (${host}:${port}) — 端口不可达"
        ((FAIL++)) || true
        return 1
    fi
}

check_dns() {
    local domain="$1"

    local result=$(dig +short "$domain" 2>/dev/null | head -1)
    if [ -n "$result" ]; then
        echo -e "  ${GREEN}[OK]${NC} DNS ${domain} — ${result}"
        ((OK++)) || true
        return 0
    else
        echo -e "  ${RED}[FAIL]${NC} DNS ${domain} — 解析失败"
        ((FAIL++)) || true
        return 1
    fi
}

main() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║     Network Connectivity Check                      ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    echo ""

    echo "=== Registry Connectivity ==="

    check_service "Docker Hub" "hub.docker.com"
    check_service "GitHub" "github.com"
    check_service "gcr.io" "gcr.io"
    check_service "ghcr.io" "ghcr.io"
    check_service " Quay.io" "quay.io"
    check_service "Google Kubernetes" "registry.k8s.io"

    echo ""
    echo "=== DNS Resolution ==="

    check_dns "docker.io"
    check_dns "github.com"
    check_dns "gcr.io"
    check_dns "ghcr.io"

    echo ""
    echo "=== Outbound Ports ==="

    check_port "HTTP" "github.com" 80 5
    check_port "HTTPS" "github.com" 443 5
    check_port "Docker Registry" "registry-1.docker.io" 443 5

    echo ""
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║     Summary                                         ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    echo ""
    echo -e "  ${GREEN}OK:${NC}    $OK"
    echo -e "  ${YELLOW}WARN:${NC}  $WARN"
    echo -e "  ${RED}FAIL:${NC}  $FAIL"
    echo ""

    if [ $FAIL -gt 0 ]; then
        echo -e "${RED}建议:${NC} 检测到 $FAIL 个不可达服务"
        echo ""
        echo "如果 gcr.io/ghcr.io 不可达，建议："
        echo "  1. 运行 ./scripts/setup-cn-mirrors.sh 配置镜像加速"
        echo "  2. 运行 ./scripts/localize-images.sh --cn 替换镜像"
        echo ""
    fi

    if [ $WARN -gt 0 ]; then
        echo -e "${YELLOW}注意:${NC} 检测到 $WARN 个服务延迟较高"
        echo "  这可能会影响首次部署速度，但不影响功能"
        echo ""
    fi

    if [ $FAIL -eq 0 ] && [ $WARN -eq 0 ]; then
        echo -e "${GREEN}所有检查通过！可以开始部署。${NC}"
    fi

    echo ""
}

main "$@"
