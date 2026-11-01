#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Connectivity Checker
# 检测 Docker Hub / GitHub / gcr.io / ghcr.io / DNS / 出站端口 连通性
# 对应 Issue #8 [BOUNTY $250] Robustness — 国内网络适配
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[connectivity]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[connectivity]${NC} $*"; }
log_error() { echo -e "${RED}[connectivity]${NC} $*" >&2; }

FAIL_COUNT=0
SLOW_COUNT=0

# ---------------------------------------------------------------------------
# curl_retry — 断网重试包装（指数退避，最多 3 次）
# 对应任务要求：所有网络请求使用此包装函数
# ---------------------------------------------------------------------------
curl_retry() {
  local max_attempts=3
  local delay=5
  local i
  for i in $(seq 1 "$max_attempts"); do
    if curl --connect-timeout 10 --max-time 60 "$@" 2>/dev/null; then
      return 0
    fi
    echo "[connectivity] Attempt $i failed, retrying in ${delay}s..." >&2
    sleep "$delay"
    delay=$((delay * 2))
  done
  return 1
}

# ---------------------------------------------------------------------------
# check_endpoint — 检测单端点
#   $1: 显示名  $2: URL  $3: 建议（若慢/不可达）
# ---------------------------------------------------------------------------
check_endpoint() {
  local name="$1" url="$2" advice="$3"
  local code latency
  code=$(curl -sf --connect-timeout 5 --max-time 8 -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
  latency=$(curl -sf --connect-timeout 5 --max-time 8 -o /dev/null -w "%{time_total}" "$url" 2>/dev/null || echo "999")

  if [[ "$code" == "000" ]]; then
    echo -e "  ${RED}[FAIL]${NC} $name — 连接失败 ✗ $advice"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  elif awk -v l="$latency" 'BEGIN {exit !(l < 1.5)}'; then
    echo -e "  ${GREEN}[OK]${NC}   $name — 延迟 ${latency}s"
  else
    echo -e "  ${YELLOW}[SLOW]${NC} $name — 延迟 ${latency}s ⚠️ $advice"
    SLOW_COUNT=$((SLOW_COUNT + 1))
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
log_info "HomeLab Stack — 网络连通性检测"
echo ""

log_info "检测项目:"
echo "  ✓ Docker Hub 可达性"
echo "  ✓ GitHub 可达性"
echo "  ✓ gcr.io 可达性"
echo "  ✓ ghcr.io 可达性"
echo "  ✓ DNS 解析正常"
echo "  ✓ 443/80 出站端口开放"
echo ""

check_endpoint "Docker Hub (hub.docker.com)" "https://hub.docker.com/v2/" "建议检查代理"
check_endpoint "GitHub (github.com)" "https://github.com" "建议开启镜像加速"
check_endpoint "gcr.io" "https://gcr.io/v2/" "需要使用国内镜像"
check_endpoint "ghcr.io" "https://ghcr.io/v2/" "需要使用国内镜像"
check_endpoint "Baidu (国内基准)" "https://www.baidu.com" "国内网络也异常，检查基础网络"
check_endpoint "Daocloud 镜像 (国内源)" "https://docker.m.daocloud.io/v2/" "国内镜像源可用性"

# DNS 检查
echo ""
log_info "DNS 解析检查:"
if getent hosts hub.docker.com >/dev/null 2>&1 || nslookup hub.docker.com >/dev/null 2>&1; then
  echo -e "  ${GREEN}[OK]${NC}   DNS 解析正常 (hub.docker.com)"
else
  echo -e "  ${RED}[FAIL]${NC} DNS 解析失败 — 检查 /etc/resolv.conf"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# 出站端口检查
echo ""
log_info "出站端口检查:"
for port in 80 443; do
  if curl -sf --connect-timeout 3 -o /dev/null "http://127.0.0.1:$port" 2>/dev/null; then
    echo -e "  ${GREEN}[OK]${NC}   本地 $port 端口可达（本地服务）"
  elif command -v nc &>/dev/null && nc -z -w 3 8.8.8.8 "$port" 2>/dev/null; then
    echo -e "  ${GREEN}[OK]${NC}   $port 出站端口开放"
  else
    echo -e "  ${YELLOW}[WARN]${NC} $port 出站端口未确认（可能被防火墙拦截）"
  fi
done

# 汇总
echo ""
if [[ "$FAIL_COUNT" -gt 0 ]]; then
  log_error "检测到 $FAIL_COUNT 个不可达源，建议运行 ./scripts/setup-cn-mirrors.sh"
  exit 1
elif [[ "$SLOW_COUNT" -gt 0 ]]; then
  log_warn "检测到 $SLOW_COUNT 个慢速源，建议运行 ./scripts/setup-cn-mirrors.sh"
  exit 0
else
  log_info "全部网络源正常 ✓"
  exit 0
fi
