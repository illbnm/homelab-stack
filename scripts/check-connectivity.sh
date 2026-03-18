#!/usr/bin/env bash
# =============================================================================
# Check Connectivity — 网络连通性检测
# 检测 Docker Hub / GitHub / gcr.io / ghcr.io 可达性、DNS、端口
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
PASS=0; FAIL=0

check_pass() { echo -e "  ${GREEN}✓ PASS${NC} $1"; ((PASS++)); }
check_fail() { echo -e "  ${RED}✗ FAIL${NC} $1"; ((FAIL++)); }
check_warn() { echo -e "  ${YELLOW}⚠ WARN${NC} $1"; }

# HTTP 可达性检测
check_http() {
  local name=$1 url=$2
  local code
  code=$(curl -sf -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 10 "$url" 2>/dev/null || echo "000")
  if [[ "$code" != "000" ]]; then
    check_pass "$name reachable (HTTP $code)"
  else
    check_fail "$name unreachable — $url"
  fi
}

# DNS 解析检测
check_dns() {
  local host=$1
  local result
  result=$(nslookup "$host" 2>/dev/null | grep -A1 "Name:" | grep "Address" | head -1 | awk '{print $2}' || true)
  if [[ -n "$result" ]]; then
    check_pass "DNS $host → $result"
  else
    check_fail "DNS $host — resolution failed"
  fi
}

# 端口出站检测
check_port() {
  local host=$1 port=$2
  if timeout 5 bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null; then
    check_pass "Port $port outbound to $host"
  else
    check_fail "Port $port outbound to $host — blocked or timeout"
  fi
}

echo -e "\n${CYAN}=== Network Connectivity Check ===${NC}\n"

echo "[1/3] Registry Reachability"
check_http "Docker Hub" "https://hub.docker.com"
check_http "GitHub" "https://github.com"
check_http "gcr.io" "https://gcr.io"
check_http "ghcr.io" "https://ghcr.io"
check_http "quay.io" "https://quay.io"
echo ""

echo "[2/3] DNS Resolution"
check_dns "registry-1.docker.io"
check_dns "gcr.io"
check_dns "ghcr.io"
check_dns "github.com"
check_dns "production.cloudflare.docker.com"
echo ""

echo "[3/3] Outbound Ports"
check_port "registry-1.docker.io" 443
check_port "github.com" 443
check_port "gcr.io" 443
if timeout 5 bash -c "echo >/dev/tcp/registry-1.docker.io/80" 2>/dev/null; then
  check_pass "Port 80 outbound to Docker Hub"
else
  check_warn "Port 80 outbound — blocked (usually OK, HTTPS preferred)"
fi
echo ""

echo -e "${CYAN}=== Summary ===${NC}"
echo -e "  ${GREEN}PASS: $PASS${NC}  ${RED}FAIL: $FAIL${NC}"
echo ""

if [[ $FAIL -gt 0 ]]; then
  echo -e "${YELLOW}Suggestions:${NC}"
  echo "  • If Docker Hub / gcr.io / ghcr.io unreachable, you are likely in mainland China."
  echo "  • Run: ./scripts/setup-cn-mirrors.sh     # Configure Docker mirror acceleration"
  echo "  • Run: ./scripts/localize-images.sh --cn  # Replace images in compose files"
  echo "  • Consider setting HTTP_PROXY/HTTPS_PROXY in .env if you have a local proxy"
  exit 1
else
  echo -e "${GREEN}All connectivity checks passed. Direct pull should work fine.${NC}"
  exit 0
fi
