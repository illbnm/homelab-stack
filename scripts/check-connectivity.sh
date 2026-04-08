#!/usr/bin/env bash
# =============================================================================
# Network Connectivity Checker
# Tests connectivity to Docker registries and provides recommendations
# =============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

OK=0
SLOW=0
FAIL=0
TIMEOUT=5

log_ok()   { echo -e "  ${GREEN}[OK]${NC}   $*"; ((OK++)); }
log_slow() { echo -e "  ${YELLOW}[SLOW]${NC} $* ${YELLOW}⚠️${NC}"; ((SLOW++)); }
log_fail() { echo -e "  ${RED}[FAIL]${NC} $* ${RED}✗${NC}"; ((FAIL++)); }

check_http() {
  local url=$1
  local name=$2
  local threshold=${3:-1000}  # ms
  
  local start end duration status
  
  start=$(date +%s%3N)
  if curl -sf --connect-timeout 3 --max-time $TIMEOUT "$url" >/dev/null 2>&1; then
    end=$(date +%s%3N)
    duration=$((end - start))
    
    if [[ $duration -lt $threshold ]]; then
      log_ok "$name — 延迟 ${duration}ms"
      return 0
    else
      log_slow "$name — 延迟 ${duration}ms"
      return 1
    fi
  else
    log_fail "$name — 连接失败"
    return 2
  fi
}

check_port() {
  local host=$1
  local port=$2
  local name=$3
  
  if timeout $TIMEOUT bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null; then
    log_ok "$name (端口 $port) 开放"
    return 0
  else
    log_fail "$name (端口 $port) 不可达"
    return 2
  fi
}

check_dns() {
  local domain=$1
  
  if nslookup "$domain" >/dev/null 2>&1 || dig +short "$domain" >/dev/null 2>&1; then
    log_ok "DNS 解析: $domain"
    return 0
  else
    log_fail "DNS 解析失败: $domain"
    return 2
  fi
}

# Main execution
echo -e "\n${BOLD}${BLUE}=== 网络连通性检测 ===${NC}\n"

echo "[1/6] Docker 镜像源连通性"
check_http "https://hub.docker.com" "Docker Hub (hub.docker.com)" 800
check_http "https://gcr.io" "Google Container Registry (gcr.io)" 2000
check_http "https://ghcr.io" "GitHub Container Registry (ghcr.io)" 2000
check_http "https://quay.io" "Quay.io" 2000
echo

echo "[2/6] GitHub 访问"
check_http "https://github.com" "GitHub (github.com)" 1500
check_http "https://api.github.com" "GitHub API" 1500
echo

echo "[3/6] 国内镜像源"
check_http "https://mirror.gcr.io" "GCR 镜像 (mirror.gcr.io)" 1000
check_http "https://docker.m.daocloud.io" "DaoCloud 镜像" 1000
check_http "https://hub-mirror.c.163.com" "网易镜像" 1000
echo

echo "[4/6] DNS 解析"
check_dns "docker.io"
check_dns "github.com"
check_dns "gcr.io"
echo

echo "[5/6] 出站端口"
check_port "hub.docker.com" 443 "HTTPS (443)"
check_port "hub.docker.com" 80 "HTTP (80)"
echo

echo "[6/6] 系统时间"
if timedatectl status 2>/dev/null | grep -q "synchronized: yes"; then
  log_ok "系统时间已同步"
else
  echo -e "  ${YELLOW}[WARN]${NC} 系统时间未同步，可能影响 HTTPS 连接"
fi
echo

# Summary
echo -e "${BOLD}${BLUE}=== 检测结果 ===${NC}\n"
echo -e "  ${GREEN}OK: $OK${NC}  ${YELLOW}SLOW: $SLOW${NC}  ${RED}FAIL: $FAIL${NC}\n"

if [[ $FAIL -gt 0 ]]; then
  echo -e "${YELLOW}建议: 检测到 $FAIL 个不可达源，建议运行:${NC}"
  echo -e "  ${BOLD}./scripts/setup-cn-mirrors.sh${NC}\n"
  exit 1
elif [[ $SLOW -gt 0 ]]; then
  echo -e "${YELLOW}建议: 检测到 $SLOW 个慢速源，建议开启镜像加速${NC}\n"
  exit 0
else
  echo -e "${GREEN}所有服务可达，网络状态良好${NC}\n"
  exit 0
fi
