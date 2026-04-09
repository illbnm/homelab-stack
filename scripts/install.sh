#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Robust Installation Script
# Handles: Docker install, port conflicts, disk/memory checks, CN mirror setup.
#
# Usage: ./scripts/install.sh [--skip-docker] [--cn]
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
log_info()    { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()    { echo; echo -e "${CYAN}==>${NC} $*"; }

SKIP_DOCKER=false
CN_MODE=false

for arg in "$@"; do
  case "$arg" in
    --skip-docker) SKIP_DOCKER=true ;;
    --cn)          CN_MODE=true ;;
    --help|-h)     echo "Usage: $0 [--skip-docker] [--cn]"; exit 0 ;;
  esac
done

# ---------------------------------------------------------------------------
# curl with retry (exponential backoff)
# ---------------------------------------------------------------------------
curl_retry() {
  local max_attempts=3
  local delay=5
  for i in $(seq 1 "$max_attempts"); do
    if curl --connect-timeout 10 --max-time 60 -fsSL "$@"; then
      return 0
    fi
    log_warn "Download attempt $i/$max_attempts failed, retrying in ${delay}s..."
    sleep "$delay"
    delay=$((delay * 2))
  done
  log_error "Failed after $max_attempts attempts: $*"
  return 1
}

# ---------------------------------------------------------------------------
# Detect OS
# ---------------------------------------------------------------------------
detect_os() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "${ID}"
  elif command -v lsb_release &>/dev/null; then
    lsb_release -is | tr '[:upper:]' '[:lower:]'
  else
    echo "unknown"
  fi
}

# ---------------------------------------------------------------------------
# Check prerequisites
# ---------------------------------------------------------------------------
check_prerequisites() {
  log_step "Checking prerequisites"

  # Check root or docker group
  if [ "$(id -u)" -ne 0 ]; then
    if ! groups | grep -q docker; then
      log_warn "User not in docker group. Adding..."
      sudo usermod -aG docker "$USER"
      log_warn "Please log out and back in for group changes to take effect."
      log_warn "Then re-run this script."
      exit 1
    fi
  fi

  # Memory check
  local mem_mb
  mem_mb=$(free -m 2>/dev/null | awk '/^Mem:/ {print $2}' || echo 0)
  if [ "$mem_mb" -lt 2048 ]; then
    log_error "Insufficient memory: ${mem_mb}MB (minimum: 2048MB)"
    log_error "Consider adding swap or upgrading your server."
    exit 1
  elif [ "$mem_mb" -lt 4096 ]; then
    log_warn "Low memory: ${mem_mb}MB — some services may not start properly."
  else
    log_info "Memory: ${mem_mb}MB ✓"
  fi

  # Disk space check
  local disk_gb
  disk_gb=$(df -BG / 2>/dev/null | awk 'NR==2 {print $4}' | tr -d 'G' || echo 0)
  if [ "$disk_gb" -lt 5 ]; then
    log_error "Insufficient disk space: ${disk_gb}GB free (minimum: 5GB)"
    exit 1
  elif [ "$disk_gb" -lt 20 ]; then
    log_warn "Low disk space: ${disk_gb}GB free — recommended minimum 20GB"
  else
    log_info "Disk space: ${disk_gb}GB free ✓"
  fi

  # Essential tools
  for tool in curl git; do
    if command -v "$tool" &>/dev/null; then
      log_info "$tool: $(command -v "$tool") ✓"
    else
      log_warn "$tool not found — installing..."
      sudo apt-get update -qq && sudo apt-get install -y -qq "$tool" || \
        sudo yum install -y "$tool" || true
    fi
  done
}

# ---------------------------------------------------------------------------
# Install Docker
# ---------------------------------------------------------------------------
install_docker() {
  if $SKIP_DOCKER; then
    log_info "Skipping Docker installation (--skip-docker)"
    return 0
  fi

  log_step "Checking Docker installation"

  if command -v docker &>/dev/null; then
    local version
    version=$(docker --version 2>/dev/null)
    log_info "Docker already installed: $version"

    # Check Docker Compose v2
    if docker compose version &>/dev/null; then
      log_info "Docker Compose v2: $(docker compose version --short)"
    elif command -v docker-compose &>/dev/null; then
      log_warn "Docker Compose v1 detected — upgrading to v2 recommended"
      log_warn "Run: sudo apt-get install docker-compose-plugin"
    else
      log_error "Docker Compose not found"
      log_error "Install v2: sudo apt-get install docker-compose-plugin"
      exit 1
    fi
    return 0
  fi

  log_step "Installing Docker"
  local os
  os=$(detect_os)

  case "$os" in
    ubuntu|debian)
      log_info "Detected: $os"
      # Remove old versions
      sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

      # Install dependencies
      sudo apt-get update -qq
      sudo apt-get install -y -qq \
        ca-certificates curl gnupg lsb-release

      # Add Docker GPG key
      sudo mkdir -p /etc/apt/keyrings
      curl_retry -o /tmp/docker_gpg https://download.docker.com/linux/$os/gpg
      sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg < /tmp/docker_gpg 2>/dev/null || true

      # Add repository
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
        https://download.docker.com/linux/$os $(lsb_release -cs) stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

      # Install
      sudo apt-get update -qq
      sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin
      ;;

    centos|rhel|rocky|almalinux)
      log_info "Detected: $os"
      sudo yum install -y yum-utils
      sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
      sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
      sudo systemctl enable --now docker
      ;;

    arch|manjaro)
      log_info "Detected: $os"
      sudo pacman -Sy --noconfirm docker docker-compose
      sudo systemctl enable --now docker
      ;;

    *)
      log_error "Unsupported OS: $os"
      log_error "Install Docker manually: https://docs.docker.com/engine/install/"
      exit 1
      ;;
  esac

  # Add user to docker group
  if [ "$(id -u)" -ne 0 ]; then
    sudo usermod -aG docker "$USER"
    log_warn "Added $USER to docker group. Log out and back in for this to take effect."
  fi

  log_info "Docker installed: $(docker --version)"
}

# ---------------------------------------------------------------------------
# Check port conflicts
# ---------------------------------------------------------------------------
check_ports() {
  log_step "Checking port availability"

  local ports=(53 80 443 3000 3001 3100 3200 5432 6379 8080 9000 9090 9093 9443)
  local conflicts=0

  for port in "${ports[@]}"; do
    if ss -tlnp 2>/dev/null | grep -q ":${port} "; then
      listener=$(ss -tlnp 2>/dev/null | grep ":${port} " | awk '{print $NF}' | head -1)
      log_warn "Port $port in use by $listener"
      conflicts=$((conflicts + 1))
    fi
  done

  if [ "$conflicts" -gt 0 ]; then
    log_warn "$conflicts port conflicts detected — some services may fail to start"
    log_warn "Stop conflicting services or adjust ports in docker-compose files"
  else
    log_info "All required ports available ✓"
  fi
}

# ---------------------------------------------------------------------------
# Check firewall
# ---------------------------------------------------------------------------
check_firewall() {
  log_step "Checking firewall"

  if command -v ufw &>/dev/null && sudo ufw status 2>/dev/null | grep -q "active"; then
    log_warn "UFW firewall is active — ensure ports 80, 443 are open:"
    log_warn "  sudo ufw allow 80/tcp && sudo ufw allow 443/tcp"
  elif command -v firewall-cmd &>/dev/null && sudo firewall-cmd --state 2>/dev/null | grep -q "running"; then
    log_warn "firewalld is active — ensure ports 80, 443 are open:"
    log_warn "  sudo firewall-cmd --add-port=80/tcp --permanent && sudo firewall-cmd --add-port=443/tcp --permanent"
  else
    log_info "No active firewall detected ✓"
  fi
}

# ---------------------------------------------------------------------------
# Setup environment
# ---------------------------------------------------------------------------
setup_environment() {
  log_step "Setting up environment"

  cd "$ROOT_DIR"

  if [ ! -f .env ]; then
    if [ -f .env.example ]; then
      cp .env.example .env
      log_info "Created .env from .env.example"
      log_warn "IMPORTANT: Edit .env with your settings before starting services!"
      log_warn "  nano .env"
    else
      log_error ".env.example not found"
      exit 1
    fi
  else
    log_info ".env already exists ✓"
  fi

  # Check required vars
  local required_vars="DOMAIN TZ"
  for var in $required_vars; do
    val=$(grep "^${var}=" .env 2>/dev/null | cut -d= -f2- || true)
    if [ -z "$val" ] || [ "$val" = "yourdomain.com" ]; then
      log_warn "$var is not configured in .env"
    fi
  done
}

# ---------------------------------------------------------------------------
# CN mirror setup
# ---------------------------------------------------------------------------
setup_cn() {
  if $CN_MODE; then
    log_step "Configuring CN mirrors"
    if [ -f "${SCRIPT_DIR}/setup-cn-mirrors.sh" ]; then
      sudo bash "${SCRIPT_DIR}/setup-cn-mirrors.sh" --auto || true
    fi
    if [ -f "${SCRIPT_DIR}/localize-images.sh" ]; then
      bash "${SCRIPT_DIR}/localize-images.sh" --cn || true
    fi
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  echo "========================================"
  echo "  HomeLab Stack — Installation"
  echo "========================================"
  echo

  check_prerequisites
  install_docker
  check_ports
  check_firewall
  setup_environment
  setup_cn

  log_step "Installation Complete!"
  echo
  log_info "Next steps:"
  log_info "  1. Edit .env with your domain and passwords"
  log_info "  2. Start base stack:   docker compose -f stacks/base/docker-compose.yml up -d"
  log_info "  3. Start SSO stack:    docker compose -f stacks/sso/docker-compose.yml up -d"
  log_info "  4. Start monitoring:   docker compose -f stacks/monitoring/docker-compose.yml up -d"
  log_info "  5. Setup Authentik:    ./scripts/setup-authentik.sh"
  echo
  log_info "For CN users: add --cn flag or run ./scripts/setup-cn-mirrors.sh"
  log_info "Diagnostics:  ./scripts/diagnose.sh"
}

main "$@"
