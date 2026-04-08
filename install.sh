#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Robust Installer
# =============================================================================
set -euo pipefail
IFS=$'\n\t'

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

LOG_FILE="$HOME/.homelab/install.log"
mkdir -p "$(dirname "$LOG_FILE")"

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; echo "[INFO] $*" >> "$LOG_FILE"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; echo "[WARN] $*" >> "$LOG_FILE"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; echo "[ERROR] $*" >> "$LOG_FILE"; }
log_step()  { echo -e "\n${BLUE}${BOLD}==> $*${NC}"; echo "[STEP] $*" >> "$LOG_FILE"; }

# Network retry wrapper
curl_retry() {
  local max_attempts=3
  local delay=5
  local url=$1
  shift
  
  for i in $(seq 1 $max_attempts); do
    echo "尝试 $i/$max_attempts: $url" >> "$LOG_FILE"
    if curl --connect-timeout 10 --max-time 60 "$url" "$@" 2>> "$LOG_FILE"; then
      return 0
    fi
    if [[ $i -lt $max_attempts ]]; then
      log_warn "下载失败，${delay}秒后重试..."
      sleep $delay
      delay=$((delay * 2))
    fi
  done
  log_error "下载失败: $url"
  return 1
}

cleanup() {
  if [[ $? -ne 0 ]]; then
    log_error "安装失败。查看日志: $LOG_FILE"
  fi
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Banner
# ---------------------------------------------------------------------------
echo -e ""
echo -e "${BOLD}  ██╗  ██╗ ██████╗ ███╗   ███╗███████╗██╗      █████╗ ██████╗ ${NC}"
echo -e "${BOLD}  ██║  ██║██╔═══██╗████╗ ████║██╔════╝██║     ██╔══██╗██╔══██╗${NC}"
echo -e "${BOLD}  ███████║██║   ██║██╔████╔██║█████╗  ██║     ███████║██████╔╝${NC}"
echo -e "${BOLD}  ██╔══██║██║   ██║██║╚██╔╝██║██╔══╝  ██║     ██╔══██║██╔══██╗${NC}"
echo -e "${BOLD}  ██║  ██║╚██████╔╝██║ ╚═╝ ██║███████╗███████╗██║  ██║██████╔╝${NC}"
echo -e "${BOLD}  ╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝╚═════╝ ${NC}"
echo -e "${BOLD}                    S T A C K   v1.0.0${NC}"
echo -e ""
echo -e "日志文件: $LOG_FILE"
echo ""

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------

# Check if running as root
if [[ $EUID -eq 0 ]]; then
  log_warn "检测到以 root 用户运行"
  log_warn "建议使用普通用户运行，必要时会提示 sudo"
  read -p "是否继续? (y/N): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

# Check system requirements
log_step "系统资源检查"

# Memory check
MEMORY_GB=$(free -g | awk '/^Mem:/{print $2}')
if [[ $MEMORY_GB -lt 2 ]]; then
  log_warn "内存不足 2GB (当前: ${MEMORY_GB}GB)，部分服务可能无法正常运行"
  read -p "是否继续? (y/N): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
elif [[ $MEMORY_GB -lt 4 ]]; then
  log_warn "内存较低 (当前: ${MEMORY_GB}GB)，建议 4GB 以上"
fi

# Disk space check
DISK_GB=$(df -BG / | awk 'NR==2 {gsub(/G/,"",$4); print $4}')
if [[ $DISK_GB -lt 5 ]]; then
  log_error "磁盘空间不足 5GB (当前: ${DISK_GB}GB)，无法继续安装"
  exit 1
elif [[ $DISK_GB -lt 20 ]]; then
  log_warn "磁盘空间不足 20GB (当前: ${DISK_GB}GB)，可能影响长期使用"
fi

log_info "系统资源检查通过"

# Port conflict check
log_step "端口冲突检测"
PORT_CONFLICT=0
for port in 53 80 443 3000 8080 9000; do
  if ss -tlnp 2>/dev/null | grep -q ":${port} " || netstat -tlnp 2>/dev/null | grep -q ":${port} "; then
    log_warn "端口 $port 已被占用"
    PORT_CONFLICT=1
  fi
done

if [[ $PORT_CONFLICT -eq 1 ]]; then
  log_warn "检测到端口冲突，某些服务可能无法启动"
  log_warn "请停止占用端口的服务或修改 docker-compose.yml 中的端口映射"
  read -p "是否继续? (y/N): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
else
  log_info "端口检查通过"
fi

# Firewall check
log_step "防火墙检查"
if command -v ufw &>/dev/null && ufw status | grep -q "Status: active"; then
  log_warn "UFW 防火墙已启用，请确保以下端口已开放:"
  log_warn "  - 80/tcp (HTTP)"
  log_warn "  - 443/tcp (HTTPS)"
  log_info "运行: sudo ufw allow 80/tcp && sudo ufw allow 443/tcp"
elif command -v firewall-cmd &>/dev/null && firewall-cmd --state 2>/dev/null | grep -q "running"; then
  log_warn "Firewalld 防火墙已启用，请确保以下端口已开放:"
  log_warn "  - 80/tcp (HTTP)"
  log_warn "  - 443/tcp (HTTPS)"
  log_info "运行: sudo firewall-cmd --add-port=80/tcp --permanent && sudo firewall-cmd --add-port=443/tcp --permanent"
fi

# ---------------------------------------------------------------------------
# Docker installation
# ---------------------------------------------------------------------------
log_step "Docker 环境检查"

if ! command -v docker &>/dev/null; then
  log_warn "Docker 未安装"
  read -p "是否自动安装 Docker? (y/N): " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "开始安装 Docker..."
    
    # Detect OS
    if [[ -f /etc/debian_version ]] || [[ -f /etc/lsb-release ]]; then
      # Ubuntu/Debian
      log_info "检测到 Debian/Ubuntu 系统"
      curl_retry https://get.docker.com | sudo bash
    elif [[ -f /etc/centos-release ]] || [[ -f /etc/redhat-release ]]; then
      # CentOS/RHEL
      log_info "检测到 CentOS/RHEL 系统"
      sudo yum install -y yum-utils
      sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
      sudo yum install -y docker-ce docker-ce-cli containerd.io
      sudo systemctl start docker
      sudo systemctl enable docker
    elif [[ -f /etc/arch-release ]]; then
      # Arch Linux
      log_info "检测到 Arch Linux 系统"
      sudo pacman -S --noconfirm docker
      sudo systemctl start docker
      sudo systemctl enable docker
    else
      log_error "不支持的操作系统，请手动安装 Docker"
      exit 1
    fi
    
    # Add user to docker group
    if [[ $EUID -ne 0 ]]; then
      log_info "将当前用户添加到 docker 组..."
      sudo usermod -aG docker "$USER"
      log_warn "请注销并重新登录以使组权限生效"
      log_warn "然后重新运行此脚本"
      exit 0
    fi
  else
    log_error "Docker 是必需的依赖。请先安装 Docker"
    exit 1
  fi
else
  log_info "Docker 已安装: $(docker --version)"
fi

# Check Docker daemon
if ! docker info &>/dev/null; then
  log_error "Docker 守护进程未运行"
  log_info "尝试启动 Docker..."
  if [[ $EUID -eq 0 ]]; then
    systemctl start docker
  else
    sudo systemctl start docker
  fi
  sleep 3
  if ! docker info &>/dev/null; then
    log_error "Docker 启动失败，请手动启动: sudo systemctl start docker"
    exit 1
  fi
fi

# Docker Compose check
if ! docker compose version &>/dev/null; then
  if command -v docker-compose &>/dev/null; then
    log_warn "检测到 Docker Compose v1 (独立版)"
    log_warn "建议升级到 Docker Compose v2 (插件)"
    log_info "参考: https://docs.docker.com/compose/migrate/"
    read -p "是否继续使用 v1? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      exit 1
    fi
    # Create wrapper
    log_info "创建 docker compose 别名..."
    mkdir -p ~/.local/bin
    cat > ~/.local/bin/docker <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "compose" ]]; then
  shift
  docker-compose "$@"
else
  /usr/bin/docker "$@"
fi
EOF
    chmod +x ~/.local/bin/docker
    export PATH="$HOME/.local/bin:$PATH"
  else
    log_error "Docker Compose 未安装"
    exit 1
  fi
else
  log_info "Docker Compose 已安装: $(docker compose version --short)"
fi

# Non-root user check
if [[ $EUID -ne 0 ]] && ! groups | grep -q docker; then
  log_warn "当前用户不在 docker 组中"
  read -p "是否添加到 docker 组? (y/N): " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo usermod -aG docker "$USER"
    log_warn "已添加到 docker 组。请注销并重新登录以生效"
    log_warn "然后重新运行此脚本"
    exit 0
  else
    log_error "需要 docker 组权限才能继续"
    exit 1
  fi
fi

# ---------------------------------------------------------------------------
# Check dependencies
# ---------------------------------------------------------------------------
log_step "检查依赖项"
bash "$(dirname "$0")/scripts/check-deps.sh"

# ---------------------------------------------------------------------------
# CN network detection
# ---------------------------------------------------------------------------
log_step "网络环境检测"
bash "$(dirname "$0")/scripts/check-connectivity.sh"

if [[ $? -ne 0 ]]; then
  log_warn "检测到网络问题"
  read -p "是否配置国内镜像加速? (y/N): " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo bash "$(dirname "$0")/scripts/setup-cn-mirrors.sh"
  fi
fi

# ---------------------------------------------------------------------------
# Setup environment
# ---------------------------------------------------------------------------
log_step "环境配置"
if [[ ! -f .env ]]; then
  bash "$(dirname "$0")/scripts/setup-env.sh"
else
  log_warn ".env 已存在，跳过配置。删除后可重新配置。"
fi

# ---------------------------------------------------------------------------
# Create data directories
# ---------------------------------------------------------------------------
log_step "创建数据目录"
mkdir -p \
  data/traefik/certs \
  data/portainer \
  data/prometheus \
  data/grafana \
  data/loki \
  data/authentik/media \
  data/nextcloud \
  data/gitea \
  data/vaultwarden

chmod 600 config/traefik/acme.json 2>/dev/null || touch config/traefik/acme.json && chmod 600 config/traefik/acme.json

# ---------------------------------------------------------------------------
# Create proxy network
# ---------------------------------------------------------------------------
log_step "创建 Docker 网络"
if ! docker network inspect proxy &>/dev/null; then
  log_info "创建 proxy 网络..."
  docker network create proxy
else
  log_info "proxy 网络已存在"
fi

# ---------------------------------------------------------------------------
# Launch base infrastructure
# ---------------------------------------------------------------------------
log_step "启动基础基础设施"
docker compose -f docker-compose.base.yml up -d

# Wait for healthy
log_info "等待服务启动..."
sleep 5

# Check if containers are running
if docker compose -f docker-compose.base.yml ps | grep -q "Exit"; then
  log_error "部分容器启动失败"
  docker compose -f docker-compose.base.yml ps
  log_info "查看日志: docker compose -f docker-compose.base.yml logs"
  exit 1
fi

# ---------------------------------------------------------------------------
# Success
# ---------------------------------------------------------------------------
log_info ""
log_info "${GREEN}${BOLD}✓ 基础基础设施已启动!${NC}"
log_info ""
log_info "后续步骤:"
log_info "  1. 配置 SSO (推荐首先设置):"
log_info "     ./scripts/stack-manager.sh start sso"
log_info ""
log_info "  2. 启动监控:"
log_info "     ./scripts/stack-manager.sh start monitoring"
log_info ""
log_info "  3. 查看所有可用服务:"
log_info "     ./scripts/stack-manager.sh list"
log_info ""
log_info "  4. 如遇问题，运行诊断:"
log_info "     ./scripts/diagnose.sh"
log_info ""
log_info "文档: docs/getting-started.md"
log_info "日志: $LOG_FILE"
