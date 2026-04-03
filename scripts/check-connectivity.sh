#!/usr/bin/env bash
# =============================================================================
# Check Connectivity — Test reachability of Docker registries, GitHub, etc.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

TOTAL=0; PASS=0; SLOW=0; FAIL=0

log_result() {
  local status=$1; local host=$2; local latency=$3; local extra=$4
  ((TOTAL++))
  case "$status" in
    OK)
      if [[ "$latency" -gt 800 ]]; then
        echo -e "  ${YELLOW}[SLOW]${NC} $host — ${latency}ms  ⚠️ Consider CN mirror"
        ((SLOW++)); ((PASS++))
      else
        echo -e "  ${GREEN}[OK]${NC}   $host — ${latency}ms"
        ((PASS++))
      fi
      ;;
    FAIL)  echo -e "  ${RED}[FAIL]${NC} $host — $extra"; ((FAIL++)) ;;
    WARN)  echo -e "  ${YELLOW}[WARN]${NC} $host — $extra"; ((WARN++)) ;;
  esac
}

test_http() {
  local host=$1; local path=${2:-/}; local timeout=${3:-8}
  local start_ms end_ms latency code
  start_ms=$(date +%s%3N)
  code=$(curl -sf -o /dev/null -w "%{http_code}" \
    --connect-timeout 3 --max-time "$timeout" \
    "https://${host}${path}" 2>/dev/null || echo "000")
  end_ms=$(date +%s%3N)
  latency=$((end_ms - start_ms))
  if [[ "$code" =~ ^[23] ]]; then
    echo "OK:$latency"
  else
    echo "FAIL:HTTP $code"
  fi
}

test_dns() {
  local host=$1
  local dns_result
  dns_result=$(python3 -c "import socket; socket.gethostbyname('$host')" 2>&1 || echo "FAIL")
  if [[ "$dns_result" != "FAIL" ]]; then
    echo "OK:$dns_result"
  else
    echo "FAIL:DNS resolution failed"
  fi
}

test_tcp() {
  local host=$1; local port=$2; local timeout=${3:-5}
  if timeout "$timeout" bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null; then
    echo "OK"
  else
    echo "FAIL"
  fi
}

print_header() {
  echo ""
  echo "=============================================="
  echo "  HomeLab Stack — Network Connectivity Check"
  echo "=============================================="
  echo ""
}

print_summary() {
  echo ""
  echo "=============================================="
  echo "  Summary"
  echo "=============================================="
  echo ""
  echo "  Total:  $TOTAL"
  echo -e "  ${GREEN}Passed:${NC} $PASS"
  [[ ${SLOW:-0} -gt 0 ]] && echo -e "  ${YELLOW}Slow:${NC} $SLOW"
  [[ ${FAIL:-0} -gt 0 ]] && echo -e "  ${RED}Failed:${NC} $FAIL"
  echo ""

  if [[ ${FAIL:-0} -gt 0 ]]; then
    echo -e "  ${RED}⚠️  ${FAIL} source(s) unreachable — CN adaptation recommended${NC}"
    echo ""
    echo "  Run the following to set up CN mirrors:"
    echo "    sudo ./scripts/setup-cn-mirrors.sh --cn"
    echo "    ./scripts/localize-images.sh --cn"
    return 1
  elif [[ ${SLOW:-0} -gt 0 ]]; then
    echo -e "  ${YELLOW}⚠️  ${SLOW} source(s) slow — CN mirrors may improve speed${NC}"
  else
    echo -e "  ${GREEN}✓ All sources accessible${NC}"
  fi
}

# Main connectivity tests
echo ""
echo "=== Docker Registries ==="
for host in docker.io registry-1.docker.io gcr.io ghcr.io k8s.gcr.io quay.io; do
  result=$(test_http "$host" "/v2/" 10)
  IFS=':' read -r status val <<< "$result"
  log_result "$status" "$host" "$val" ""
done

echo ""
echo "=== Chinese Mirrors ==="
for host in m.daocloud.io docker.m.daocloud.io gcr.m.daocloud.io ghcr.m.daocloud.io \
            mirror.ccs.tencentyun.com hub-mirror.c.163.com mirror.baidubce.com; do
  result=$(test_http "$host" "/v2/" 8)
  IFS=':' read -r status val <<< "$result"
  log_result "$status" "$host" "$val" ""
done

echo ""
echo "=== GitHub & Code Hosts ==="
for host in github.com api.github.com raw.githubusercontent.com; do
  result=$(test_http "$host" "/" 10)
  IFS=':' read -r status val <<< "$result"
  log_result "$status" "$host" "$val" ""
done

echo ""
echo "=== DNS Resolution ==="
for host in github.com gcr.io hub.docker.com; do
  result=$(test_dns "$host")
  IFS=':' read -r status val <<< "$result"
  if [[ "$status" == "OK" ]]; then
    echo -e "  ${GREEN}[OK]${NC}   $host -> $val"
  else
    echo -e "  ${RED}[FAIL]${NC} $host — $val"
  fi
done

echo ""
echo "=== Required Ports ==="
for host_port in "8.8.8.8:53" "1.1.1.1:53" "dns.google:443"; do
  IFS=':' read -r host port <<< "$host_port"
  result=$(test_tcp "$host" "$port" 5)
  echo -e "  ${GREEN}[OK]${NC}   $host:$port"
done

echo ""
echo "=== GitHub Hosts File Entries ==="
echo "  These entries can be added to /etc/hosts for GitHub accessibility:"
echo ""
cat <<'HOSTS_EOF'
# GitHub China accessibility (add to /etc/hosts)
140.82.112.4    github.com
140.82.112.10   api.github.com
185.199.108.133  raw.githubusercontent.com
185.199.109.133  user-images.githubusercontent.com
185.199.110.133  packages.cloud.githubusercontent.com
HOSTS_EOF
echo ""
echo "  Apply with: sudo scripts/check-connectivity.sh --apply-hosts"
