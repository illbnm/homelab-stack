#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Installer
# =============================================================================
set -uo pipefail
IFS=$'\n\t'

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$SCRIPT_DIR"
BASE_STACK="$BASE_DIR/stacks/base/docker-compose.yml"

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()  { echo -e "\n${BLUE}${BOLD}==> $*${NC}"; }
log_ok()    { echo -e "${GREEN}  ✓ $*${NC}"; }

cleanup() {
  if [[ $? -ne 0 ]]; then
    log_error "Installation failed. Check logs."
    log_info "Common fixes:"
    log_info "  • sudo ./scripts/setup-cn-mirrors.sh  # if network issues"
    log_info "  • docker network create proxy         # if network missing"
  fi
}
trap cleanup EXIT

# ============================================================================
# Utility: curl with retry + exponential backoff
# ============================================================================
curl_retry() {
  local max_attempts=3
  local delay=5
  for i in $(seq 1 $max_attempts); do
    if curl --connect-timeout 10 --max-time 60 "$@" 2>/dev/null; then
      return 0
    fi
    if [[ $i -lt $max_attempts ]]; then
      echo -e "${YELLOW}[curl_retry] Attempt $i failed, retrying in ${delay}s...${NC}" >&2
      sleep $delay
      delay=$((delay * 2))
    fi
  done
  return 1
}

# ============================================================================
# Check: disk space (< 5GB = hard block, < 20GB = warn)
# ============================================================================
check_disk_space() {
  log_step "Checking disk space"
  local free_gb
  free_gb=$(df -BG / | awk 'NR==2 {gsub(/G/,"",$4); print $4}')

  if [[ "$free_gb" -lt 5 ]]; then
    log_error "Insufficient disk space: ${free_gb}GB free. Need at least 5GB."
    log_error "Free up space with: docker system prune -a"
    exit 1
  elif [[ "$free_gb" -lt 20 ]]; then
    log_warn "Low disk space: ${free_gb}GB free. Recommend >= 20GB."
    log_warn "Free up space with: docker system prune -a"
  else
    log_ok "Disk space: ${free_gb}GB free"
  fi
}

# ============================================================================
# Check: memory (< 2GB = warn)
# ============================================================================
check_memory() {
  log_step "Checking memory"
  local mem_kb mem_gb
  mem_kb=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
  mem_gb=$(echo "scale=1; $mem_kb / 1024 / 1024" | bc -l 2>/dev/null || echo "unknown")

  local mem_int
  mem_int=$(echo "$mem_kb / 1024 / 1024" | bc -l 2>/dev/null || echo 0)

  if [[ "$mem_int" -lt 2 ]]; then
    log_warn "Low memory: ~${mem_gb}GB available. Some services may struggle."
  else
    log_ok "Memory: ~${mem_gb}GB available"
  fi
}

# ============================================================================
# Check: port conflicts (53, 80, 443, 3000, 8080, 9000)
# ============================================================================
check_port_conflicts() {
  log_step "Checking port conflicts"
  local conflicts=0
  for port in 53 80 443 2375 3000 3001 8080 8096 8123 9000 9001 9090 1880 2586 51820; do
    if ss -tlnp 2>/dev/null | grep -q ":${port} " || \
       netstat -tlnp 2>/dev/null | grep -q ":${port} "; then
      log_warn "Port $port is already in use — some services will fail to bind"
      ((conflicts++))
    fi
  done
  [[ "$conflicts" -eq 0 ]] && log_ok "All critical ports are available"
}

# ============================================================================
# Check: non-root user → add to docker group
# ============================================================================
check_docker_group() {
  if [[ "$EUID" -ne 0 ]]; then
    if groups | grep -q docker; then
      log_ok "Current user is in docker group"
    else
      log_warn "Current user is not in docker group."
      log_info "Run: sudo usermod -aG docker $USER && newgrp docker"
    fi
  fi
}

# ============================================================================
# Check: firewall rules
# ============================================================================
check_firewall() {
  log_step "Checking firewall"
  if command -v ufw &>/dev/null && ufw status 2>/dev/null | grep -q "Status: active"; then
    log_warn "UFW firewall is active — ensure ports 80/443 are allowed:"
    log_info "  sudo ufw allow 80/tcp"
    log_info "  sudo ufw allow 443/tcp"
  elif command -v firewalld &>/dev/null && systemctl is-active firewalld &>/dev/null; then
    log_warn "firewalld is active — ensure ports 80/443 are allowed:"
    log_info "  sudo firewall-cmd --permanent --add-port=80/tcp"
    log_info "  sudo firewall-cmd --permanent --add-port=443/tcp"
    log_info "  sudo firewall-cmd --reload"
  else
    log_ok "No active firewall detected"
  fi
}

# ============================================================================
# Install Docker if missing
# ============================================================================
install_docker() {
  if command -v docker &>/dev/null; then
    log_info "Docker already installed: $(docker --version 2>&1 | head -1)"
    return 0
  fi

  log_warn "Docker not installed. Attempting to install..."

  local os
  os=$(grep "^ID=" /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')

  case "$os" in
    ubuntu|debian)
      log_info "Detected Debian/Ubuntu — installing Docker..."
      curl_retry -fsSL https://get.docker.com | sh
      ;;
    fedora|rhel|centos|rocky|alma)
      log_info "Detected RHEL/Fedora — installing Docker..."
      curl_retry -fsSL https://get.docker.com | sh
      ;;
    arch)
      log_info "Detected Arch — installing Docker..."
      sudo pacman -S --noconfirm docker
      ;;
    *)
      log_error "Cannot auto-install Docker on OS: $os"
      log_info "Please install Docker manually: https://docs.docker.com/get-docker/"
      exit 1
      ;;
  esac

  log_ok "Docker installed"
  log_info "Starting Docker daemon..."
  sudo systemctl start docker 2>/dev/null || sudo service docker start 2>/dev/null || true
  sudo systemctl enable docker 2>/dev/null || true
}

# ============================================================================
# Banner
# ============================================================================
echo -e ""
echo -e "${BOLD}  ██╗  ██╗ ██████╗ ███╗   ███╗███████╗██╗      █████╗ ██████╗ ${NC}"
echo -e "${BOLD}  ██║  ██║██╔═══██╗████╗ ████║██╔════╝██║     ██╔══██╗██╔══██╗${NC}"
echo -e "${BOLD}  ███████║██║   ██║██╔████╔██║█████╗  ██║     ███████║██████╔╝${NC}"
echo -e "${BOLD}  ██╔══██║██║   ██║██║╚██╔╝██║██╔══╝  ██║     ██╔══██║██╔══██╗${NC}"
echo -e "${BOLD}  ██║  ██║╚██████╔╝██║ ╚═╝ ██║███████╗███████╗██║  ██║██████╔╝${NC}"
echo -e "${BOLD}  ╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝╚═════╝ ${NC}"
echo -e "${BOLD}                    S T A C K   v1.0.0${NC}"
echo -e ""

# ============================================================================
# Pre-flight checks
# ============================================================================
check_disk_space
check_memory
check_port_conflicts
check_firewall
check_docker_group

# ============================================================================
# Docker install (if missing)
# ============================================================================
install_docker

# ============================================================================
# Step 1: Dependencies
# ============================================================================
log_step "Checking dependencies"
if ! bash "$SCRIPT_DIR/scripts/check-deps.sh"; then
  log_error "Dependency check failed. Please fix the issues above."
  exit 1
fi

# ============================================================================
# Step 2: CN network detection
# ============================================================================
log_step "Network environment detection"
if curl_retry --connect-timeout 3 --max-time 5 \
  -o /dev/null -w '%{http_code}' "https://gcr.io" 2>/dev/null | grep -qv "200\|301\|302"; then
  log_warn "Detected China mainland network"
  log_info "Consider running: sudo ./scripts/setup-cn-mirrors.sh"
  log_info "Then: ./scripts/localize-images.sh --cn"
fi

# ============================================================================
# Step 3: Setup environment
# ============================================================================
log_step "Environment configuration"
if [[ ! -f "$BASE_DIR/.env" ]]; then
  cp "$BASE_DIR/.env.example" "$BASE_DIR/.env"
  log_info ".env created from .env.example — please edit it with your settings"
  log_info "  DOMAIN=yourdomain.com"
  log_info "  ACME_EMAIL=you@example.com"
  log_info "  Then re-run this installer"
  exit 0
else
  log_ok ".env already exists"
fi

# ============================================================================
# Step 4: Create Docker network
# ============================================================================
log_step "Setting up Docker network"
if docker network inspect proxy &>/dev/null; then
  log_ok "Docker network 'proxy' already exists"
else
  log_info "Creating docker network 'proxy'..."
  docker network create proxy 2>/dev/null && log_ok "Created 'proxy' network" || \
    log_error "Failed to create 'proxy' network"
fi

# ============================================================================
# Step 5: Create data directories & permissions
# ============================================================================
log_step "Creating data directories"
mkdir -p \
  "$BASE_DIR/data/traefik/certs" \
  "$BASE_DIR/data/portainer" \
  "$BASE_DIR/data/prometheus" \
  "$BASE_DIR/data/grafana" \
  "$BASE_DIR/data/loki" \
  "$BASE_DIR/data/authentik/media" \
  "$BASE_DIR/data/nextcloud" \
  "$BASE_DIR/data/gitea" \
  "$BASE_DIR/data/vaultwarden"

touch "$BASE_DIR/config/traefik/acme.json"
chmod 600 "$BASE_DIR/config/traefik/acme.json"
log_ok "Data directories and acme.json permissions set"

# ============================================================================
# Step 6: Launch base infrastructure
# ============================================================================
log_step "Launching base infrastructure"

if [[ ! -f "$BASE_STACK" ]]; then
  log_error "Base stack not found: $BASE_STACK"
  exit 1
fi

log_info "Starting base stack..."
if docker compose -f "$BASE_STACK" config --quiet 2>/dev/null; then
  docker compose -f "$BASE_STACK" up -d
  log_ok "Base infrastructure is up!"

  log_info "Waiting for containers to be healthy..."
  if bash "$SCRIPT_DIR/scripts/wait-healthy.sh" --stack base --timeout 120 2>/dev/null; then
    log_ok "All base containers healthy"
  else
    log_warn "Some containers may not be healthy yet"
    log_info "Run: docker compose -f stacks/base/docker-compose.yml ps"
  fi
else
  log_error "Base stack docker-compose.yml has syntax errors"
  docker compose -f "$BASE_STACK" config 2>&1 | head -20
  exit 1
fi

# ============================================================================
# Done
# ============================================================================
echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║            HomeLab Stack deployed successfully!         ║${NC}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
log_info "Next steps:"
log_info "  1. Edit .env with your domain and credentials"
log_info "  2. ./scripts/stack-manager.sh start sso        # Set up SSO first (recommended)"
log_info "  3. ./scripts/stack-manager.sh start monitoring # Launch monitoring"
log_info "  4. ./scripts/stack-manager.sh list             # See all available stacks"
log_info ""
log_info "Diagnostics:"
log_info "  ./scripts/check-connectivity.sh                # Network diagnostics"
log_info "  ./scripts/diagnose.sh                          # Full system report"
log_info ""
log_info "Documentation: docs/getting-started.md"
