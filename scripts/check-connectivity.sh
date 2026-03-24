#!/usr/bin/env bash
# =============================================================================
# Check Connectivity — 网络连通性检测
# Tests reachability of all registries and external services used by HomeLab.
#
# Usage: ./scripts/check-connectivity.sh
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

PASS=0; SLOW=0; FAIL=0

# ---------------------------------------------------------------------------
# Test a single endpoint
# ---------------------------------------------------------------------------
check_endpoint() {
  local name="$1"
  local host="$2"
  local url="${3:-https://$host}"

  local start end elapsed_ms
  start=$(date +%s%N)

  if curl -sf --connect-timeout 5 --max-time 10 -o /dev/null "$url" 2>/dev/null; then
    end=$(date +%s%N)
    elapsed_ms=$(( (end - start) / 1000000 ))

    if [[ $elapsed_ms -lt 500 ]]; then
      echo -e "  ${GREEN}[OK]${NC}   $name ($host) — ${elapsed_ms}ms"
      ((PASS++))
    else
      echo -e "  ${YELLOW}[SLOW]${NC} $name ($host) — ${elapsed_ms}ms ⚠️  suggest enabling mirror"
      ((SLOW++))
    fi
  else
    echo -e "  ${RED}[FAIL]${NC} $name ($host) — connection timeout ✗ needs CN mirror"
    ((FAIL++))
  fi
}

# ---------------------------------------------------------------------------
# DNS resolution check
# ---------------------------------------------------------------------------
check_dns() {
  local host="$1"
  if nslookup "$host" &>/dev/null || host "$host" &>/dev/null || dig +short "$host" &>/dev/null; then
    echo -e "  ${GREEN}[OK]${NC}   DNS resolution ($host)"
    ((PASS++))
  else
    echo -e "  ${RED}[FAIL]${NC} DNS resolution ($host) — DNS may be blocked or misconfigured"
    ((FAIL++))
  fi
}

# ---------------------------------------------------------------------------
# Outbound port check
# ---------------------------------------------------------------------------
check_port() {
  local port="$1"
  local host="${2:-hub.docker.com}"

  if timeout 5 bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null; then
    echo -e "  ${GREEN}[OK]${NC}   Outbound port $port ($host)"
    ((PASS++))
  else
    echo -e "  ${RED}[FAIL]${NC} Outbound port $port ($host) — may be blocked by firewall"
    ((FAIL++))
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
echo ""
echo -e "${BLUE}${BOLD}=== HomeLab Stack — Network Connectivity Check ===${NC}"
echo ""

echo -e "${BOLD}[1/4] Registry Reachability${NC}"
check_endpoint "Docker Hub" "hub.docker.com" "https://hub.docker.com"
check_endpoint "GitHub" "github.com" "https://github.com"
check_endpoint "gcr.io" "gcr.io" "https://gcr.io"
check_endpoint "ghcr.io" "ghcr.io" "https://ghcr.io"
check_endpoint "Quay.io" "quay.io" "https://quay.io"
echo ""

echo -e "${BOLD}[2/4] CN Mirror Reachability${NC}"
check_endpoint "DaoCloud Mirror" "docker.m.daocloud.io" "https://docker.m.daocloud.io"
check_endpoint "Baidu Mirror" "mirror.baidubce.com" "https://mirror.baidubce.com"
check_endpoint "163 Mirror" "hub-mirror.c.163.com" "https://hub-mirror.c.163.com"
echo ""

echo -e "${BOLD}[3/4] DNS Resolution${NC}"
check_dns "hub.docker.com"
check_dns "github.com"
echo ""

echo -e "${BOLD}[4/4] Outbound Ports${NC}"
check_port 443 "hub.docker.com"
check_port 80 "hub.docker.com"
echo ""

# ---------------------------------------------------------------------------
# Summary & Recommendations
# ---------------------------------------------------------------------------
echo -e "${BLUE}${BOLD}=== Summary ===${NC}"
echo -e "  ${GREEN}OK: $PASS${NC}  ${YELLOW}SLOW: $SLOW${NC}  ${RED}FAIL: $FAIL${NC}"
echo ""

if [[ $FAIL -gt 0 ]]; then
  echo -e "${YELLOW}${BOLD}Recommendation:${NC} Detected $FAIL unreachable source(s)."
  echo -e "  Run: ${BOLD}sudo ./scripts/setup-cn-mirrors.sh${NC} to configure Docker mirror acceleration."
  echo -e "  Run: ${BOLD}./scripts/localize-images.sh --cn${NC} to replace gcr.io/ghcr.io images."
elif [[ $SLOW -gt 0 ]]; then
  echo -e "${YELLOW}Recommendation:${NC} Some sources are slow. Consider running setup-cn-mirrors.sh for better performance."
else
  echo -e "${GREEN}All endpoints reachable. No mirror configuration needed.${NC}"
fi
