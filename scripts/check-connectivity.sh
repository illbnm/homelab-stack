#!/usr/bin/env bash
# =============================================================================
# check-connectivity.sh — 网络连通性检测工具
# 检测 Docker Hub、GitHub、gcr.io、ghcr.io 等镜像源可达性
# =============================================================================
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Results
declare -A RESULTS
FAIL_COUNT=0
SLOW_COUNT=0
OK_COUNT=0

# Timing function
measure_latency() {
  local host="$1"
  local url="${2:-https://$host}"
  
  local start end duration
  start=$(date +%s%N 2>/dev/null || echo "0")
  
  if curl -sf --connect-timeout 5 --max-time 10 "$url" &>/dev/null; then
    end=$(date +%s%N 2>/dev/null || echo "0")
    # Calculate milliseconds
    duration=$(( (end - start) / 1000000 ))
    echo "$duration"
    return 0
  fi
  
  echo "-1"
  return 1
}

# Check DNS resolution
check_dns() {
  echo -e "${BLUE}[CHECK]${NC} DNS Resolution"
  
  local domains=("github.com" "hub.docker.com" "google.com" "gcr.io")
  local all_ok=true
  
  for domain in "${domains[@]}"; do
    if host -W 3 "$domain" &>/dev/null || nslookup -timeout=3 "$domain" &>/dev/null; then
      echo -e "  ${GREEN}[OK]${NC}   $domain resolved"
    else
      echo -e "  ${RED}[FAIL]${NC} $domain resolution failed"
      all_ok=false
    fi
  done
  
  if $all_ok; then
    RESULTS["dns"]="OK"
    ((OK_COUNT++))
  else
    RESULTS["dns"]="FAIL"
    ((FAIL_COUNT++))
  fi
  echo ""
}

# Check outbound ports
check_ports() {
  echo -e "${BLUE}[CHECK]${NC} Outbound Ports"
  
  # Test port 443 (HTTPS)
  if timeout 5 bash -c "echo >/dev/tcp/google.com 443" 2>/dev/null; then
    echo -e "  ${GREEN}[OK]${NC}   Port 443 (HTTPS) open"
    RESULTS["port_443"]="OK"
    ((OK_COUNT++))
  else
    echo -e "  ${RED}[FAIL]${NC} Port 443 (HTTPS) blocked"
    RESULTS["port_443"]="FAIL"
    ((FAIL_COUNT++))
  fi
  
  # Test port 80 (HTTP)
  if timeout 5 bash -c "echo >/dev/tcp/google.com 80" 2>/dev/null; then
    echo -e "  ${GREEN}[OK]${NC}   Port 80 (HTTP) open"
    RESULTS["port_80"]="OK"
    ((OK_COUNT++))
  else
    echo -e "  ${RED}[FAIL]${NC} Port 80 (HTTP) blocked"
    RESULTS["port_80"]="FAIL"
    ((FAIL_COUNT++))
  fi
  
  echo ""
}

# Check container registries
check_registries() {
  echo -e "${BLUE}[CHECK]${NC} Container Registries"
  
  declare -A registries=(
    ["hub.docker.com"]="Docker Hub"
    ["github.com"]="GitHub"
    ["gcr.io"]="Google Container Registry"
    ["ghcr.io"]="GitHub Container Registry"
    ["quay.io"]="Quay.io"
    ["lscr.io"]="LinuxServer.io"
  )
  
  for host in "${!registries[@]}"; do
    local name="${registries[$host]}"
    local url="https://$host/v2/"
    
    echo -n "  "
    
    local latency
    latency=$(measure_latency "$host" "$url")
    
    if [[ "$latency" == "-1" ]]; then
      echo -e "${RED}[FAIL]${NC} $name ($host) — connection failed"
      RESULTS["$host"]="FAIL"
      ((FAIL_COUNT++))
    elif [[ "$latency" -gt 1000 ]]; then
      echo -e "${YELLOW}[SLOW]${NC} $name ($host) — ${latency}ms ${YELLOW}⚠️${NC}"
      RESULTS["$host"]="SLOW"
      ((SLOW_COUNT++))
    else
      echo -e "${GREEN}[OK]${NC}   $name ($host) — ${latency}ms"
      RESULTS["$host"]="OK"
      ((OK_COUNT++))
    fi
  done
  
  echo ""
}

# Check China-specific mirrors
check_cn_mirrors() {
  echo -e "${BLUE}[CHECK]${NC} CN Mirror Availability (for China users)"
  
  declare -A mirrors=(
    ["docker.m.daocloud.io"]="DaoCloud Docker"
    ["ghcr.m.daocloud.io"]="DaoCloud GHCR"
    ["gcr.m.daocloud.io"]="DaoCloud GCR"
    ["hub-mirror.c.163.com"]="NetEase Docker"
    ["mirror.baidubce.com"]="Baidu Docker"
    ["mirror.gcr.io"]="GCR Mirror"
  )
  
  local available=0
  
  for host in "${!mirrors[@]}"; do
    local name="${mirrors[$host]}"
    local url="https://$host/v2/"
    
    echo -n "  "
    
    local latency
    latency=$(measure_latency "$host" "$url")
    
    if [[ "$latency" == "-1" ]]; then
      echo -e "${RED}[FAIL]${NC} $name — unreachable"
    else
      echo -e "${GREEN}[OK]${NC}   $name — ${latency}ms"
      ((available++))
    fi
  done
  
  RESULTS["cn_mirrors_available"]=$available
  echo ""
}

# Generate recommendations
generate_recommendations() {
  echo -e "${BLUE}${BOLD}=== Recommendations ===${NC}"
  echo ""
  
  local needs_cn_setup=false
  local needs_mirror=false
  
  # Check for unreachable registries
  for host in "gcr.io" "ghcr.io" "quay.io"; do
    if [[ "${RESULTS[$host]:-}" == "FAIL" ]]; then
      needs_cn_setup=true
      break
    fi
  done
  
  # Check for slow connections
  for host in "hub.docker.com" "github.com"; do
    if [[ "${RESULTS[$host]:-}" == "SLOW" || "${RESULTS[$host]:-}" == "FAIL" ]]; then
      needs_mirror=true
      break
    fi
  done
  
  if $needs_cn_setup; then
    echo -e "${YELLOW}⚠️  检测到部分镜像源不可达${NC}"
    echo ""
    echo "建议操作:"
    echo "  1. 运行镜像加速配置: ./scripts/setup-cn-mirrors.sh"
    echo "  2. 本地化镜像名称:    ./scripts/localize-images.sh --cn"
    echo ""
  fi
  
  if $needs_mirror; then
    echo -e "${YELLOW}⚠️  部分连接速度较慢${NC}"
    echo ""
    echo "建议操作:"
    echo "  - 配置 Docker 镜像加速: ./scripts/setup-cn-mirrors.sh -y"
    echo ""
  fi
  
  # Port issues
  if [[ "${RESULTS[port_443]:-}" == "FAIL" || "${RESULTS[port_80]:-}" == "FAIL" ]]; then
    echo -e "${RED}⚠️  检测到端口被阻止${NC}"
    echo ""
    echo "可能的原因:"
    echo "  - 防火墙规则限制"
    echo "  - 公司/学校网络限制"
    echo "  - 代理设置问题"
    echo ""
    echo "建议操作:"
    echo "  - 检查防火墙: sudo ufw status"
    echo "  - 配置 HTTP 代理 (如需要)"
    echo ""
  fi
  
  # DNS issues
  if [[ "${RESULTS[dns]:-}" == "FAIL" ]]; then
    echo -e "${RED}⚠️  DNS 解析失败${NC}"
    echo ""
    echo "建议操作:"
    echo "  - 更换 DNS 服务器: sudo vim /etc/resolv.conf"
    echo "  - 使用国内 DNS: 223.5.5.5 或 114.114.114.114"
    echo ""
  fi
  
  # All good
  if [[ $FAIL_COUNT -eq 0 && $SLOW_COUNT -eq 0 ]]; then
    echo -e "${GREEN}✓ 网络连接正常,无需特殊配置${NC}"
    echo ""
  fi
}

# Print summary
print_summary() {
  echo -e "${BLUE}${BOLD}=== Summary ===${NC}"
  echo ""
  echo -e "  ${GREEN}OK:   $OK_COUNT${NC}"
  echo -e "  ${YELLOW}SLOW: $SLOW_COUNT${NC}"
  echo -e "  ${RED}FAIL: $FAIL_COUNT${NC}"
  echo ""
}

# JSON output for programmatic use
json_output() {
  local json="{"
  json+="\"timestamp\":\"$(date -Iseconds)\","
  json+="\"ok\":$OK_COUNT,"
  json+="\"slow\":$SLOW_COUNT,"
  json+="\"fail\":$FAIL_COUNT,"
  json+="\"results\":{"
  
  local first=true
  for key in "${!RESULTS[@]}"; do
    $first || json+=","
    first=false
    json+="\"$key\":\"${RESULTS[$key]}\""
  done
  
  json+="}}"
  echo "$json"
}

# Usage
usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Options:
  -j, --json      Output results as JSON
  -q, --quiet     Only show failures
  -c, --cn-only   Only check CN mirrors
  -h, --help      Show this help

Examples:
  $0                  # Full connectivity check
  $0 --json           # JSON output for scripts
  $0 --cn-only        # Check CN mirrors only

Exit codes:
  0 - All checks passed
  1 - Some checks failed or slow

EOF
  exit 0
}

# Main
main() {
  local output_json=false
  local quiet=false
  local cn_only=false
  # shellcheck disable=SC2034
  while [[ $# -gt 0 ]]; do
    case $1 in
      -j|--json) output_json=true ;;
      -q|--quiet) quiet=true ;;
      -c|--cn-only) cn_only=true ;;
      -h|--help) usage ;;
      *) echo "Unknown option: $1"; usage ;;
    esac
    shift
  done
  
  echo ""
  echo -e "${BOLD}  ╔═══════════════════════════════════════╗${NC}"
  echo -e "${BOLD}  ║   Network Connectivity Checker        ║${NC}"
  echo -e "${BOLD}  ╚═══════════════════════════════════════╝${NC}"
  echo ""
  
  if $cn_only; then
    check_cn_mirrors
  else
    check_dns
    check_ports
    check_registries
    check_cn_mirrors
    print_summary
    generate_recommendations
  fi
  
  if $output_json; then
    json_output
  fi
  
  # Exit with appropriate code
  if [[ $FAIL_COUNT -gt 0 ]]; then
    exit 1
  elif [[ $SLOW_COUNT -gt 0 ]]; then
    exit 0  # Slow is OK, just a warning
  else
    exit 0
  fi
}

main "$@"
