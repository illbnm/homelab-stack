#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Network Connectivity Checker
# Tests reachability of all required external services.
#
# Usage: ./scripts/check-connectivity.sh [--json] [--quiet]
# =============================================================================
set -euo pipefail

JSON_OUTPUT=false
QUIET=false
for arg in "$@"; do
  case "$arg" in
    --json)  JSON_OUTPUT=true ;;
    --quiet) QUIET=true ;;
    --help)  echo "Usage: $0 [--json] [--quiet]"; exit 0 ;;
  esac
done

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

# Results tracking
declare -a RESULTS_OK=()
declare -a RESULTS_SLOW=()
declare -a RESULTS_FAIL=()

# Test a host:port with timeout, return latency in ms
test_host() {
  local host="$1" port="${2:-443}" url="${3:-}"
  local start duration http_code

  if [ -n "$url" ]; then
    start=$(date +%s%N)
    http_code=$(curl -o /dev/null -s -w "%{http_code}" \
      --connect-timeout 5 --max-time 10 "$url" 2>/dev/null) || http_code="000"
    duration=$(( ($(date +%s%N) - start) / 1000000 ))
  else
    start=$(date +%s%N)
    if timeout 5 bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null; then
      duration=$(( ($(date +%s%N) - start) / 1000000 ))
      http_code="OK"
    else
      duration=0
      http_code="FAIL"
    fi
  fi

  echo "$duration|$http_code"
}

# Check DNS resolution
check_dns() {
  local result
  result=$(host -W 3 google.com 2>/dev/null | grep -c "has address" || echo 0)
  if [ "$result" -gt 0 ]; then
    echo "OK|0"
  else
    echo "FAIL|0"
  fi
}

if ! $JSON_OUTPUT; then
  echo "========================================"
  echo "  HomeLab Stack — Connectivity Check"
  echo "========================================"
  echo
fi

# Define tests: label|host|port|url
TESTS=(
  "Docker Hub|hub.docker.com|443|https://hub.docker.com/v2/"
  "GitHub|github.com|443|https://github.com"
  "GitHub Container|ghcr.io|443|https://ghcr.io/v2/"
  "Google Container|gcr.io|443|https://gcr.io/v2/"
  "Docker Registry|registry-1.docker.io|443|https://registry-1.docker.io/v2/"
  "Let's Encrypt|acme-v02.api.letsencrypt.org|443|https://acme-v02.api.letsencrypt.org/directory"
  "ntfy|ntfy.sh|443|https://ntfy.sh"
)

# Run tests
for test_def in "${TESTS[@]}"; do
  IFS='|' read -r label host port url <<< "$test_def"
  result=$(test_host "$host" "$port" "$url")
  IFS='|' read -r latency code <<< "$result"

  if [ "$code" = "FAIL" ] || [ "$code" = "000" ]; then
    RESULTS_FAIL+=("$label ($host)")
    if ! $JSON_OUTPUT; then
      printf "  ${RED}[FAIL]${NC} %-35s — 连接超时 ✗ 需要使用国内镜像\n" "$label ($host)"
    fi
  elif [ "$latency" -gt 1000 ]; then
    RESULTS_SLOW+=("$label ($host)")
    if ! $JSON_OUTPUT; then
      printf "  ${YELLOW}[SLOW]${NC} %-35s — 延迟 ${latency}ms ⚠️ 建议开启镜像加速\n" "$label ($host)"
    fi
  else
    RESULTS_OK+=("$label ($host)")
    if ! $JSON_OUTPUT; then
      printf "  ${GREEN}[OK]${NC}   %-35s — 延迟 ${latency}ms\n" "$label ($host)"
    fi
  fi
done

# DNS check
dns_result=$(check_dns)
IFS='|' read -r dns_status _ <<< "$dns_result"
if [ "$dns_status" = "OK" ]; then
  RESULTS_OK+=("DNS Resolution")
  if ! $JSON_OUTPUT; then
    printf "  ${GREEN}[OK]${NC}   %-35s — 正常\n" "DNS 解析"
  fi
else
  RESULTS_FAIL+=("DNS Resolution")
  if ! $JSON_OUTPUT; then
    printf "  ${RED}[FAIL]${NC} %-35s — 异常 ✗\n" "DNS 解析"
  fi
fi

# Outbound port check
for port in 80 443; do
  result=$(timeout 5 bash -c "echo >/dev/tcp/google.com/$port" 2>/dev/null && echo "OK" || echo "FAIL")
  if [ "$result" = "OK" ]; then
    RESULTS_OK+=("Port $port outbound")
    if ! $JSON_OUTPUT; then
      printf "  ${GREEN}[OK]${NC}   出站端口 %-24s — 开放\n" "$port"
    fi
  else
    RESULTS_FAIL+=("Port $port outbound")
    if ! $JSON_OUTPUT; then
      printf "  ${RED}[FAIL]${NC} 出站端口 %-24s — 被阻止 ✗\n" "$port"
    fi
  fi
done

# Summary
echo
fail_count=${#RESULTS_FAIL[@]}
slow_count=${#RESULTS_SLOW[@]}
ok_count=${#RESULTS_OK[@]}

if $JSON_OUTPUT; then
  echo "{"
  echo "  \"ok\": $ok_count,"
  echo "  \"slow\": $slow_count,"
  echo "  \"failed\": $fail_count,"
  echo "  \"failed_services\": [$(printf '"%s",' "${RESULTS_FAIL[@]}" | sed 's/,$//')],"
  echo "  \"slow_services\": [$(printf '"%s",' "${RESULTS_SLOW[@]}" | sed 's/,$//')]"
  echo "}"
else
  echo "========================================"
  echo "  结果: ${GREEN}${ok_count} OK${NC} | ${YELLOW}${slow_count} SLOW${NC} | ${RED}${fail_count} FAIL${NC}"
  echo "========================================"

  if [ "$fail_count" -gt 0 ] || [ "$slow_count" -gt 0 ]; then
    echo
    echo -e "${YELLOW}建议:${NC}"
    if [ "$fail_count" -gt 0 ]; then
      echo "  检测到 $fail_count 个不可达源，建议运行: ./scripts/setup-cn-mirrors.sh"
      echo "  或手动替换镜像: ./scripts/localize-images.sh --cn"
    fi
    if [ "$slow_count" -gt 0 ]; then
      echo "  检测到 $slow_count 个慢速源，建议开启镜像加速"
    fi
  fi
fi

exit $fail_count
