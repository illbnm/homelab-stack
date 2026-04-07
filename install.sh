#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Robust Installer with CN Network Support
# =============================================================================
set -euo pipefail
IFS=$'\n\t'

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()  { echo -e "\n${BLUE}${BOLD}==> $*${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
LOG_FILE="$HOME/.homelab/install.log"

mkdir -p "$(dirname "$LOG_FILE")"

# Logging function
exec > >(tee -a "$LOG_FILE") 2>&1

cleanup() {
  if [[ $? -ne 0 ]]; then
    log_error "Installation failed. Check logs at $LOG_FILE"
    log_error "Run './scripts/diagnose.sh' to collect diagnostic information"
  fi
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Robust curl with retry logic
# ---------------------------------------------------------------------------
curl_retry() {
  local max_attempts=3
  local delay=5
  local attempt=1

  while [[ $attempt -le $max_attempts ]]; do
    if curl --connect-timeout 10 --max-time 60 "$@"; then
      return 0
    fi

    if [[ $attempt -lt $max_attempts ]]; then
      log_warn "Attempt $attempt failed, retrying in ${delay}s..."
      sleep $delay
      delay=$((delay * 2))  # Exponential backoff
    fi
    ((attempt++))
  done

  return 1
}

# ---------------------------------------------------------------------------
# Check if running as root
# ---------------------------------------------------------------------------
check_root() {
  if [[ $EUID -eq 0 ]]; then
    log_warn "Running as root is not recommended"
    log_info "This script can be run as a regular user"
  fi
}

# ---------------------------------------------------------------------------
# Add user to docker group if needed
# ---------------------------------------------------------------------------
ensure_docker_group() {
  if ! groups | grep -q docker; then
    log_step "Adding user to docker group"
    if command -v sudo &>/dev/null; then
      sudo usermod -aG docker "$USER"
      log_warn "You've been added to the docker group"
      log_warn "Please log out and back in for changes to take effect"
      log_warn "Then re-run this script"
      exit 0
    fi
  fi
}

# ---------------------------------------------------------------------------
# Install Docker if not present
# ---------------------------------------------------------------------------
install_docker() {
  if command -v docker &>/dev/null; then
    log_info "Docker is already installed"
    return 0
  fi

  log_step "Installing Docker"

  # Detect OS
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
  else
    log_error "Cannot detect OS"
    exit 1
  fi

  case "$ID" in
    ubuntu|debian)
      log_info "Detected Debian/Ubuntu"
      # Install dependencies
      sudo apt-get update
      sudo apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release

      # Add Docker's official GPG key
      curl_retry -fsSL https://download.docker.com/linux/$ID/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

      # Set up stable repository
      echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/$ID \
        $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

      # Install Docker
      sudo apt-get update
      sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
      ;;

    centos|rhel|rocky|almalinux)
      log_info "Detected RHEL/CentOS"
      sudo yum install -y yum-utils
      sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
      sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
      sudo systemctl start docker
      sudo systemctl enable docker
      ;;

    arch|manjaro)
      log_info "Detected Arch Linux"
      sudo pacman -Sy --noconfirm docker docker-compose
      sudo systemctl start docker
      sudo systemctl enable docker
      ;;

    *)
      log_error "Unsupported OS: $ID"
      log_error "Please install Docker manually: https://docs.docker.com/get-docker/"
      exit 1
      ;;
  esac

  log_info "Docker installation complete"
}

# ---------------------------------------------------------------------------
# Check Docker Compose version
# ---------------------------------------------------------------------------
check_docker_compose() {
  if docker compose version &>/dev/null; then
    local version
    version=$(docker compose version --short)
    log_info "Docker Compose v2 found: $version"
  elif command -v docker-compose &>/dev/null; then
    log_warn "Docker Compose v1 found"
    log_warn "Please upgrade to Docker Compose v2 for better compatibility"
    log_warn "See: https://docs.docker.com/compose/migrate/"
    read -rp "Continue anyway? [y/N]: " yn
    [[ "$yn" =~ ^[Yy]$ ]] || exit 1
  else
    log_error "Docker Compose not found"
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Check system resources
# ---------------------------------------------------------------------------
check_resources() {
  log_step "Checking system resources"

  # Check disk space
  local free_gb
  free_gb=$(df -BG / | awk 'NR==2 {gsub(/G/,"",$4); print $4}')

  if [[ "$free_gb" -lt 5 ]]; then
    log_error "Insufficient disk space: ${free_gb}GB free"
    log_error "Minimum 5GB required, 20GB recommended"
    exit 1
  elif [[ "$free_gb" -lt 20 ]]; then
    log_warn "Low disk space: ${free_gb}GB free (20GB recommended)"
  else
    log_info "Disk space: ${free_gb}GB free"
  fi

  # Check memory
  if command -v free &>/dev/null; then
    local total_mb
    total_mb=$(free -m | awk 'NR==2 {print $2}')

    if [[ "$total_mb" -lt 2048 ]]; then
      log_warn "Low memory: ${total_mb}MB (2GB minimum, 8GB recommended)"
    else
      log_info "Memory: ${total_mb}MB available"
    fi
  fi
}

# ---------------------------------------------------------------------------
# Check port availability
# ---------------------------------------------------------------------------
check_ports() {
  log_step "Checking port availability"

  local required_ports=(80 443)
  local port_issues=0

  for port in "${required_ports[@]}"; do
    if ss -tlnp 2>/dev/null | grep -q ":${port} " || \
       netstat -tlnp 2>/dev/null | grep -q ":${port} "; then
      log_warn "Port $port is already in use"
      log_warn "Traefik will fail to bind to port $port"
      ((port_issues++))
    else
      log_info "Port $port is available"
    fi
  done

  if [[ $port_issues -gt 0 ]]; then
    log_warn "Port conflicts detected. Some services may fail to start."
    read -rp "Continue anyway? [y/N]: " yn
    [[ "$yn" =~ ^[Yy]$ ]] || exit 1
  fi
}

# ---------------------------------------------------------------------------
# Check firewall
# ---------------------------------------------------------------------------
check_firewall() {
  log_step "Checking firewall"

  if command -v ufw &>/dev/null && ufw status | grep -q "Status: active"; then
    log_info "UFW firewall is active"
    log_warn "Ensure ports 80 and 443 are allowed:"
    log_warn "  sudo ufw allow 80/tcp"
    log_warn "  sudo ufw allow 443/tcp"
  elif command -v firewall-cmd &>/dev/null && firewall-cmd --state &>/dev/null; then
    log_info "Firewalld is active"
    log_warn "Ensure ports 80 and 443 are allowed:"
    log_warn "  sudo firewall-cmd --add-port=80/tcp --permanent"
    log_warn "  sudo firewall-cmd --add-port=443/tcp --permanent"
    log_warn "  sudo firewall-cmd --reload"
  else
    log_info "No firewall detected or firewall is inactive"
  fi
}

# ---------------------------------------------------------------------------
# China network detection
# ---------------------------------------------------------------------------
detect_china_network() {
  log_step "Network environment detection"

  # Test connectivity to common China-blocked services
  local blocked=0

  if ! curl -sf --connect-timeout 5 --max-time 10 https://hub.docker.com &>/dev/null; then
    log_warn "Docker Hub is not directly accessible"
    ((blocked++))
  fi

  if ! curl -sf --connect-timeout 5 --max-time 10 https://gcr.io &>/dev/null; then
    log_warn "Google Container Registry (gcr.io) is not directly accessible"
    ((blocked++))
  fi

  if [[ $blocked -gt 0 ]]; then
    log_warn ""
    log_warn "Detected potential China network environment"
    log_warn "Run the following commands for better connectivity:"
    log_warn ""
    log_warn "  sudo ./scripts/setup-cn-mirrors.sh"
    log_warn "  ./scripts/localize-images.sh --cn"
    log_warn ""
    read -rp "Configure China mirrors now? [Y/n]: " yn
    if [[ ! "$yn" =~ ^[Nn]$ ]]; then
      if [[ -f "$SCRIPT_DIR/scripts/setup-cn-mirrors.sh" ]]; then
        sudo bash "$SCRIPT_DIR/scripts/setup-cn-mirrors.sh"
      fi
    fi
  else
    log_info "Network connectivity is good"
  fi
}

# ---------------------------------------------------------------------------
# Create necessary directories and files
# ---------------------------------------------------------------------------
create_directories() {
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

  # Create acme.json with correct permissions
  local acme_file="config/traefik/acme.json"
  if [[ ! -f "$acme_file" ]]; then
    touch "$acme_file"
    chmod 600 "$acme_file"
    log_info "Created $acme_file with permissions 600"
  fi
}

# ---------------------------------------------------------------------------
# Setup environment file
# ---------------------------------------------------------------------------
setup_env() {
  log_step "Environment configuration"

  if [[ ! -f .env ]]; then
    if [[ -f .env.example ]]; then
      cp .env.example .env
      log_info "Created .env from .env.example"
      log_warn "Please edit .env with your configuration"
      log_warn "Then run: ./scripts/setup-env.sh"
    else
      log_error ".env.example not found"
      exit 1
    fi
  else
    log_info ".env already exists, skipping"
    log_warn "To reconfigure, remove .env and run this script again"
  fi
}

# ---------------------------------------------------------------------------
# Create proxy network
# ---------------------------------------------------------------------------
create_proxy_network() {
  log_step "Creating Docker networks"

  if ! docker network inspect proxy &>/dev/null; then
    docker network create proxy
    log_info "Created 'proxy' network"
  else
    log_info "'proxy' network already exists"
  fi
}

# ---------------------------------------------------------------------------
# Main installation flow
# ---------------------------------------------------------------------------
main() {
  echo -e ""
  echo -e "${BOLD}  ██╗  ██╗ ██████╗ ███╗   ███╗███████╗██╗      █████╗ ██████╗ ${NC}"
  echo -e "${BOLD}  ██║  ██║██╔═══██╗████╗ ████║██╔════╝██║     ██╔══██╗██╔══██╗${NC}"
  echo -e "${BOLD}  ███████║██║   ██║██╔████╔██║█████╗  ██║     ███████║██████╔╝${NC}"
  echo -e "${BOLD}  ██╔══██║██║   ██║██║╚██╔╝██║██╔══╝  ██║     ██╔══██║██╔══██╗${NC}"
  echo -e "${BOLD}  ██║  ██║╚██████╔╝██║ ╚═╝ ██║███████╗███████╗██║  ██║██████╔╝${NC}"
  echo -e "${BOLD}  ╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝╚═════╝ ${NC}"
  echo -e "${BOLD}                    S T A C K   v1.0.0${NC}"
  echo -e "${BOLD}            Robust Installer with CN Support${NC}"
  echo -e ""

  # Pre-flight checks
  check_root
  check_resources
  check_ports
  check_firewall

  # Install dependencies
  install_docker
  check_docker_compose
  ensure_docker_group

  # Network setup
  detect_china_network

  # Project setup
  create_directories
  setup_env
  create_proxy_network

  # Success message
  log_info ""
  log_info "${GREEN}${BOLD}✓ Installation complete!${NC}"
  log_info ""
  log_info "Next steps:"
  log_info ""
  log_info "  1. Edit .env with your configuration"
  log_info "     nano .env"
  log_info ""
  log_info "  2. (Optional) Run setup script for guided configuration"
  log_info "     ./scripts/setup-env.sh"
  log_info ""
  log_info "  3. Launch base infrastructure"
  log_info "     docker compose -f docker-compose.base.yml up -d"
  log_info ""
  log_info "  4. Deploy stacks"
  log_info "     ./scripts/stack-manager.sh start sso"
  log_info "     ./scripts/stack-manager.sh start monitoring"
  log_info ""
  log_info "  5. Check stack health"
  log_info "     ./scripts/wait-healthy.sh --stack base --timeout 300"
  log_info ""
  log_info "Documentation: docs/getting-started.md"
  log_info "Troubleshooting: ./scripts/diagnose.sh"
  log_info ""
}

main "$@"
