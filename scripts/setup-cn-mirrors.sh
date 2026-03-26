#!/usr/bin/env bash
# =============================================================================
# setup-cn-mirrors.sh — Docker 镜像加速配置
# 支持交互式询问和静默模式（通过环境变量），自动写入 daemon.json
# =============================================================================
set -euo pipefail
IFS=$'\n\t'

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

DOCKER_DAEMON="/etc/docker/daemon.json"
BACKUP_FILE="${DOCKER_DAEMON}.bak.$(date +%Y%m%d%H%M%S)"

# 默认镜像源列表（主/备用）
CN_MIRRORS='[
  "https://docker.m.daocloud.io",
  "https://mirror.gcr.io",
  "https://hub-mirror.c.163.com",
  "https://mirror.baidubce.com"
]'

is_cn_network() {
  # 通过多个指标综合判断是否在中国大陆
  # 1. 检查是否已配置过
  if grep -q "daocloud\|163.com\|baidubce" "$DOCKER_DAEMON" 2>/dev/null; then
    return 0
  fi

  # 2. 检查DNS解析是否指向国内CDN（尝试访问百度）
  if curl -sf --connect-timeout 3 --max-time 5 "https://www.baidu.com" &>/dev/null; then
    # 能访问百度，大概率在国内
    return 0
  fi

  # 3. 检查是否能直连 Docker Hub（如果能连上说明不是CN网络）
  if curl -sf --connect-timeout 5 --max-time 10 "https://registry-1.docker.io" &>/dev/null; then
    return 1
  fi

  # 4. 兜底：检测IP段（简单判断）
  local ip
  ip=$(curl -sf --connect-timeout 3 --max-time 5 ip.sb 2>/dev/null || echo "")
  if [[ -n "$ip" ]]; then
    # 中国大陆 IP 段粗略判断
    if [[ "$ip" =~ ^(101\.|117\.|119\.|120\.|121\.|122\.|123\.|124\.|125\.|139\.|140\.|175\.|180\.|182\.|183\.|202\.|203\.|211\.|218\.|220\.|221\.|222\.|223\.|49\.|116\.) ]]; then
      return 0
    fi
  fi

  return 1
}

read_user_choice() {
  echo ""
  echo -e "${BOLD}🌏 检测网络环境...${NC}"
  echo ""
  echo "是否在中国大陆网络环境下运行？"
  echo ""
  echo "  [1] 是，我在中国大陆（推荐配置国内镜像加速）"
  echo "  [2] 否，我在海外（保持默认配置）"
  echo "  [3] 手动选择镜像源（高级）"
  echo ""
  read -r -p "请输入选项 [1/2/3，默认 2]: " choice
  echo ""
  case "${choice:-2}" in
    1) return 0 ;;
    2) return 1 ;;
    3) return 2 ;;
    *) return 1 ;;
  esac
}

configure_mirrors() {
  local mirror_type="${1:-full}"

  log_info "正在配置 Docker 镜像加速..."

  # 创建备份
  if [[ -f "$DOCKER_DAEMON" ]]; then
    cp "$DOCKER_DAEMON" "$BACKUP_FILE"
    log_info "已备份原配置到: $BACKUP_FILE"
  fi

  # 确保目录存在
  mkdir -p "$(dirname "$DOCKER_DAEMON")"

  case "$mirror_type" in
    minimal)
      # 仅配置核心镜像源
      cat > "$DOCKER_DAEMON" <<EOF
{
  "registry-mirrors": [
    "https://docker.m.daocloud.io"
  ]
}
EOF
      ;;
    full|*)
      # 配置完整镜像源列表
      cat > "$DOCKER_DAEMON" <<EOF
{
  "registry-mirrors": ${CN_MIRRORS}
}
EOF
      ;;
  esac

  log_info "已写入: $DOCKER_DAEMON"
}

restart_docker() {
  log_info "正在重启 Docker 服务以应用配置..."

  if command -v systemctl &>/dev/null; then
    if systemctl is-active --quiet docker; then
      systemctl restart docker
      log_info "Docker 已重启（systemctl）"
    else
      log_warn "Docker 未运行，尝试启动..."
      systemctl start docker || true
    fi
  elif command -v service &>/dev/null; then
    service docker restart 2>/dev/null || true
    log_info "Docker 已重启（service）"
  else
    log_warn "无法自动重启 Docker，请手动执行: sudo systemctl restart docker"
    log_info "配置已写入，但需要重启 Docker 后生效"
    return 1
  fi

  # 等待 Docker 重启完成
  local wait_count=0
  while ! docker info &>/dev/null; do
    sleep 1
    ((wait_count++)) || true
    if [[ $wait_count -ge 30 ]]; then
      log_error "Docker 重启超时（30秒）"
      return 1
    fi
  done
  log_info "Docker 服务已就绪"
  return 0
}

verify_mirror() {
  log_info "正在验证镜像拉取..."
  echo ""

  if docker pull hello-world &>/dev/null; then
    log_info "✓ Docker 镜像拉取测试成功"
    docker rmi hello-world &>/dev/null || true
    return 0
  else
    log_error "✗ Docker 镜像拉取测试失败"
    log_warn "可能是网络问题或镜像源不可用"
    log_info "可以尝试手动拉取测试: docker pull hello-world"
    return 1
  fi
}

show_current_config() {
  echo ""
  echo -e "${BOLD}当前 Docker 镜像配置:${NC}"
  if [[ -f "$DOCKER_DAEMON" ]]; then
    cat "$DOCKER_DAEMON"
  else
    echo "(未配置)"
  fi
  echo ""

  echo -e "${BOLD}当前生效的 registry-mirrors:${NC}"
  docker info 2>/dev/null | grep -A 10 "Registry Mirrors" || echo "(无)"
  echo ""
}

usage() {
  cat <<EOF
用法: $0 [选项]

配置 Docker 镜像加速（中国大陆网络优化）

选项:
  --silent          静默模式（自动检测并配置）
  --force           强制配置（跳过检测，直接配置）
  --minimal         仅配置主镜像源（daoocloud）
  --show            显示当前配置
  --verify          仅验证当前配置是否有效
  -h, --help        显示帮助

示例:
  $0                  # 交互式配置
  $0 --silent         # 自动检测并配置
  $0 --minimal        # 最小配置（仅主镜像）
  $0 --show           # 查看当前配置
EOF
}

main() {
  local mode="interactive"
  local mirror_type="full"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --silent)   mode="silent" ;;
      --force)    mode="force" ;;
      --minimal)  mirror_type="minimal" ;;
      --show)     show_current_config; exit 0 ;;
      --verify)   verify_mirror; exit $? ;;
      -h|--help)  usage; exit 0 ;;
      *)          log_error "未知参数: $1"; usage; exit 1 ;;
    esac
    shift
  done

  echo ""
  echo -e "${BLUE}═══════════════════════════════════════════${NC}"
  echo -e "${BLUE}  Docker 镜像加速配置工具${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════${NC}"

  local should_configure=false
  local choice_result=1

  if [[ "$mode" == "silent" ]]; then
    if is_cn_network; then
      log_info "检测到中国大陆网络环境，将配置镜像加速"
      should_configure=true
      choice_result=0
    else
      log_info "未检测到中国大陆网络环境，保持默认配置"
      exit 0
    fi
  elif [[ "$mode" == "force" ]]; then
    should_configure=true
  else
    read_user_choice
    choice_result=$?
    if [[ $choice_result -eq 0 ]]; then
      should_configure=true
    elif [[ $choice_result -eq 2 ]]; then
      mirror_type="full"  # 手动选择也用完整配置
      should_configure=true
    fi
  fi

  if [[ "$should_configure" == "true" ]]; then
    configure_mirrors "$mirror_type"

    # 检查是否需要重启
    local current_mirrors
    current_mirrors=$(docker info 2>/dev/null | grep -c "docker.m.daocloud.io\|163.com\|baidubce" || echo "0")
    if [[ "$current_mirrors" -eq 0 ]]; then
      restart_docker || true
    fi

    echo ""
    show_current_config
    verify_mirror || true

    echo ""
    echo -e "${GREEN}${BOLD}✓ Docker 镜像加速配置完成！${NC}"
    echo ""
    log_info "配置已保存到: $DOCKER_DAEMON"
    log_info "如需撤销，请恢复备份: cp $BACKUP_FILE $DOCKER_DAEMON"
  else
    echo ""
    log_info "保持默认配置，未做任何更改"
  fi
}

main "$@"
