#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Installer
# 增强鲁棒性：支持国内网络、自动安装 Docker、端口冲突检测、磁盘检查
# =============================================================================
set -euo pipefail
IFS=$'\n\t'

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()  { echo -e "\n${BLUE}${BOLD}==> $*${NC}"; }

# 网络请求重试包装函数
curl_retry() {
  local max_attempts=3
  local delay=5
  for i in $(seq 1 $max_attempts); do
    curl --connect-timeout 10 --max-time 60 "$@" && return 0
    log_warn "Attempt $i failed, retrying in ${delay}s..."
    sleep $delay
    delay=$((delay * 2))
  done
  return 1
}

# 清理函数
cleanup() {
  if [[ $? -ne 0 ]]; then
    log_error "Installation failed. Check logs at ~/.homelab/install.log"
  fi
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# 鲁棒性增强：Docker 安装
# ---------------------------------------------------------------------------
install_docker() {
  log_step "Installing Docker..."
  
  local os_id
  os_id=$(grep -i '^ID=' /etc/os-release 2>/dev/null | cut -d'=' -f2 | tr -d '"' || echo "unknown")
  
  case "$os_id" in
    ubuntu|debian)
      log_info "Detected Debian/Ubuntu, installing Docker..."
      curl_retry -fsSL https://get.docker.com -o /tmp/get-docker.sh
      sudo bash /tmp/get-docker.sh
      rm -f /tmp/get-docker.sh
      ;;
    centos|rhel|fedora)
      log_info "Detected RHEL/CentOS/Fedora, installing Docker..."
      curl_retry -fsSL https://get.docker.com -o /tmp/get-docker.sh
      sudo bash /tmp/get-docker.sh
      rm -f /tmp/get-docker.sh
      ;;
    arch|manjaro)
      log_info "Detected Arch/Manjaro, installing Docker..."
      sudo pacman -Sy --noconfirm docker docker-compose
      sudo systemctl enable docker
      sudo systemctl start docker
      ;;
    *)
      log_error "Unsupported OS: $os_id. Please install Docker manually."
      log_error "Visit: https://docs.docker.com/get-docker/"
      exit 1
      ;;
  esac
  
  # 添加当前用户到 docker 组
  if ! groups | grep -q '\bdocker\b'; then
    log_info "Adding user to docker group..."
    sudo usermod -aG docker "${USER:-$(whoami)}"
    log_warn "You may need to log out and back in for group changes to take effect"
  fi
  
  log_info "Docker installed successfully"
}

# ---------------------------------------------------------------------------
# 鲁棒性增强：检查 Docker Compose 版本
# ---------------------------------------------------------------------------
check_compose_version() {
  log_step "Checking Docker Compose version..."
  
  if ! command -v docker &>/dev/null; then
    log_error "Docker is not installed"
    return 1
  fi
  
  # 检查是否是 Compose V2
  if docker compose version &>/dev/null; then
    log_info "Docker Compose V2 detected"
    return 0
  fi
  
  # 检查是否是 Compose V1
  if docker-compose version &>/dev/null; then
    local version
    version=$(docker-compose version --short 2>/dev/null || echo "0.0.0")
    log_warn "Docker Compose V1 detected ($version), V2 is recommended"
    log_warn "Consider upgrading: sudo apt-get install docker-compose-plugin"
    return 0
  fi
  
  log_error "Docker Compose not found"
  return 1
}

# ---------------------------------------------------------------------------
# 鲁棒性增强：端口冲突检测
# ---------------------------------------------------------------------------
check_port_conflicts() {
  log_step "Checking for port conflicts..."
  
  local ports=("53" "80" "443" "3000" "8080" "9000")
  local conflicts=0
  
  for port in "${ports[@]}"; do
    if sudo ss -tlnp | grep -q ":$port "; then
      local process
      process=$(sudo ss -tlnp | grep ":$port " | awk '{print $7}' | cut -d'"' -f2 || echo "unknown")
      log_warn "Port $port is already in use by: $process"
      ((conflicts++))
    else
      log_info "Port $port is available"
    fi
  done
  
  if [[ $conflicts -gt 0 ]]; then
    log_warn "Found $conflicts port conflict(s). You may need to:"
    log_warn "  1. Stop conflicting services"
    log_warn "  2. Change ports in .env file"
    echo ""
  fi
  
  return 0
}

# ---------------------------------------------------------------------------
# 鲁棒性增强：磁盘空间检查
# ---------------------------------------------------------------------------
check_disk_space() {
  log_step "Checking disk space..."
  
  local available_gb
  available_gb=$(df -BG "$PWD" | tail -1 | awk '{print $4}' | tr -d 'G')
  
  log_info "Available disk space: ${available_gb}GB"
  
  if [[ $available_gb -lt 10 ]]; then
    log_error "Insufficient disk space (< 10GB). Need at least 10GB for base installation."
    return 1
  elif [[ $available_gb -lt 20 ]]; then
    log_warn "Disk space is low (< 20GB). Consider freeing up space for full deployment."
  else
    log_info "Disk space is sufficient"
  fi
  
  return 0
}

# ---------------------------------------------------------------------------
# Step 0: Pre-installation checks (鲁棒性增强)
# ---------------------------------------------------------------------------
log_step "Pre-installation checks"

# Check Docker installation
if ! command -v docker &>/dev/null; then
  log_warn "Docker is not installed, attempting to install..."
  install_docker
else
  log_info "Docker is already installed"
fi

# Check Docker Compose version
if ! check_compose_version; then
  log_error "Docker Compose check failed"
  exit 1
fi

# Check disk space
if ! check_disk_space; then
  log_error "Disk space check failed"
  exit 1
fi

# Check port conflicts
check_port_conflicts

# ---------------------------------------------------------------------------
# Banner
# ---------------------------------------------------------------------------
echo -e ""
echo -e "${BOLD}  ██╗  ██╗ ██████╗ ███╗   ███╗███████╗██╗      █████╗ ██████╗ ${NC}"
echo -e "${BOLD}  ██║  ██║██╔═══██╗████╗ ████║██╔════╝██║     ██╔══██╗██╔══██╗${NC}"
echo -e "${BOLD}  ███████║██║   ██║██╔████╔██║█████╗  ██║     ███████║██████╔╝${NC}"
echo -e "${BOLD}  ██║  ██║██║   ██║██║╚██╔╝██║██╔══╝  ██║     ██╔══██║██╔══██╗${NC}"
echo -e "${BOLD}  ██║  ██║╚██████╔╝██║ ╚═╝ ██║███████╗███████╗██║  ██║██████╔╝${NC}"
echo -e "${BOLD}  ╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝╚═════╝ ${NC}"
echo -e "${BOLD}                    S T A C K   v1.0.0${NC}"
echo -e ""

# ---------------------------------------------------------------------------
# Step 1: Check dependencies
# ---------------------------------------------------------------------------
log_step "Checking dependencies"
bash "$(dirname "$0")/scripts/check-deps.sh"

# ---------------------------------------------------------------------------
# Step 2: CN network detection and setup
# ---------------------------------------------------------------------------
log_step "Network environment detection"
if bash "$(dirname "$0")/scripts/check-connectivity.sh 2>&1 | grep -q "FAIL\|SLOW"; then
  log_warn "Network issues detected, offering CN mirror setup..."
  if [[ -x "$(dirname "$0")/scripts/setup-cn-mirrors.sh" ]]; then
    bash "$(dirname "$0")/scripts/setup-cn-mirrors.sh" || true
  fi
fi

# ---------------------------------------------------------------------------
# Step 3: Setup environment
# ---------------------------------------------------------------------------
log_step "Environment configuration"
if [[ ! -f .env ]]; then
  bash "$(dirname "$0")/scripts/setup-env.sh"
else
  log_warn ".env already exists, skipping setup. Remove it to reconfigure."
fi

# ---------------------------------------------------------------------------
# Step 4: Create data directories
# ---------------------------------------------------------------------------
log_step "Creating data directories"
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
# Step 5: Launch base infrastructure
# ---------------------------------------------------------------------------
log_step "Launching base infrastructure"

# Check if base compose file exists
if [[ ! -f docker-compose.base.yml ]]; then
  log_error "docker-compose.base.yml not found!"
  exit 1
fi

# Pull images with retry
log_step "Pulling Docker images (with retry)..."
for i in 1 2 3; do
  if docker compose -f docker-compose.base.yml pull; then
    break
  else
    log_warn "Pull attempt $i failed, retrying..."
    sleep 5
  fi
done

# Start services
docker compose -f docker-compose.base.yml up -d

# Wait for services to be healthy
if [[ -x "$(dirname "$0")/scripts/wait-healthy.sh" ]]; then
  log_step "Waiting for services to be healthy..."
  bash "$(dirname "$0")/scripts/wait-healthy.sh" --file docker-compose.base.yml --timeout 120 || true
fi

log_info ""
log_info "${GREEN}${BOLD}✓ Base infrastructure is up!${NC}"
log_info ""
log_info "Next steps:"
log_info "  ./scripts/stack-manager.sh start sso        # Set up SSO first (recommended)"
log_info "  ./scripts/stack-manager.sh start monitoring # Launch monitoring"
log_info "  ./scripts/stack-manager.sh list             # See all available stacks"
log_info ""
log_info "Documentation: docs/getting-started.md"
