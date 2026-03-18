#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# setup-cn-mirrors.sh — 配置 Docker 国内镜像加速
#
# 用法: ./scripts/setup-cn-mirrors.sh
#
# 功能:
# 1. 检测是否在中国大陆 (可选手动指定)
# 2. 备份现有 /etc/docker/daemon.json
# 3. 写入镜像加速配置 (支持多个源)
# 4. 重启 Docker 服务
# 5. 验证配置成功
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# 配置文件路径
DOCKER_DAEMON="/etc/docker/daemon.json"
BACKUP_SUFFIX=".backup.$(date +%Y%m%d-%H%M%S)"

# 国内镜像源列表 (按优先级)
CN_MIRRORS=(
  "https://docker.m.daocloud.io"
  "https://hub-mirror.c.163.com"
  "https://mirror.baidubce.com"
  "https://mirror.gcr.io"
)

# ═══════════════════════════════════════════════════════════════════════════
# 辅助函数
# ═══════════════════════════════════════════════════════════════════════════

log() {
  echo -e "${CYAN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $*"
}

error() {
  echo -e "${RED}[ERROR]${NC} $*" >&2
  exit 1
}

warn() {
  echo -e "${YELLOW}[WARN]${NC} $*"
}

success() {
  echo -e "${GREEN}[OK]${NC} $*"
}

is_china_network() {
  # 检测是否在中国大陆 (通过 IP 或手动选择)
  # 这里我们直接询问用户，因为自动检测可能不准
  echo "n"  # 默认不是，需要询问
}

is_root() {
  [[ $EUID -eq 0 ]]
}

is_docker_installed() {
  command -v docker &>/dev/null
}

# ═══════════════════════════════════════════════════════════════════════════
# 主流程
# ═══════════════════════════════════════════════════════════════════════════

main() {
  log "开始配置 Docker 国内镜像加速..."
  echo

  # 1. 检查 Docker 是否安装
  if ! is_docker_installed; then
    error "Docker 未安装。请先安装 Docker: https://docs.docker.com/engine/install/"
  fi

  success "Docker 已安装: $(docker --version | head -1)"

  # 2. 检查权限
  if ! is_root; then
    warn "需要 root 权限写入 $DOCKER_DAEMON"
    warn "请使用 sudo 运行: sudo $0"
    exit 1
  fi

  # 3. 询问是否在中国大陆
  echo -e "${BOLD}是否在中国大陆需要镜像加速？${NC}"
  echo "  1) 是，配置国内镜像源"
  echo "  2) 否，跳过"
  echo "  3) 恢复默认配置 (移除加速)"
  read -rp "选择 [1-3]: " choice

  case "$choice" in
    1) configure_mirrors ;;
    2) skip_configuration ;;
    3) restore_default ;;
    *) error "无效选择" ;;
  esac
}

# ═══════════════════════════════════════════════════════════════════════════
# 配置镜像加速
# ═══════════════════════════════════════════════════════════════════════════

configure_mirrors() {
  log "配置 Docker 镜像加速..."

  # 备份现有配置
  if [[ -f "$DOCKER_DAEMON" ]]; then
    cp "$DOCKER_DAEMON" "${DOCKER_DAEMON}${BACKUP_SUFFIX}"
    success "已备份原配置文件到 ${DOCKER_DAEMON}${BACKUP_SUFFIX}"
  fi

  # 询问选择镜像源
  echo
  echo -e "${BOLD}选择镜像加速源：${NC}"
  echo "  1) DaoCloud (推荐，多源负载均衡)"
  echo "  2) 网易蜂巢 (仅 HTTP，需 HTTP Clients 支持)"
  echo "  3) 百度云 (适合华南)"
  echo "  4) Google Mirror (适合所有地区)"
  echo "  5) 手动输入自定义源"
  read -rp "选择 [1-5]: " mirror_choice

  local selected_mirrors=()
  case "$mirror_choice" in
    1)
      selected_mirrors=("https://docker.m.daocloud.io")
      ;;
    2)
      selected_mirrors=("http://hub-mirror.c.163.com")
      ;;
    3)
      selected_mirrors=("https://mirror.baidubce.com")
      ;;
    4)
      selected_mirrors=("https://mirror.gcr.io")
      ;;
    5)
      read -rp "输入镜像源 URL (多个用逗号分隔): " custom_input
      IFS=',' read -ra selected_mirrors <<< "$custom_input"
      ;;
    *)
      error "无效选择"
      ;;
  esac

  # 构建 registry-mirrors 配置
  local mirrors_json="["
  for i in "${!selected_mirrors[@]}"; do
    local mirror="${selected_mirrors[i]}"
    mirrors_json+="\n    \"$mirror\""
    if [[ $i -lt $((${#selected_mirrors[@]} - 1)) ]]; then
      mirrors_json+=","
    fi
  done
  mirrors_json+="\n  ]"

  # 创建新配置
  cat > "$DOCKER_DAEMON" <<EOF
{
  "registry-mirrors": ${mirrors_json},
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}
EOF

  success "Docker 配置已写入 $DOCKER_DAEMON"
  echo
  log "配置内容:"
  cat "$DOCKER_DAEMON"
  echo

  # 3. 重启 Docker
  log "重启 Docker 服务..."
  if command -v systemctl &>/dev/null; then
    systemctl restart docker
    success "Docker 服务已重启 (systemctl)"
  elif command -v service &>/dev/null; then
    service docker restart
    success "Docker 服务已重启 (service)"
  else
    warn "无法自动重启 Docker，请手动重启"
  fi

  # 4. 验证配置
  sleep 3
  log "验证配置..."
  local docker_info=$(docker info 2>/dev/null || echo "error")
  if echo "$docker_info" | grep -q "Registry Mirrors:"; then
    success "镜像加速配置生效！"
    echo
    log "当前 Registry Mirrors:"
    echo "$docker_info" | grep -A5 "Registry Mirrors:"
  else
    warn "镜像加速配置似乎未生效，请检查 Docker 日志"
  fi

  # 5. 测试拉取镜像
  echo
  read -rp "是否现在测试拉取一个镜像？(y/N): " test_pull
  if [[ "$test_pull" =~ ^[Yy]$ ]]; then
    test_pull_image
  fi

  echo
  success "配置完成！现在 Docker 拉取镜像应该更快了。"
}

# ═══════════════════════════════════════════════════════════════════════════
# 跳过配置
# ═══════════════════════════════════════════════════════════════════════════

skip_configuration() {
  log "跳过镜像加速配置。"
  echo "您可以随时运行此脚本进行配置。"
}

# ═══════════════════════════════════════════════════════════════════════════
# 恢复默认配置
# ═══════════════════════════════════════════════════════════════════════════

restore_default() {
  log "恢复 Docker 默认配置..."

  local restored=false

  # 1. 如果有备份，恢复备份
  local latest_backup=$(ls -t "${DOCKER_DAEMON}".backup.* 2>/dev/null | head -1)
  if [[ -n "$latest_backup" ]]; then
    cp "$latest_backup" "$DOCKER_DAEMON"
    success "已从备份恢复: $latest_backup"
    restored=true
  else
    # 2. 无备份，删除配置文件（Docker 会使用默认）
    if [[ -f "$DOCKER_DAEMON" ]]; then
      mv "$DOCKER_DAEMON" "${DOCKER_DAEMON}.removed.$(date +%Y%m%d-%H%M%S)"
      success "已移除配置，Docker 将使用默认设置"
      restored=true
    else
      warn "无配置文件需要恢复"
    fi
  fi

  if $restored; then
    # 重启 Docker
    log "重启 Docker 服务..."
    if command -v systemctl &>/dev/null; then
      systemctl restart docker
    elif command -v service &>/dev/null; then
      service docker restart
    fi
    success "已恢复默认配置"
  fi
}

# ═══════════════════════════════════════════════════════════════════════════
# 测试镜像拉取
# ═══════════════════════════════════════════════════════════════════════════

test_pull_image() {
  log "测试镜像拉取..."

  local test_image="hello-world:latest"
  local start_time=$(date +%s)

  if docker pull "$test_image" &>/dev/null; then
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    success "镜像拉取成功 (${duration}s)"
    docker rmi "$test_image" &>/dev/null || true
  else
    error "镜像拉取失败，请检查网络配置"
  fi
}

# ═══════════════════════════════════════════════════════════════════════════

main "$@"