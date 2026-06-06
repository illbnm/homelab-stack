#!/bin/bash
# check-connectivity.sh - Network connectivity diagnostic for homelab-stack
# Usage: ./check-connectivity.sh
#
# Checks connectivity and latency to key services and CN mirrors.
# Use this to diagnose network issues before deploying.
#
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
fail()  { echo -e "${RED}[FAIL]${NC} $1"; }
slow()  { echo -e "${YELLOW}[SLOW]${NC} $1"; }

check_url() {
    local name="$1"; local url="$2"; local timeout="${3:-5}"
    echo -n "  $name: "
    if curl -s --connect-timeout "$timeout" --max-time $((timeout + 5)) "$url" > /dev/null 2>&1; then
        ok "reachable"
        return 0
    else
        fail "unreachable"
        return 1
    fi
}

latency() {
    local name="$1"; local url="$2"
    echo -n "  $name latency: "
    local ms
    ms=$(curl -s -o /dev/null -w "%{time_connect}" --connect-timeout 10 "$url" 2>/dev/null | awk '{printf "%.0f", $1*1000}') || ms=9999
    if   [[ $ms -lt 200 ]]; then ok  "${ms}ms"
    elif [[ $ms -lt 800 ]]; then slow "${ms}ms"
    else                        fail "${ms}ms"
    fi
}

echo "========================================"
echo "  Homelab Stack Connectivity Check"
echo "========================================"
echo ""

info "Docker Registries"
check_url "Docker Hub"      "https://hub.docker.com"
check_url "gcr.io"          "https://gcr.io"
check_url "ghcr.io"         "https://ghcr.io"
check_url "registry.k8s.io" "https://registry.k8s.io"
check_url "quay.io"         "https://quay.io"
echo ""

info "Chinese Mirrors"
check_url "Baidu BCE Mirror"   "https://mirror.baidubce.com" 8
check_url "DaoCloud Mirror"     "https://docker.m.daocloud.io" 8
check_url "Rainbond Mirror"    "https://docker.rainbond.io" 8
check_url "RatGod Mirror"      "https://hub.ratgod.dev" 8
echo ""

info "Key Services"
check_url "GitHub"           "https://github.com"
check_url "Google DNS"        "https://8.8.8.8"
check_url "Cloudflare DNS"    "https://1.1.1.1"
echo ""

info "Latency Tests"
latency "Docker Hub"  "https://registry-1.docker.io/v2/"
latency "GitHub"      "https://github.com"
latency "DaoCloud"    "https://docker.m.daocloud.io"
latency "Baidu BCE"   "https://mirror.baidubce.com"
echo ""

# Docker daemon check
info "Docker Daemon"
echo -n "  Docker version: "
if docker version > /dev/null 2>&1; then
    ok "$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo 'available')"
else
    fail "not running or not accessible"
fi

echo ""
echo "========================================"
echo "  Recommendations"
echo "========================================"
echo "  If CN mirrors are reachable but Docker Hub is slow:"
echo "    sudo ./scripts/setup-cn-mirrors.sh"
echo "    ./scripts/localize-images.sh --cn"
echo ""
echo "  If all checks fail, check your firewall/proxy settings."
echo ""
