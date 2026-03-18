#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# install.sh — 鲁棒性安装脚本
#
# 功能:
# 1. 系统检测 (OS/架构)
# 2. Docker 自动安装 (如果未安装)
# 3. Docker Compose v2 确保
# 4. 资源检查 (磁盘/内存/端口)
# 5. 配置生成 (.env)
# 6. Base Stack 启动
# 7. 等待健康
#
# 用法: ./scripts/install.sh [--skip-docker] [--skip-checks]
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

# 选项
SKIP_DOCKER=false
SKIP_CHECKS=false
FORCE=false

# 路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BASE_DIR="$(dirname "$SCRIPT_DIR")"
STACKS_DIR="$BASE_DIR/stacks"
CONFIG_DIR="$BASE_DIR/config"

# 资源阈值
MIN_DISK_GB=20
MIN_MEMORY_GB=2
CONFLICT_PORTS=(53 80 443 3000 3001 3002 8080 8081 9000 9090 9093 9096 9097 3100 3200)

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

question() {
  echo -e "${BLUE}[?]${NC} $*"
}

# 获取系统信息
detect_os() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    echo "$ID"
  elif [[ -f /etc/system-release ]]; then
    echo "centos"
  else
    echo "unknown"
  fi
}

# 安装 Docker (Ubuntu/Debian/CentOS/Arch)
install_docker() {
  local os="$1"
  log "安装 Docker..."

  case "$os" in
    ubuntu|debian)
      apt-get update
      apt-get install -y ca-certificates curl gnupg lsb-release
      curl -fsSL https://download.docker.com/linux/$os/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/$os $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
      apt-get update
      apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
      ;;
    centos|rocky|almalinux)
      yum install -y yum-utils
      yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
      yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
      systemctl start docker
      systemctl enable docker
      ;;
    arch)
      pacman -S docker docker-compose
      systemctl start docker
      systemctl enable docker
      ;;
    *)
      error "不支持的操作系统: $os。请手动安装 Docker: https://docs.docker.com/engine/install/"
      ;;
  esac

  success "Docker 安装完成"
  docker --version
  docker compose version
}

# 检查并升级 Docker Compose
ensure_docker_compose_v2() {
  log "检查 Docker Compose 版本..."

  if docker compose version &>/dev/null; then
    local v2_version=$(docker compose version | head -1)
    success "Docker Compose v2 已安装: $v2_version"
  else
    warn "Docker Compose v2 未找到，尝试安装..."
    # 通常 docker compose plugin 应该随 Docker 一起安装
    # 如果没有，根据 OS 安装
    local os="$(detect_os)"
    install_docker "$os"
  fi
}

# 检查磁盘空间
check_disk_space() {
  log "检查磁盘空间..."
  local available_gb=$(df -BG / | tail -1 | awk '{print $4}' | sed 's/G//')

  if [[ $available_gb -lt $MIN_DISK_GB ]]; then
    error "磁盘空间不足！需要至少 ${MIN_DISK_GB}GB，当前只有 ${available_gb}GB"
  else
    success "磁盘空间充足: ${available_gb}GB (>${MIN_DISK_GB}GB 要求)"
  fi
}

# 检查内存
check_memory() {
  log "检查内存..."

  if command -v free &>/dev/null; then
    local total_mb=$(free -m | awk '/^Mem:/ {print $2}')
    local total_gb=$((total_mb / 1024))

    if [[ $total_gb -lt $MIN_MEMORY_GB ]]; then
      warn "内存较小: ${total_gb}GB (建议至少 ${MIN_MEMORY_GB}GB)"
      read -rp "是否继续？(y/N): " confirm
      if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        exit 1
      fi
    else
      success "内存充足: ${total_gb}GB"
    fi
  else
    warn "无法检测内存 (free 命令不可用)"
  fi
}

# 检查端口冲突
check_ports() {
  log "检查端口冲突..."

  local conflicts=()
  local all_ports=("${CONFLICT_PORTS[@]}" $(seq 8000 8100))  # 扩展端口范围

  for port in "${all_ports[@]}"; do
    if ss -tuln | grep -q ":$port "; then
      conflicts+=("$port")
    fi
  done

  if [[ ${#conflicts[@]} -gt 0 ]]; then
    warn "发现端口被占用: ${conflicts[*]}"
    echo "这些端口可能被其他服务占用，会影响 Homelab Stack 启动。"
    read -rp "是否继续？(y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      exit 1
    fi
  else
    success "无端口冲突"
  fi
}

# 检查当前用户
check_user() {
  log "检查用户权限..."

  if [[ $EUID -eq 0 ]]; then
    warn "当前为 root 用户，建议使用普通用户 + docker 组"
    read -rp "是否创建/添加当前用户到 docker 组？(y/N): " add_user
    if [[ "$add_user" =~ ^[Yy]$ ]]; then
      local current_user="${SUDO_USER:-$USER}"
      if id "$current_user" &>/dev/null; then
        usermod -aG docker "$current_user" 2>/dev/null || true
        success "已添加 $current_user 到 docker 组"
        warn "请重新登录以使组权限生效"
      fi
    fi
  else
    if groups | grep -q docker; then
      success "当前用户已加入 docker 组"
    else
      warn "当前用户未加入 docker 组，可能需要 sudo"
    fi
  fi
}

# 生成 .env 文件
generate_env() {
  log "生成环境配置文件..."

  local env_file="$BASE_DIR/.env"

  if [[ -f "$env_file" && ! $FORCE ]]; then
    warn ".env 文件已存在，跳过生成 (使用 --force 覆盖)"
    return
  fi

  # 收集输入
  question "请输入主域名 (例如 homelab.example.com):"
  read -r domain

  question "请输入 ACME 邮箱 (Let's Encrypt 证书通知):"
  read -r acme_email

  question "请输入 Traefik Dashboard 用户名 [admin]:"
  read -r traefik_user
  traefik_user=${traefik_user:-admin}

  question "请输入 Traefik Dashboard 密码 (留空随机生成):"
  read -rs traefik_password
  echo
  if [[ -z "$traefik_password" ]]; then
    traefik_password=$(openssl rand -base64 12 2>/dev/null || echo "changeme_$(date +%s)")
    success "生成的密码: $traefik_password"
  fi

  # 生成 Basic Auth hash
  local basic_auth_hash=$(echo -n "$traefik_user:$traefik_password" | openssl base64 2>/dev/null || echo "YWRtaW46JGFwcGxmOyQkOV5bWfp6TkRHaHF2R3R6Igo=")

  # 写入 .env
  cat > "$env_file" <<EOF
# Homelab Stack 环境配置
# 生成时间: $(date)

# 基础环境
TZ=Asia/Shanghai
DOMAIN=$domain
ACME_EMAIL=$acme_email

# Traefik 认证
TRAEFIK_USER=$traefik_user
TRAEFIK_PASSWORD=$traefik_password
TRAEFIK_BASIC_AUTH_HASH=$basic_auth_hash

# 数据保留策略 (可选)
PROMETHEUS_RETENTION=30d
LOKI_RETENTION=7d
TEMPO_RETENTION=3d

# 通知 (可选，如果部署 Notifications Stack)
# NTFY_TOKEN=your-ntfy-token

# OIDC 集成 (可选，如果部署 SSO Stack)
# GRAFANA_OAUTH_ENABLED=true
# GRAFANA_OAUTH_CLIENT_ID=grafana
# GRAFANA_OAUTH_CLIENT_SECRET=your-client-secret
EOF

  success ".env 文件已生成: $env_file"
}

# 启动 Base Stack
start_base_stack() {
  log "启动 Base Infrastructure Stack..."

  local compose_file="$STACKS_DIR/base/docker-compose.yml"

  if [[ ! -f "$compose_file" ]]; then
    error "Base Stack docker-compose.yml 不存在: $compose_file"
  fi

  # 检查 proxy 网络
  if ! docker network ls --format '{{.Name}}' | grep -q '^proxy$'; then
    log "创建 proxy 网络..."
    docker network create proxy 2>/dev/null || true
  fi

  # 启动
  log "执行: docker compose -f $compose_file up -d"
  if docker compose -f "$compose_file" up -d; then
    success "Base Stack 启动命令已执行"
  else
    error "Base Stack 启动失败，请检查日志"
  fi
}

# 等待服务健康
wait_for_health() {
  local timeout=180
  local start=$(date +%s)

  log "等待所有容器健康 (超时 ${timeout}s)..."

  while true; do
    # 检查是否有不健康的容器
    local unhealthy=$(docker ps --filter "health=unhealthy" --format '{{.Names}}' 2>/dev/null | wc -l | tr -d ' ')
    local restarting=$(docker ps --filter "status=restarting" --format '{{.Names}}' 2>/dev/null | wc -l | tr -d ' ')

    if [[ $unhealthy -eq 0 && $restarting -eq 0 ]]; then
      success "所有容器健康！"
      return 0
    fi

    # 显示进度
    local elapsed=$(( $(date +%s) - start ))
    if (( elapsed % 30 == 0 )); then
      log "等待中... (${elapsed}s / ${timeout}s)"
    fi

    if [[ $elapsed -ge $timeout ]]; then
      error "超时！有容器未达到健康状态"
    fi

    sleep 3
  done
}

# 显示完成信息
show_summary() {
  echo
  echo "╔════════════════════════════════════════════════════════════╗"
  echo "║           🎉 Homelab Stack 安装完成！                   ║"
  echo "╚════════════════════════════════════════════════════════════╝"
  echo
  echo "📋 下一步:"
  echo "  1. 验证 DNS 解析: ${DOMAIN:-your-domain} → 服务器 IP"
  echo "  2. 访问 Traefik Dashboard: https://traefik.${DOMAIN:-your-domain}"
  echo "  3. 访问 Portainer: https://portainer.${DOMAIN:-your-domain}"
  echo "  4. 开始部署其他 Stack (Notifications, Media, SSO, ...)"
  echo
  echo "📚 文档:"
  echo "  - 安装说明: stacks/base/README.md"
  echo "  - 部署指南: homelab.md"
  echo "  - 测试脚本: tests/run-tests.sh"
  echo
  echo "💡 提示:"
  echo "  - 如在国内，运行: sudo ./scripts/setup-cn-mirrors.sh"
  echo "  - 检查网络: ./scripts/check-connectivity.sh"
  echo "  - 运行测试: cd tests && ./run-tests.sh --all"
  echo
}

# ═══════════════════════════════════════════════════════════════════════════
# 主流程
# ═══════════════════════════════════════════════════════════════════════════

show_banner() {
  cat <<"EOF"
╔═══════════════════════════════════════════╗
║     Homelab Stack — 智能安装脚本        ║
║     Robustness by Design                 ║
╚═══════════════════════════════════════════╝

EOF
}

main() {
  show_banner

  # 解析参数
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --skip-docker)
        SKIP_DOCKER=true
        shift
        ;;
      --skip-checks)
        SKIP_CHECKS=true
        shift
        ;;
      --force)
        FORCE=true
        shift
        ;;
      --help|-h)
        cat <<HELP
用法: $0 [OPTIONS]

选项:
  --skip-docker    跳过 Docker 安装检查
  --skip-checks   跳过资源检查 (磁盘/内存/端口)
  --force         覆盖已存在的 .env 文件
  --help          显示此帮助

示例:
  $0                 # 完整安装 (交互式)
  $0 --skip-docker  # 假设 Docker 已安装，只配置应用

EOF
        exit 0
        ;;
      *)
        error "未知选项: $1"
        ;;
    esac
  done

  # 1. 检查 Docker (除非跳过)
  if ! $SKIP_DOCKER; then
    if ! command -v docker &>/dev/null; then
      log "Docker 未安装，开始自动安装..."
      install_docker "$(detect_os)"
    else
      success "Docker 已安装: $(docker --version | head -1)"
    fi

    ensure_docker_compose_v2
  else
    log "跳过 Docker 安装检查"
  fi

  # 2. 资源检查 (除非跳过)
  if ! $SKIP_CHECKS; then
    check_disk_space
    check_memory
    check_ports
  else
    log "跳过资源检查"
  fi

  # 3. 检查用户权限
  check_user

  # 4. 生成 .env
  generate_env

  # 5. 启动 Base Stack
  start_base_stack

  # 6. 等待健康
  wait_for_health

  # 7. 完成
  show_summary
}

main "$@"