#!/usr/bin/env bash
# =============================================================================
# check-connectivity.sh — Network connectivity diagnostics
# Tests reachability of essential container registries and services
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

PASS=0
FAIL=0
SLOW=0

log_ok()   { echo -e "  ${GREEN}[OK]${NC}   $*"; ((PASS++)); }
log_fail() { echo -e "  ${RED}[FAIL]${NC} $*"; ((FAIL++)); }
log_slow() { echo -e "  ${YELLOW}[SLOW]${NC} $*"; ((SLOW++)); }

# Connectivity thresholds (milliseconds)
SLOW_THRESHOLD=1000
TIMEOUT=10

# ---------------------------------------------------------------------------
# Test endpoint with latency measurement
# ---------------------------------------------------------------------------
test_endpoint() {
  local name=$1
  local url=$2
  local description=${3:-}

  local start_time
  start_time=$(date +%s%3N)

  if curl -sf --connect-timeout 5 --max-time $TIMEOUT "$url" &>/dev/null; then
    local end_time
    end_time=$(date +%s%3N)
    local latency=$((end_time - start_time))

    if [[ $latency -gt $SLOW_THRESHOLD ]]; then
      log_slow "$name ($description) — ${latency}ms ⚠️  Network is slow"
    else
      log_ok "$name ($description) — ${latency}ms"
    fi
  else
    log_fail "$name ($description) — Connection failed"
  fi
}

# ---------------------------------------------------------------------------
# Test DNS resolution
# ---------------------------------------------------------------------------
test_dns() {
  local domain=$1
  local description=$2

  if nslookup "$domain" &>/dev/null || dig +short "$domain" &>/dev/null; then
    log_ok "DNS resolution for $domain ($description)"
  else
    log_fail "DNS resolution for $domain ($description)"
  fi
}

# ---------------------------------------------------------------------------
# Test port availability
# ---------------------------------------------------------------------------
test_port() {
  local host=$1
  local port=$2
  local description=$3

  if timeout 5 bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null; then
    log_ok "Port $port on $host ($description)"
  else
    log_fail "Port $port on $host ($description) — Port may be blocked"
  fi
}

# ---------------------------------------------------------------------------
# Test Docker Hub connectivity
# ---------------------------------------------------------------------------
test_docker_hub() {
  echo -e "\n${BLUE}[1/6] Docker Hub${NC}"

  test_endpoint "Docker Hub" "https://hub.docker.com" "Main registry"
  test_endpoint "Docker Registry" "https://registry-1.docker.io" "Image pull endpoint"

  # Test pull capability (optional, requires Docker)
  if command -v docker &>/dev/null; then
    if docker pull hello-world:latest &>/dev/null; then
      log_ok "Docker pull test — hello-world image pulled successfully"
      docker rmi hello-world:latest &>/dev/null || true
    else
      log_fail "Docker pull test — Failed to pull hello-world image"
    fi
  fi
}

# ---------------------------------------------------------------------------
# Test GitHub connectivity
# ---------------------------------------------------------------------------
test_github() {
  echo -e "\n${BLUE}[2/6] GitHub${NC}"

  test_endpoint "GitHub" "https://github.com" "Code repository"
  test_endpoint "GitHub API" "https://api.github.com" "API endpoint"
  test_endpoint "GitHub Container Registry" "https://ghcr.io" "Container images"
  test_dns "github.com" "GitHub domain"
}

# ---------------------------------------------------------------------------
# Test Google Container Registry
# ---------------------------------------------------------------------------
test_gcr() {
  echo -e "\n${BLUE}[3/6] Google Container Registry (gcr.io)${NC}"

  test_endpoint "GCR" "https://gcr.io" "Google images"
  test_endpoint "GCR Mirror" "https://gcr.m.daocloud.io" "CN mirror (DaoCloud)"

  echo -e "\n  ${YELLOW}Note:${NC} If gcr.io fails, use CN mirror: ./scripts/localize-images.sh --cn"
}

# ---------------------------------------------------------------------------
# Test Kubernetes registries
# ---------------------------------------------------------------------------
test_k8s() {
  echo -e "\n${BLUE}[4/6] Kubernetes Container Registry${NC}"

  test_endpoint "K8s GCR" "https://k8s.gcr.io" "Legacy Kubernetes images"
  test_endpoint "Registry K8S" "https://registry.k8s.io" "New Kubernetes registry"
  test_endpoint "K8s Mirror" "https://k8s.m.daocloud.io" "CN mirror (DaoCloud)"
}

# ---------------------------------------------------------------------------
# Test other container registries
# ---------------------------------------------------------------------------
test_other_registries() {
  echo -e "\n${BLUE}[5/6] Other Container Registries${NC}"

  test_endpoint "Quay.io" "https://quay.io" "Red Hat images"
  test_endpoint "Quay Mirror" "https://quay.m.daocloud.io" "CN mirror (DaoCloud)"
}

# ---------------------------------------------------------------------------
# Test DNS and ports
# ---------------------------------------------------------------------------
test_networking() {
  echo -e "\n${BLUE}[6/6] Network & DNS${NC}"

  test_dns "google.com" "Basic DNS test"
  test_dns "cloudflare.com" "Cloudflare DNS"

  # Test outbound ports
  echo -e "\n  Testing outbound ports:"
  test_port "1.1.1.1" 80 "HTTP outbound"
  test_port "1.1.1.1" 443 "HTTPS outbound"
}

# ---------------------------------------------------------------------------
# Generate recommendations
# ---------------------------------------------------------------------------
show_recommendations() {
  echo -e "\n${BOLD}=== Connectivity Report ===${NC}"
  echo -e "  ${GREEN}OK:   $PASS${NC}"
  echo -e "  ${YELLOW}SLOW: $SLOW${NC}"
  echo -e "  ${RED}FAIL: $FAIL${NC}"

  if [[ $FAIL -gt 0 || $SLOW -gt 0 ]]; then
    echo -e "\n${YELLOW}=== Recommendations ===${NC}"

    if [[ $FAIL -gt 2 ]]; then
      echo -e "  • ${RED}Multiple connection failures detected${NC}"
      echo -e "    → Run: ${BOLD}./scripts/setup-cn-mirrors.sh${NC} to configure Docker mirrors"
      echo -e "    → Run: ${BOLD}./scripts/localize-images.sh --cn${NC} to use CN image mirrors"
    fi

    if [[ $SLOW -gt 0 ]]; then
      echo -e "  • ${YELLOW}Slow network detected${NC}"
      echo -e "    → Consider using mirror acceleration"
      echo -e "    → Run: ${BOLD}./scripts/setup-cn-mirrors.sh${NC}"
    fi

    echo -e "\n  ${BLUE}For China network:${NC}"
    echo -e "    1. Run: ${BOLD}sudo ./scripts/setup-cn-mirrors.sh${NC}"
    echo -e "    2. Run: ${BOLD}./scripts/localize-images.sh --cn${NC}"
    echo -e "    3. Re-run this script to verify improvements"
  else
    echo -e "\n${GREEN}✓ Network connectivity is good!${NC}"
    echo -e "  No mirror configuration needed."
  fi

  echo ""
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  echo -e ""
  echo -e "${BOLD}  HomeLab Stack — Network Connectivity Check${NC}"
  echo -e "${BOLD}  =============================================${NC}"

  test_docker_hub
  test_github
  test_gcr
  test_k8s
  test_other_registries
  test_networking

  show_recommendations

  # Exit with error code if too many failures
  if [[ $FAIL -gt 2 ]]; then
    exit 1
  fi
}

main "$@"
