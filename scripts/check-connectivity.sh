#!/usr/bin/env bash
# =============================================================================
# check-connectivity.sh — 检测各镜像源 / 平台可达性
# 输出: OK / SLOW / FAIL 状态及延迟
# =============================================================================
set -uo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
BOLD='\033[1m'; NC='\033[0m'

OK="${GREEN}✓${NC}"
SLOW="${YELLOW}⚠${NC}"
FAIL="${RED}✗${NC}"

# 检测目标列表: name url_or_host port timeout
declare -a TARGETS=(
  "Docker Hub"         "hub.docker.com"           443 10
  "GitHub"             "github.com"               443 10
  "gcr.io"             "gcr.io"                  443 8
  "ghcr.io"            "ghcr.io"                 443 8
  "k8s.gcr.io"         "k8s.gcr.io"             443 8
  "registry.k8s.io"    "registry.k8s.io"          443 8
  "quay.io"            "quay.io"                 443 8
  "lscr.io"            "lscr.io"                 443 8
  "Docker Hub API"     "hub.docker.com/v2/"       443 10
  "GitHub API"        "api.github.com"           443 10
  "Daocloud Mirror"    "m.daocloud.io"           443 8
  "Baidu Mirror"      "mirror.baidubce.com"      443 8
  "163 Mirror"        "hub-mirror.c.163.com"     443 8
  "DNS (Google)"      "8.8.8.8"                 53  5
  "DNS (Aliyun)"       "223.6.6.6"              53  5
  "Docker daemon"     "localhost"                2375 3
)

OUTPUT_FILE=""
VERBOSE=false
JSON_OUTPUT=false

usage() {
  cat << EOF
用法: $0 [选项]

检测网络连通性（Docker Hub、GitHub、各镜像源、DNS）

选项:
  -o, --output <file>   将结果写入文件
  -j, --json            JSON 格式输出
  -v, --verbose         详细输出
  -h, --help            显示帮助

示例:
  $0                     # 标准输出
  $0 -j                  # JSON 输出
  $0 -o connectivity.txt # 输出到文件
EOF
}

for arg in "$@"; do
  case $arg in
    -o|--output) OUTPUT_FILE="$2"; shift 2 ;;
    -j|--json) JSON_OUTPUT=true; shift ;;
    -v|--verbose) VERBOSE=true; shift ;;
    -h|--help) usage; exit 0 ;;
  esac
done

# 检测单点连通性
check_target() {
  local name="$1"; local host="$2"; local port="$3"; local timeout="$4"
  local start_ms end_ms latency_ms status_code

  start_ms=$(date +%s%3N)

  if [[ "$host" == "localhost" || "$host" == "8.8.8.8" || "$host" == "223.6.6.6" ]]; then
    # TCP port check
    if nc -z -w"$timeout" "$host" "$port" 2>/dev/null; then
      end_ms=$(date +%s%3N)
      latency_ms=$((end_ms - start_ms))
      echo "OK|$name|HTTP|$latency_ms"
    else
      echo "FAIL|$name|TCP|$port"
    fi
  else
    # HTTP check
    local code
    code=$(curl -sf --connect-timeout "$timeout" --max-time $((timeout + 5)) \
      -o /dev/null -w '%{http_code}' \
      "https://$host" 2>/dev/null || echo "000")

    end_ms=$(date +%s%3N)
    latency_ms=$((end_ms - start_ms))

    if [[ "$code" =~ ^[23] ]]; then
      echo "OK|$name|HTTP $code|$latency_ms"
    elif [[ "$code" == "000" ]]; then
      echo "FAIL|$name|TIMEOUT|$timeout"
    else
      echo "SLOW|$name|HTTP $code|$latency_ms"
    fi
  fi
}

# 检测 DNS 解析
check_dns() {
  local domain="$1"
  local start end ms
  start=$(date +%s%3N)
  if host "$domain" &>/dev/null || nslookup "$domain" &>/dev/null; then
    end=$(date +%s%3N)
    ms=$((end - start))
    echo "OK|$domain|$ms"
  else
    echo "FAIL|$domain|0"
  fi
}

# 生成状态报告
print_result() {
  local status="$1"; local name="$2"; local detail="$3"; local latency="$4"
  local latency_s
  printf -v latency_s "%.1f" "$(echo "scale=1; $latency/1000" | bc -l 2>/dev/null || echo "0")"

  local icon
  case "$status" in
    OK)  icon="$OK"  ;;
    SLOW) icon="$SLOW" ;;
    FAIL) icon="$FAIL" ;;
  esac

  local latency_str=""
  [[ -n "$latency" && "$latency" != "0" ]] && latency_str=" (${latency_s}s)"

  printf "  %-4s %-25s %s %s%s\n" "" "$name" "$icon" "$detail" "$latency_str"
}

# 主程序
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║       HomeLab Stack — Network Connectivity Check     ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

# System info
echo -e "${BLUE}[System Info]${NC}"
echo "  OS: $(uname -s) $(uname -r)"
echo "  Host: $(hostname) ($(hostname -I 2>/dev/null | awk '{print $1}'))"
echo "  DNS: $(cat /etc/resolv.conf 2>/dev/null | grep nameserver | awk '{print $2}' | head -1)"
echo ""

# Check internet
echo -e "${BLUE}[Internet]${NC}"
if curl -sf --connect-timeout 5 --max-time 10 \
  -o /dev/null -w '%{http_code}' "https://www.baidu.com" 2>/dev/null | grep -q "200\|301\|302"; then
  echo -e "  Internet connectivity: $OK"
else
  echo -e "  Internet connectivity: $FAIL (offline?)"
fi
echo ""

echo -e "${BLUE}[Registry & Platform Reachability]${NC}"
printf "  %-4s %-25s %s %s %s\n" "" "Service" "Status" "Detail" "Latency"
printf "  %s\n" "--------------------------------------------------------------------------------"

declare -a results=()
local i=0
while [[ $i -lt ${#TARGETS[@]} ]]; do
  local name="${TARGETS[$i]}"
  local host="${TARGETS[$((i+1))]}"
  local port="${TARGETS[$((i+2))]}"
  local timeout="${TARGETS[$((i+3))]}"

  local result
  result=$(check_target "$name" "$host" "$port" "$timeout")

  local status detail latency
  IFS='|' read -r status detail latency <<< "$result"
  print_result "$status" "$name" "$detail" "$latency"
  results+=("$result")

  ((i+=4))
done

# DNS checks
echo ""
echo -e "${BLUE}[DNS Resolution]${NC}"
for domain in google.com baidu.com github.com docker.com; do
  local res
  res=$(check_dns "$domain")
  local status d_latency
  IFS='|' read -r status d_latency <<< "$res"
  [[ -n "$d_latency" ]] && d_latency=" ($(echo "scale=1; $d_latency/1000" | bc -l 2>/dev/null || echo "0")s)" || d_latency=""
  print_result "$status" "Resolve $domain" "" "$d_latency"
done

# Summary
echo ""
echo -e "${BOLD}────────────────────────────────────────────────────────────────────${NC}"
local ok_count=0 slow_count=0 fail_count=0
for r in "${results[@]}"; do
  local s
  s="${r%%|*}"
  [[ "$s" == "OK" ]] && ((ok_count++))
  [[ "$s" == "SLOW" ]] && ((slow_count++))
  [[ "$s" == "FAIL" ]] && ((fail_count++))
done

printf "  %-30s %s OK, %s SLOW, %s FAIL\n" \
  "Summary:" "$ok_count" "$slow_count" "$fail_count"

# Recommendations
echo ""
echo -e "${BLUE}[Recommendations]${NC}"
if [[ "$fail_count" -gt 0 ]]; then
  echo -e "  $FAIL $fail_count service(s) unreachable"
  if [[ "$fail_count" -ge 2 ]]; then
    echo -e "  ${YELLOW}→${NC} Run: sudo ./scripts/setup-cn-mirrors.sh"
    echo -e "  ${YELLOW}→${NC} Run: ./scripts/localize-images.sh --cn"
  fi
fi
if [[ "$slow_count" -gt 0 ]]; then
  echo -e "  $SLOW $slow_count service(s) slow"
fi

# Write to file if requested
if [[ -n "$OUTPUT_FILE" ]]; then
  "$0" -j > "$OUTPUT_FILE" 2>&1 || "$0" > "$OUTPUT_FILE" 2>&1
  echo -e "\n${GREEN}Report written to $OUTPUT_FILE${NC}"
fi

# Exit code
[[ "$fail_count" -gt 0 ]] && exit 1 || exit 0
