#!/usr/bin/env bash
# =============================================================================
# Network Connectivity Checker
# =============================================================================
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

FAILED_COUNT=0

check_url() {
  local name="$1"
  local url="$2"
  local timeout=5
  
  local out
  out=$(curl -o /dev/null -s -w "%{time_total}\n" --connect-timeout $timeout -m $timeout "$url" || echo "FAIL")
  
  if [[ "$out" == "FAIL" ]]; then
    echo -e "${RED}[FAIL]${NC} $name — 连接超时 ✗ 需要使用国内镜像"
    FAILED_COUNT=$((FAILED_COUNT + 1))
  else
    local ms
    ms=$(awk -v t="$out" 'BEGIN {print int(t * 1000)}')
    if [ "$ms" -gt 1000 ]; then
      echo -e "${YELLOW}[SLOW]${NC} $name — 延迟 ${ms}ms ⚠️ 建议开启镜像加速"
      FAILED_COUNT=$((FAILED_COUNT + 1))
    else
      echo -e "${GREEN}[OK]${NC}   $name — 延迟 ${ms}ms"
    fi
  fi
}

check_dns() {
  if command -v host &> /dev/null; then
    if host github.com &> /dev/null; then
      echo -e "${GREEN}[OK]${NC}   DNS 解析正常"
    else
      echo -e "${RED}[FAIL]${NC} DNS 解析失败"
      FAILED_COUNT=$((FAILED_COUNT + 1))
    fi
  elif command -v nslookup &> /dev/null; then
    if nslookup github.com &> /dev/null; then
      echo -e "${GREEN}[OK]${NC}   DNS 解析正常"
    else
      echo -e "${RED}[FAIL]${NC} DNS 解析失败"
      FAILED_COUNT=$((FAILED_COUNT + 1))
    fi
  else
    if ping -c 1 github.com &> /dev/null; then
      echo -e "${GREEN}[OK]${NC}   DNS 解析正常"
    else
      echo -e "${RED}[FAIL]${NC} DNS 解析失败"
      FAILED_COUNT=$((FAILED_COUNT + 1))
    fi
  fi
}

check_port() {
  local port=$1
  if curl -o /dev/null -s --connect-timeout 5 "http://portquiz.net:$port" &> /dev/null; then
    echo -e "${GREEN}[OK]${NC}   $port 出站端口开放"
  else
    if curl -o /dev/null -s --connect-timeout 5 "https://github.com" &> /dev/null && [ "$port" == "443" ]; then
      echo -e "${GREEN}[OK]${NC}   $port 出站端口开放"
    elif curl -o /dev/null -s --connect-timeout 5 "http://gnu.org" &> /dev/null && [ "$port" == "80" ]; then
      echo -e "${GREEN}[OK]${NC}   $port 出站端口开放"
    else
      echo -e "${RED}[FAIL]${NC} $port 出站端口可能受限"
    fi
  fi
}

echo "检测项目:"
check_url "Docker Hub (hub.docker.com)" "https://hub.docker.com"
check_url "GitHub (github.com)" "https://github.com"
check_url "gcr.io" "https://gcr.io"
check_url "ghcr.io" "https://ghcr.io"
check_dns
check_port 80
check_port 443

echo ""
if [ "$FAILED_COUNT" -ge 2 ]; then
  echo -e "建议: 检测到 $FAILED_COUNT 个不可达源或较慢源，建议运行 ./scripts/setup-cn-mirrors.sh"
else
  echo -e "网络连通性良好。"
fi
