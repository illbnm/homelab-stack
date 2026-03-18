#!/usr/bin/env bash
# =============================================================================
# Check Connectivity — 网络连通性检测脚本
# 检测 Docker Hub、GitHub、gcr.io、ghcr.io 等镜像源可达性
# =============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[check-connectivity]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[check-connectivity]${NC} $*" >&2; }
log_error() { echo -e "${RED}[check-connectivity]${NC} $*" >&2; }
log_step()  { echo -e "${BLUE}[check-connectivity]${NC} $*"; }

# 检测目标列表
declare -A TARGETS=(
  ["Docker Hub"]="hub.docker.com"
  ["GitHub"]="github.com"
  ["gcr.io"]="gcr.io"
  ["ghcr.io"]="ghcr.io"
  ["Quay.io"]="quay.io"
  ["Google DNS"]="8.8.8.8"
  ["Cloudflare DNS"]="1.1.1.1"
)

# 结果统计
declare -A RESULTS=()
OK_COUNT=0
SLOW_COUNT=0
FAIL_COUNT=0

# 检测单个主机连通性
check_host() {
  local name="$1"
  local host="$2"
  
  # DNS 解析测试
  if ! nslookup "$host" &>/dev/null; then
    echo "[FAIL] $name ($host) — DNS 解析失败 ✗"
    RESULTS["$name"]="FAIL"
    ((FAIL_COUNT++))
    return 1
  fi
  
  # HTTP/HTTPS 连接测试
  local start_time=$(date +%s%N)
  local http_code
  http_code=$(curl -sf --connect-timeout 5 --max-time 10 -o /dev/null -w "%{http_code}" "https://$host" 2>/dev/null || echo "000")
  local end_time=$(date +%s%N)
  local latency=$(( (end_time - start_time) / 1000000 ))
  
  # 判断结果
  if [[ "$http_code" == "000" ]]; then
    echo "[FAIL] $name ($host) — 连接超时 ✗"
    RESULTS["$name"]="FAIL"
    ((FAIL_COUNT++))
    return 1
  elif [[ $latency -gt 1000 ]]; then
    echo "[SLOW] $name ($host) — 延迟 ${latency}ms ⚠️ 建议开启镜像加速"
    RESULTS["$name"]="SLOW"
    ((SLOW_COUNT++))
    return 0
  elif [[ $latency -gt 500 ]]; then
    echo "[OK] $name ($host) — 延迟 ${latency}ms ⚠️ 稍慢"
    RESULTS["$name"]="OK"
    ((OK_COUNT++))
    return 0
  else
    echo "[OK] $name ($host) — 延迟 ${latency}ms ✓"
    RESULTS["$name"]="OK"
    ((OK_COUNT++))
    return 0
  fi
}

# 检测端口连通性
check_port() {
  local name="$1"
  local host="$2"
  local port="$3"
  
  if timeout 3 bash -c "echo > /dev/tcp/$host/$port" 2>/dev/null; then
    echo "[OK] $name ($host:$port) — 端口开放 ✓"
    return 0
  else
    echo "[FAIL] $name ($host:$port) — 端口不可达 ✗"
    return 1
  fi
}

# Docker Hub 拉取测试
test_docker_pull() {
  log_step "测试 Docker 拉取能力..."
  
  if command -v docker &>/dev/null; then
    local start_time=$(date +%s%N)
    if sudo docker pull hello-world:latest &>/dev/null; then
      local end_time=$(date +%s%N)
      local duration=$(( (end_time - start_time) / 1000000 ))
      echo "[OK] Docker Pull — 成功拉取 hello-world (${duration}ms)"
      sudo docker rmi hello-world:latest &>/dev/null
      return 0
    else
      echo "[FAIL] Docker Pull — 拉取失败 ✗"
      return 1
    fi
  else
    echo "[SKIP] Docker Pull — Docker 未安装"
    return 0
  fi
}

# 显示检测报告
show_report() {
  echo ""
  echo "=============================================="
  echo "  网络连通性检测报告"
  echo "=============================================="
  echo ""
  echo "检测结果:"
  echo "  ✓ 成功：$OK_COUNT"
  echo "  ⚠️  缓慢：$SLOW_COUNT"
  echo "  ✗ 失败：$FAIL_COUNT"
  echo ""
  
  if [[ $FAIL_COUNT -gt 0 ]]; then
    echo -e "${RED}建议：${NC}检测到 $FAIL_COUNT 个不可达源，建议运行以下命令配置镜像加速："
    echo "  ./scripts/setup-cn-mirrors.sh"
    echo ""
  elif [[ $SLOW_COUNT -gt 0 ]]; then
    echo -e "${YELLOW}建议：${NC}检测到 $SLOW_COUNT 个缓慢的连接，可考虑开启镜像加速提升体验"
    echo "  ./scripts/setup-cn-mirrors.sh"
    echo ""
  else
    echo -e "${GREEN}结论：${NC}网络状况良好，无需特别配置"
    echo ""
  fi
}

# 主函数
main() {
  echo ""
  echo "=============================================="
  echo "  网络连通性检测工具"
  echo "=============================================="
  echo ""
  
  log_step "开始检测网络连通性..."
  echo ""
  
  # DNS 解析测试
  log_step "检测 DNS 解析..."
  if ! nslookup www.baidu.com &>/dev/null; then
    log_error "DNS 解析失败，请检查网络配置"
    exit 1
  fi
  echo "[OK] DNS 解析正常 ✓"
  echo ""
  
  # 主机连通性测试
  log_step "检测主机连通性..."
  for name in "${!TARGETS[@]}"; do
    check_host "$name" "${TARGETS[$name]}"
  done
  echo ""
  
  # 端口检测
  log_step "检测关键端口..."
  check_port "HTTP" "www.baidu.com" "80" || true
  check_port "HTTPS" "www.baidu.com" "443" || true
  echo ""
  
  # Docker 拉取测试
  test_docker_pull || true
  echo ""
  
  # 显示报告
  show_report
}

main "$@"
