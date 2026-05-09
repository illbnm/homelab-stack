#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Network Connectivity Check
# Tests reachability to all required registries and services.
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RESET='\033[0m'

PASS=0; FAIL=0; WARN=0; SLOW=0

check() {
  local name="$1" url="$2" expected_code="${3:-200}"
  local start end latency result code
  
  start=$(date +%s%N 2>/dev/null || echo 0)
  result=$(curl -skL --connect-timeout 5 --max-time 10 -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
  end=$(date +%s%N 2>/dev/null || echo 0)
  
  if [ "$start" != "0" ] && [ "$end" != "0" ]; then
    latency=$(( (end - start) / 1000000 ))
  else
    latency=0
  fi
  
  if [ "$result" = "000" ] || [ "$result" = "000" ]; then
    echo -e "  ${RED}[FAIL]${RESET} $name ($url) — 连接超时 ✗"
    ((FAIL++))
  elif [ "$latency" -gt 1000 ] 2>/dev/null; then
    echo -e "  ${YELLOW}[SLOW]${RESET} $name ($url) — 延迟 ${latency}ms ⚠️ 建议使用镜像加速"
    ((SLOW++))
  else
    echo -e "  ${GREEN}[OK]${RESET}   $name ($url) — 延迟 ${latency}ms"
    ((PASS++))
  fi
}

echo -e "${CYAN}╔══════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║   Network Connectivity Check        ║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════╝${RESET}"
echo ""

echo "── Registry Reachability ──"
check "Docker Hub"       "https://hub.docker.com/"
check "GitHub"           "https://github.com/"
check "ghcr.io"          "https://ghcr.io/"
check "gcr.io"           "https://gcr.io/"
check "quay.io"          "https://quay.io/"
check "DaoCloud Mirror"  "https://docker.m.daocloud.io/"
check "USTC Mirror"      "https://docker.mirrors.ustc.edu.cn/"

echo ""
echo "── DNS Resolution ──"
for domain in hub.docker.com github.com ghcr.io gcr.io baidu.com; do
  if nslookup "$domain" > /dev/null 2>&1 || dig +short "$domain" > /dev/null 2>&1; then
    echo -e "  ${GREEN}[OK]${RESET}   DNS: $domain"
  else
    echo -e "  ${RED}[FAIL]${RESET} DNS: $domain"
    ((FAIL++))
  fi
done

echo ""
echo "── Port Checks ──"
for port in 80 443 22; do
  if ss -tuln 2>/dev/null | grep -q ":$port " || netstat -tuln 2>/dev/null | grep -q ":$port "; then
    echo -e "  ${YELLOW}[IN USE]${RESET} Port $port — may conflict with Traefik/SSH"
  else
    echo -e "  ${GREEN}[FREE]${RESET}  Port $port"
  fi
done

echo ""
echo -e "${CYAN}═══════════════════════════════════${RESET}"
echo -e "  ${GREEN}OK: $PASS${RESET}  ${YELLOW}Slow: $SLOW${RESET}  ${RED}Failed: $FAIL${RESET}"
echo -e "${CYAN}═══════════════════════════════════${RESET}"

if [ $FAIL -gt 0 ]; then
  echo ""
  echo "💡 Suggestion: Run ./scripts/setup-cn-mirrors.sh --apply"
fi

if [ $SLOW -gt 0 ]; then
  echo "💡 Suggestion: Consider running ./scripts/localize-images.sh --cn"
fi

exit $FAIL
