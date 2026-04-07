#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()  { echo -e "${BLUE}==>${NC} $*"; }

declare -A TEST_ENDPOINTS=(
  ["Docker Hub"]="hub.docker.com"
  ["GitHub"]="github.com"
  ["GCR"]="gcr.io"
  ["GHCR"]="ghcr.io"
  ["Docker Registry"]="registry-1.docker.io"
  ["Quay"]="quay.io"
)

test_host() {
  local name=$1
  local host=$2
  
  if ! host "$host" &> /dev/null; then
    echo -e "${RED}[FAIL]${NC} $name ($host) — DNS resolution failed"
    return 1
  fi
  
  local start_time end_time latency
  start_time=$(date +%s%3N)
  
  if timeout 10 curl -sf --connect-timeout 5 --max-time 10 "https://$host" > /dev/null 2>&1; then
    end_time=$(date +%s%3N)
    latency=$((end_time - start_time))
    
    if [[ $latency -lt 500 ]]; then
      echo -e "${GREEN}[OK]${NC}   $name ($host) — latency ${latency}ms"
      return 0
    elif [[ $latency -lt 2000 ]]; then
      echo -e "${YELLOW}[SLOW]${NC} $name ($host) — latency ${latency}ms ⚠️"
      return 2
    else
      echo -e "${YELLOW}[SLOW]${NC} $name ($host) — latency ${latency}ms ⚠️ Consider using mirrors"
      return 2
    fi
  else
    echo -e "${RED}[FAIL]${NC} $name ($host) — connection timeout ✗"
    return 1
  fi
}

test_dns() {
  log_step "Testing DNS resolution"
  local test_domains=("google.com" "github.com" "docker.com")
  local dns_ok=true
  
  for domain in "${test_domains[@]}"; do
    if host "$domain" &> /dev/null; then
      echo -e "${GREEN}[OK]${NC}   DNS resolution for $domain"
    else
      echo -e "${RED}[FAIL]${NC} DNS resolution for $domain"
      dns_ok=false
    fi
  done
  
  [[ "$dns_ok" == true ]]
}

test_ports() {
  log_step "Testing outbound ports"
  local ports=(443 80)
  local ports_ok=true
  
  for port in "${ports[@]}"; do
    if timeout 5 bash -c "echo > /dev/tcp/8.8.8.8/$port" 2>/dev/null; then
      echo -e "${GREEN}[OK]${NC}   Port $port is open"
    else
      echo -e "${YELLOW}[WARN]${NC} Port $port may be blocked"
      ports_ok=false
    fi
  done
  
  [[ "$ports_ok" == true ]]
}

detect_china() {
  log_step "Detecting network environment"
  
  if timeout 5 curl -sf https://www.google.com > /dev/null 2>&1; then
    log_info "Google accessible — likely NOT in mainland China"
    return 1
  else
    log_warn "Google not accessible — likely IN mainland China"
    return 0
  fi
}

generate_recommendations() {
  local failed_count=$1
  local slow_count=$2
  
  echo ""
  log_step "Recommendations"
  
  if [[ $failed_count -gt 0 || $slow_count -gt 0 ]]; then
    echo -e "${YELLOW}Detected connectivity issues:${NC}"
    [[ $failed_count -gt 0 ]] && echo "  • $failed_count endpoint(s) unreachable"
    [[ $slow_count -gt 0 ]] && echo "  • $slow_count endpoint(s) slow (>500ms)"
    
    echo ""
    echo -e "${BOLD}Suggested actions:${NC}"
    echo "  1. Configure Docker mirrors: sudo ./scripts/setup-cn-mirrors.sh"
    echo "  2. Localize compose files: ./scripts/localize-images.sh --cn"
    echo "  3. Use CN-aware puller: ./scripts/cn-pull.sh --stack <stack-name>"
  else
    log_info "All connectivity tests passed! Network is healthy."
  fi
}

main() {
  echo -e "${BOLD}Network Connectivity Test${NC}"
  echo "================================"
  echo ""
  
  detect_china || true
  echo ""
  test_dns || true
  echo ""
  test_ports || true
  echo ""
  
  log_step "Testing registry connectivity"
  
  local failed_count=0
  local slow_count=0
  
  for name in "${!TEST_ENDPOINTS[@]}"; do
    host="${TEST_ENDPOINTS[$name]}"
    test_host "$name" "$host"
    result=$?
    
    case $result in
      1) ((failed_count++)) || true ;;
      2) ((slow_count++)) || true ;;
    esac
  done
  
  generate_recommendations $failed_count $slow_count
  
  if [[ $failed_count -gt 2 ]]; then
    exit 1
  elif [[ $failed_count -gt 0 || $slow_count -gt 0 ]]; then
    exit 2
  else
    exit 0
  fi
}

main "$@"
