#!/usr/bin/env bash
# check-connectivity.sh — Network connectivity check for homelab stack
# Usage: ./scripts/check-connectivity.sh
set -euo pipefail

# Colors
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# Thresholds (ms)
SLOW_THRESHOLD=1000

# Track failures
FAIL_COUNT=0
SLOW_COUNT=0

# Source curl_retry if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/curl_retry.sh" ]]; then
  source "$SCRIPT_DIR/curl_retry.sh"
fi

check_host() {
  local name="$1"
  local host="$2"

  local start_ms end_ms elapsed_ms
  start_ms=$(date +%s%N 2>/dev/null || date +%s)

  if curl --connect-timeout 10 --max-time 15 -s -o /dev/null "https://${host}/" 2>/dev/null; then
    end_ms=$(date +%s%N 2>/dev/null || date +%s)

    if [[ ${#start_ms} -gt 10 ]]; then
      elapsed_ms=$(( (end_ms - start_ms) / 1000000 ))
    else
      elapsed_ms=$(( (end_ms - start_ms) * 1000 ))
    fi

    if [[ $elapsed_ms -ge $SLOW_THRESHOLD ]]; then
      printf "  ${YELLOW}[SLOW]${RESET} ${BOLD}%-30s${RESET} — 延迟 %dms ⚠️  建议开启镜像加速\n" "$name" "$elapsed_ms"
      SLOW_COUNT=$((SLOW_COUNT + 1))
    else
      printf "  ${GREEN}[OK]${RESET}   ${BOLD}%-30s${RESET} — 延迟 %dms\n" "$name" "$elapsed_ms"
    fi
  else
    printf "  ${RED}[FAIL]${RESET} ${BOLD}%-30s${RESET} — 连接超时 ✗ 需要使用国内镜像\n" "$name"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

check_dns() {
  local domain="$1"
  local name="$2"

  if host "$domain" >/dev/null 2>&1 || nslookup "$domain" >/dev/null 2>&1 || getent hosts "$domain" >/dev/null 2>&1; then
    printf "  ${GREEN}[OK]${RESET}   ${BOLD}%-30s${RESET} — DNS 解析正常\n" "$name"
  else
    printf "  ${RED}[FAIL]${RESET} ${BOLD}%-30s${RESET} — DNS 解析失败 ✗\n" "$name"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

check_port() {
  local host="$1"
  local port="$2"
  local name="$3"

  if timeout 5 bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null || curl --connect-timeout 5 -s -o /dev/null "https://${host}/" 2>/dev/null; then
    printf "  ${GREEN}[OK]${RESET}   ${BOLD}%-30s${RESET} — 端口 %d 可达\n" "$name" "$port"
  else
    printf "  ${RED}[FAIL]${RESET} ${BOLD}%-30s${RESET} — 端口 %d 不可达 ✗\n" "$name" "$port"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

echo ""
echo -e "${BOLD}🔍 网络连通性检测${RESET}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo -e "${CYAN}📡 主机可达性${RESET}"
check_host "Docker Hub" "hub.docker.com"
check_host "GitHub" "github.com"
check_host "gcr.io" "gcr.io"
check_host "ghcr.io" "ghcr.io"
check_host "Quay.io" "quay.io"

echo ""
echo -e "${CYAN}🌐 DNS 解析${RESET}"
check_dns "hub.docker.com" "Docker Hub"
check_dns "github.com" "GitHub"
check_dns "gcr.io" "gcr.io"
check_dns "ghcr.io" "ghcr.io"

echo ""
echo -e "${CYAN}🔌 出站端口${RESET}"
check_port "hub.docker.com" 443 "Docker Hub:443"
check_port "hub.docker.com" 80 "Docker Hub:80"
check_port "github.com" 443 "GitHub:443"
check_port "gcr.io" 443 "gcr.io:443"
check_port "ghcr.io" 443 "ghcr.io:443"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ $FAIL_COUNT -gt 0 ]]; then
  echo -e "  ${RED}建议: 检测到 ${FAIL_COUNT} 个不可达源，建议运行 ./scripts/setup-cn-mirrors.sh${RESET}"
  echo ""
  exit 1
elif [[ $SLOW_COUNT -gt 0 ]]; then
  echo -e "  ${YELLOW}建议: 检测到 ${SLOW_COUNT} 个慢连接，建议开启镜像加速${RESET}"
  echo ""
  exit 0
else
  echo -e "  ${GREEN}✅ 所有检测通过${RESET}"
  echo ""
  exit 0
fi
