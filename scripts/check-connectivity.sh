#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# check-connectivity.sh — 网络连通性检测
#
# 检测中国大陆网络环境下的各个镜像源可达性
# 输出详细诊断报告，建议是否需要镜像加速
#
# 用法: ./scripts/check-connectivity.sh [--json]
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# 检测目标列表
TARGETS=(
  "Docker Hub|hub.docker.com|443"
  "GitHub|github.com|443"
  "GCR (Google)|gcr.io|443"
  "GHCR (GitHub Container)|ghcr.io|443"
  "Docker Daocloud|docker.m.daocloud.io|443"
  "网易蜂巢|hub-mirror.c.163.com|80"
  "百度云镜像|mirror.baidubce.com|443"
)

# 超时时间 (秒)
TIMEOUT=10

# ═══════════════════════════════════════════════════════════════════════════
# 辅助函数
# ═══════════════════════════════════════════════════════════════════════════

log() {
  echo -e "${CYAN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $*"
}

ping_host() {
  local host="$1"
  local port="$2"
  local timeout=$3

  # 使用 nc (netcat) 测试端口连通性
  if nc -z -w "$timeout" "$host" "$port" 2>/dev/null; then
    return 0
  else
    return 1
  fi
}

measure_latency() {
  local host="$1"
  local port="$2"

  # 使用 time 命令测量 TCP 连接时间
  # 这里简化，返回随机延迟或实际上测量
  # 可用: time nc -z -w 1 host port
  echo "N/A"
}

# ═══════════════════════════════════════════════════════════════════════════
# 检测模式
# ═══════════════════════════════════════════════════════════════════════════

run_check() {
  log "开始网络连通性检测..."
  echo

  local results=()
  local failed=0
  local slow=0

  for target in "${TARGETS[@]}"; do
    IFS='|' read -r name host port <<< "$target"

    echo -n "检测 $name ($host:$port) ... "

    if ping_host "$host" "$port" "$TIMEOUT"; then
      local latency=$(measure_latency "$host" "$port")
      echo -e "${GREEN}✓ 可达${NC} (延迟: ${latency})"
      results+=("OK|$name|$host|$port|$latency")
    else
      echo -e "${RED}✗ 不可达${NC}"
      results+=("FAIL|$name|$host|$port|N/A")
      ((failed++))
    fi
    sleep 1
  done

  echo
  echo "────────────────────────────────────────────────────────────────────────────────────────────"
  log "检测完成"
  echo

  # 输出详细报告
  local ok_count=$((${#TARGETS[@]} - failed))
  echo -e "结果: ${GREEN}${ok_count} 个可达${NC}, ${RED}${failed} 个不可达${NC}"
  echo

  # 建议
  if [[ $failed -ge 2 ]]; then
    warn "检测到多个镜像源不可达，建议启用镜像加速！"
    echo "运行: sudo ./scripts/setup-cn-mirrors.sh"
    return 1
  elif [[ $failed -ge 1 ]]; then
    warn "检测到部分镜像源不可达，可能影响镜像拉取速度"
    echo "建议: 启用镜像加速以获得更好体验"
    echo "运行: sudo ./scripts/setup-cn-mirrors.sh"
    return 0
  else
    success "所有目标均可达，网络环境良好！"
    return 0
  fi
}

# ═══════════════════════════════════════════════════════════════════════════
# JSON 输出模式 (用于 CI/自动化)
# ═══════════════════════════════════════════════════════════════════════════

run_check_json() {
  log "检测模式: JSON 输出"
  echo

  local json="{\"timestamp\":\"$(date -Iseconds)\",\"targets\":["

  for i in "${!TARGETS[@]}"; do
    IFS='|' read -r name host port <<< "${TARGETS[i]}"

    if ping_host "$host" "$port" "$TIMEOUT"; then
      local status="ok"
      local latency=$(measure_latency "$host" "$port")
    else
      local status="fail"
      local latency=null
    fi

    json+="{\"name\":\"$name\",\"host\":\"$host\",\"port\":$port,\"status\":\"$status\",\"latency\":$latency}"
    if [[ $i -lt $((${#TARGETS[@]} - 1)) ]]; then
      json+=","
    fi
  done

  json+="],\"summary\":{"

  # 统计
  local ok=0
  local fail=0
  for target in "${TARGETS[@]}"; do
    IFS='|' read -r name host port <<< "$target"
    if ping_host "$host" "$port" "$TIMEOUT"; then
      ((ok++))
    else
      ((fail++))
    fi
  done

  json+="\"ok\":$ok,\"fail\":$fail,\"total\":${#TARGETS[@]}"
  json+="}}"

  echo "$json" | python3 -m json.tool 2>/dev/null || echo "$json"
}

# ═══════════════════════════════════════════════════════════════════════════

show_help() {
  cat <<EOF
网络连通性检测工具

用法: $0 [OPTIONS]

选项:
  --json       输出 JSON 格式 (用于 CI)
  --help       显示此帮助

检测目标:
  - Docker Hub (hub.docker.com:443)
  - GitHub (github.com:443)
  - Google Container Registry (gcr.io:443)
  - GitHub Container Registry (ghcr.io:443)
  - DaoCloud Mirror (docker.m.daocloud.io:443)
  - 网易蜂巢 (hub-mirror.c.163.com:80)
  - 百度云镜像 (mirror.baidubce.com:443)

示例:
  $0                    # 交互式检测
  $0 --json            # JSON 输出，供脚本解析

EOF
}

main() {
  case "${1:-}" in
    --json)
      run_check_json
      ;;
    --help|-h)
      show_help
      exit 0
      ;;
    "")
      run_check
      ;;
    *)
      error "未知选项: $1"
      ;;
  esac
}

main "$@"