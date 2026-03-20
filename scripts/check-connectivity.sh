#!/usr/bin/env bash
# =============================================================================
# Check Connectivity — 网络连通性检测工具
# 检测 Docker Hub、GitHub、gcr.io、ghcr.io 等关键服务的可达性
# =============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# 检测结果统计
PASS=0
WARN=0
FAIL=0

log_pass() { echo -e "  ${GREEN}[OK]${NC} $*"; ((PASS++)); }
log_warn() { echo -e "  ${YELLOW}[SLOW]${NC} $* ⚠️"; ((WARN++)); }
log_fail() { echo -e "  ${RED}[FAIL]${NC} $* ✗"; ((FAIL++)); }
log_info() { echo -e "  ${BLUE}[INFO]${NC} $*"; }

# 测试主机连通性和延迟
test_host() {
  local host="$1"
  local description="$2"
  local timeout="${3:-5}"
  
  local start_time=$(date +%s%N)
  
  if curl -sf --connect-timeout "$timeout" --max-time "$((timeout * 2))" "https://$host" &>/dev/null; then
    local end_time=$(date +%s%N)
    local latency=$(( (end_time - start_time) / 1000000 ))
    
    if [[ $latency -lt 300 ]]; then
      log_pass "$description ($host) — 延迟 ${latency}ms"
    elif [[ $latency -lt 1000 ]]; then
      log_warn "$description ($host) — 延迟 ${latency}ms，建议开启镜像加速"
    else
      log_fail "$description ($host) — 延迟 ${latency}ms，需要使用国内镜像"
    fi
  else
    log_fail "$description ($host) — 连接超时"
  fi
}

# 测试端口连通性
test_port() {
  local host="$1"
  local port="$2"
  local description="$3"
  
  if timeout 3 bash -c "cat < /dev/null > /dev/tcp/$host/$port" 2>/dev/null; then
    log_pass "$description ($host:$port) — 端口开放"
  else
    log_fail "$description ($host:$port) — 端口不可达"
  fi
}

# 测试 DNS 解析
test_dns() {
  local host="$1"
  local description="$2"
  
  if command -v dig &>/dev/null; then
    local result=$(dig +short "$host" 2>/dev/null | head -1)
    if [[ -n "$result" ]]; then
      log_pass "$description — DNS 解析成功 ($result)"
    else
      log_fail "$description — DNS 解析失败"
    fi
  elif command -v nslookup &>/dev/null; then
    if nslookup "$host" &>/dev/null; then
      log_pass "$description — DNS 解析成功"
    else
      log_fail "$description — DNS 解析失败"
    fi
  elif command -v host &>/dev/null; then
    if host "$host" &>/dev/null; then
      log_pass "$description — DNS 解析成功"
    else
      log_fail "$description — DNS 解析失败"
    fi
  else
    # 使用 ping 作为最后手段
    if ping -c 1 -W 2 "$host" &>/dev/null; then
      log_pass "$description — DNS 解析成功 (ping)"
    else
      log_fail "$description — DNS 解析失败"
    fi
  fi
}

# 检测 Docker 镜像源
check_docker_hub() {
  echo -e "\n${BLUE}${BOLD}[1/6] Docker Hub 检测${NC}"
  
  test_host "hub.docker.com" "Docker Hub"
  test_host "registry-1.docker.io" "Docker Registry"
  test_host "auth.docker.io" "Docker Auth"
}

# 检测 GitHub
check_github() {
  echo -e "\n${BLUE}${BOLD}[2/6] GitHub 检测${NC}"
  
  test_host "github.com" "GitHub"
  test_host "api.github.com" "GitHub API"
  test_host "raw.githubusercontent.com" "GitHub Raw"
  test_host "ghcr.io" "GitHub Container Registry"
}

# 检测 Google 容器镜像
check_gcr() {
  echo -e "\n${BLUE}${BOLD}[3/6] GCR.io 检测${NC}"
  
  test_host "gcr.io" "GCR.io"
  test_host "k8s.gcr.io" "K8s GCR"
  test_host "registry.k8s.io" "K8s Registry"
}

# 检测其他容器镜像源
check_quay() {
  echo -e "\n${BLUE}${BOLD}[4/6] Quay.io 检测${NC}"
  
  test_host "quay.io" "Quay.io"
}

# 检测 DNS 和网络基础
check_network() {
  echo -e "\n${BLUE}${BOLD}[5/6] 网络基础检测${NC}"
  
  # DNS 解析测试
  test_dns "google.com" "DNS 解析 (google.com)"
  test_dns "github.com" "DNS 解析 (github.com)"
  
  # 端口测试
  test_port "hub.docker.com" "443" "HTTPS 出站"
  test_port "github.com" "443" "HTTPS 出站"
}

# 检测 Docker 配置
check_docker_config() {
  echo -e "\n${BLUE}${BOLD}[6/6] Docker 配置检测${NC}"
  
  if command -v docker &>/dev/null; then
    log_pass "Docker 已安装"
    
    if docker info &>/dev/null; then
      log_pass "Docker 服务运行正常"
      
      # 检查镜像源配置
      local mirrors=$(docker info 2>/dev/null | grep -A 10 "Registry Mirrors" || true)
      if [[ -n "$mirrors" ]]; then
        log_info "已配置的镜像源:"
        echo "$mirrors" | grep -E "^\s+" | while read -r line; do
          echo -e "    ${BLUE}•${NC} $line"
        done
      else
        log_warn "未配置镜像加速源"
      fi
      
      # 检查 daemon.json
      if [[ -f "/etc/docker/daemon.json" ]]; then
        log_pass "daemon.json 存在"
      else
        log_info "daemon.json 不存在 (使用默认配置)"
      fi
    else
      log_fail "Docker 服务未运行"
    fi
  else
    log_fail "Docker 未安装"
  fi
}

# 生成建议
generate_recommendations() {
  echo -e "\n${BLUE}${BOLD}═══════════════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}${BOLD}检测建议${NC}"
  echo -e "${BLUE}${BOLD}═══════════════════════════════════════════════════════════${NC}"
  
  local recommendations=0
  
  if [[ $FAIL -gt 0 ]]; then
    echo -e "\n${RED}检测到 $FAIL 个不可达源，建议进行以下配置:${NC}"
    ((recommendations++))
    
    echo -e "\n${YELLOW}1. 配置 Docker 镜像加速${NC}"
    echo -e "   运行：sudo ./scripts/setup-cn-mirrors.sh --auto"
    
    echo -e "\n${YELLOW}2. 替换 compose 文件镜像为国内源${NC}"
    echo -e "   运行：./scripts/localize-images.sh --cn"
  fi
  
  if [[ $WARN -gt 0 ]]; then
    echo -e "\n${YELLOW}检测到 $WARN 个慢速连接，建议进行以下优化:${NC}"
    ((recommendations++))
    
    echo -e "\n${YELLOW}1. 配置镜像加速以提升拉取速度${NC}"
    echo -e "   运行：sudo ./scripts/setup-cn-mirrors.sh --auto"
  fi
  
  if [[ $PASS -gt 0 && $WARN -eq 0 && $FAIL -eq 0 ]]; then
    echo -e "\n${GREEN}✓ 网络状况良好，无需额外配置${NC}"
  fi
  
  if [[ $recommendations -gt 0 ]]; then
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}一键配置命令:${NC}"
    echo -e "  ${GREEN}sudo ./scripts/setup-cn-mirrors.sh --auto${NC}"
    echo -e "  ${GREEN}./scripts/localize-images.sh --cn${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
  fi
}

# 显示摘要
show_summary() {
  echo -e "\n${BLUE}${BOLD}═══════════════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}${BOLD}检测摘要${NC}"
  echo -e "${BLUE}${BOLD}═══════════════════════════════════════════════════════════${NC}"
  echo -e "  ${GREEN}PASS: $PASS${NC}  ${YELLOW}WARN: $WARN${NC}  ${RED}FAIL: $FAIL${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
}

# 显示帮助
usage() {
  cat <<EOF
用法：$0 [选项]

选项:
  --quick     快速检测 (仅检测关键服务)
  --full      完整检测 (默认)
  --json      输出 JSON 格式结果
  --help      显示帮助信息

示例:
  $0              # 完整检测
  $0 --quick      # 快速检测
  $0 --json       # JSON 输出

EOF
  exit 0
}

# JSON 输出
output_json() {
  cat <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "summary": {
    "pass": $PASS,
    "warn": $WARN,
    "fail": $FAIL
  },
  "recommendation": $([ $FAIL -gt 0 ] && echo "true" || echo "false")
}
EOF
}

# 主函数
main() {
  echo -e ""
  echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║   HomeLab Stack - 网络连通性检测工具                     ║${NC}"
  echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
  echo -e ""
  
  local mode="full"
  local json_output=false
  
  # 解析参数
  while [[ $# -gt 0 ]]; do
    case $1 in
      --quick)
        mode="quick"
        shift
        ;;
      --full)
        mode="full"
        shift
        ;;
      --json)
        json_output=true
        shift
        ;;
      --help|-h)
        usage
        ;;
      *)
        echo -e "${RED}未知选项：$1${NC}"
        usage
        ;;
    esac
  done
  
  if [[ "$mode" == "quick" ]]; then
    # 快速检测
    check_docker_hub
    check_github
    check_gcr
  else
    # 完整检测
    check_docker_hub
    check_github
    check_gcr
    check_quay
    check_network
    check_docker_config
  fi
  
  # 输出结果
  if [[ "$json_output" == true ]]; then
    output_json
  else
    show_summary
    generate_recommendations
  fi
  
  # 返回状态码
  if [[ $FAIL -gt 0 ]]; then
    exit 1
  else
    exit 0
  fi
}

main "$@"
