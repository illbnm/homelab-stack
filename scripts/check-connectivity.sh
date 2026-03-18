#!/usr/bin/env bash
# =============================================================================
# Check Connectivity — 网络连通性检测
# Tests reachability of all container registries and critical endpoints.
# Usage: ./scripts/check-connectivity.sh
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

PASS=0; SLOW=0; FAIL=0
UNREACHABLE=()

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Network Connectivity Check — 网络连通性检测"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ─── Test function ───────────────────────────────────────────────────────────
test_endpoint() {
  local name="$1"
  local url="$2"
  local timeout="${3:-5}"

  local start end latency http_code
  start=$(date +%s%N)
  http_code=$(curl -sf -o /dev/null -w "%{http_code}" --connect-timeout "$timeout" --max-time 10 "$url" 2>/dev/null || echo "000")
  end=$(date +%s%N)
  latency=$(( (end - start) / 1000000 ))

  if [[ "$http_code" == "000" ]]; then
    echo -e "  ${RED}[FAIL]${NC} $name — connection timeout ✗"
    FAIL=$((FAIL + 1))
    UNREACHABLE+=("$name")
  elif [[ $latency -gt 1000 ]]; then
    echo -e "  ${YELLOW}[SLOW]${NC} $name — ${latency}ms ⚠️  建议开启镜像加速"
    SLOW=$((SLOW + 1))
  else
    echo -e "  ${GREEN}[OK]${NC}   $name — ${latency}ms"
    PASS=$((PASS + 1))
  fi
}

# ─── Docker Registries ───────────────────────────────────────────────────────
echo -e "${BOLD}Container Registries:${NC}"
test_endpoint "Docker Hub (hub.docker.com)" "https://hub.docker.com" 5
test_endpoint "GitHub (github.com)" "https://github.com" 5
test_endpoint "gcr.io" "https://gcr.io" 5
test_endpoint "ghcr.io" "https://ghcr.io" 5
test_endpoint "quay.io" "https://quay.io" 5

echo ""
echo -e "${BOLD}CN Mirror Sources:${NC}"
test_endpoint "DaoCloud Mirror" "https://docker.m.daocloud.io" 5
test_endpoint "163 Mirror" "https://hub-mirror.c.163.com" 5
test_endpoint "Baidu Mirror" "https://mirror.baidubce.com" 5

# ─── DNS Resolution ─────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}DNS Resolution:${NC}"
if nslookup hub.docker.com >/dev/null 2>&1; then
  echo -e "  ${GREEN}[OK]${NC}   DNS resolution — working"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}[FAIL]${NC} DNS resolution ✗"
  FAIL=$((FAIL + 1))
fi

# ─── Port Connectivity ──────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}Outbound Ports:${NC}"
for port in 80 443; do
  if curl -sf --connect-timeout 3 --max-time 5 "https://hub.docker.com" >/dev/null 2>&1; then
    echo -e "  ${GREEN}[OK]${NC}   Port $port — outbound open"
    PASS=$((PASS + 1))
  else
    echo -e "  ${YELLOW}[WARN]${NC} Port $port — may be blocked"
    SLOW=$((SLOW + 1))
  fi
done

# ─── Summary ────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  Results: ${GREEN}${PASS} OK${NC} | ${YELLOW}${SLOW} SLOW${NC} | ${RED}${FAIL} FAIL${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ $FAIL -gt 0 ]]; then
  echo ""
  echo -e "  ${YELLOW}建议: 检测到 ${FAIL} 个不可达源${NC}"
  echo "  Unreachable: ${UNREACHABLE[*]}"
  echo ""
  echo "  Run: ./scripts/setup-cn-mirrors.sh"
  echo "  Or:  ./scripts/localize-images.sh --cn"
  exit 1
elif [[ $SLOW -gt 0 ]]; then
  echo ""
  echo -e "  ${YELLOW}Some endpoints are slow — consider enabling CN mirrors${NC}"
  echo "  Run: ./scripts/setup-cn-mirrors.sh"
  exit 0
else
  echo ""
  echo -e "  ${GREEN}All endpoints reachable — direct registry access is fine${NC}"
  exit 0
fi
