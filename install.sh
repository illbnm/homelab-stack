#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Installer
# =============================================================================
set -euo pipefail
IFS=$'\n\t'

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Version
VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"

# Logging
LOG_FILE="$HOME/.homelab/install.log"
mkdir -p "$(dirname "$LOG_FILE")"

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; echo "[INFO] $*" >> "$LOG_FILE"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; echo "[WARN] $*" >> "$LOG_FILE"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; echo "[ERROR] $*" >> "$LOG_FILE"; }
log_step()  { echo -e "\n${BLUE}${BOLD}==> $*${NC}"; echo "==> $*" >> "$LOG_FILE"; }

# Cleanup on error
cleanup() {
  local rc=$?
  if [[ $rc -ne 0 ]]; then
    log_error "Installation failed (exit code: $rc)"
    log_error "Check logs at: $LOG_FILE"
  fi
}
trap cleanup EXIT

# =============================================================================
# Retry function for network requests
# =============================================================================
curl_retry() {
  local max_attempts=3
  local delay=5
  local attempt=1
  
  while [[ $attempt -le $max_attempts ]]; do
    log_info "Attempt $attempt/$max_attempts: $*"
    if curl --connect-timeout 10 --max-time 60 -fSL "$@"; then
      return 0
    fi
    
    log_warn "Attempt $attempt failed"
    if [[ $attempt -lt $max_attempts ]]; then
      log_info "Retrying in ${delay}s..."
      sleep "$delay"
      delay=$((delay * 2))  # Exponential backoff
    fi
    ((attempt++))
  done
  
  log_error "Failed after $max_attempts attempts: $*"
  return 1
}

# =============================================================================
# Detect OS
# =============================================================================
detect_os() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    echo "$ID"
  elif [[ -f /etc/debian_version ]]; then
    echo "debian"
  elif [[ -f /etc/redhat-release ]]; then
    echo "centos"
  else
    uname -s | tr '[:upper:]' '[:lower:]'
  fi
}

# =============================================================================
# Check and install Docker
# =============================================================================
check_docker() {
  if command -v docker &>/dev/null; then
    local ver
    ver=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "unknown")
    log_info "Docker found: $ver"
    
    # Check daemon
    if docker info &>/dev/null; then
      log_info "Docker daemon is running"
      return 0
    else
      log_error "Docker daemon is not running"
      log_info "Try: sudo systemctl start docker"
      return 1
    fi
  fi
  
  return 1
}

install_docker_ubuntu() {
  log_info "Installing Docker on Ubuntu/Debian..."
  
  # Update package index
  apt-get update -qq
  
  # Install dependencies
  apt-get install -y -qq \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
  
  # Add Docker's official GPG key
  local keyrings_dir="/usr/share/keyrings"
  mkdir -p "$keyrings_dir"
  
  if [[ ! -f "$keyrings_dir/docker.gpg" ]]; then
    curl_retry https://download.docker.com/linux/ubuntu/gpg | \
      gpg --dearmor -o "$keyrings_dir/docker.gpg"
  fi
  
  # Set up repository
  local repo
  repo="deb [arch=$(dpkg --print-architecture) signed-by=$keyrings_dir/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
  echo "$repo" > /etc/apt/sources.list.d/docker.list
  
  # Install Docker
  apt-get update -qq
  apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin
  
  log_info "Docker installed successfully"
}

install_docker_centos() {
  log_info "Installing Docker on CentOS/RHEL..."
  
  # Install dependencies
  yum install -y -q yum-utils
  
  # Add Docker repository
  yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
  
  # Install Docker
  yum install -y -q docker-ce docker-ce-cli containerd.io docker-compose-plugin
  
  # Start Docker
  systemctl start docker
  systemctl enable docker
  
  log_info "Docker installed successfully"
}

install_docker_arch() {
  log_info "Installing Docker on Arch Linux..."
  
  pacman -Sy --noconfirm docker docker-compose
  
  systemctl start docker
  systemctl enable docker
  
  log_info "Docker installed successfully"
}

install_docker() {
  local os
  os=$(detect_os)
  
  log_step "Installing Docker..."
  
  case "$os" in
    ubuntu|debian|raspbian)
      install_docker_ubuntu
      ;;
    centos|rhel|fedora|rocky|almalinux)
      install_docker_centos
      ;;
    arch|manjaro)
      install_docker_arch
      ;;
    *)
      log_error "Unsupported OS: $os"
      log_info "Please install Docker manually: https://docs.docker.com/get-docker/"
      return 1
      ;;
  esac
}

# =============================================================================
# Check Docker Compose version
# =============================================================================
check_docker_compose() {
  if docker compose version &>/dev/null; then
    local ver
    ver=$(docker compose version --short 2>/dev/null || echo "unknown")
    log_info "Docker Compose v2: $ver"
    return 0
  elif command -v docker-compose &>/dev/null; then
    log_warn "Found docker-compose v1 (standalone)"
    log_warn "Please upgrade to Docker Compose v2:"
    log_warn "  https://docs.docker.com/compose/migrate/"
    return 1
  else
    log_error "Docker Compose not found"
    return 1
  fi
}

# =============================================================================
# Check system requirements
# =============================================================================
check_disk_space() {
  local path="${1:-/}"
  local available
  available=$(df -BG "$path" | awk 'NR==2 {gsub(/G/,"",$4); print $4}')
  
  echo "$available"
}

check_memory() {
  local total_mb
  total_mb=$(free -m | awk '/^Mem:/ {print $2}')
  echo "$total_mb"
}

check_system_requirements() {
  log_step "Checking system requirements..."
  
  local warnings=0
  local errors=0
  
  # Disk space check
  local disk_free
  disk_free=$(check_disk_space "/")
  
  if [[ $disk_free -lt 5 ]]; then
    log_error "Insufficient disk space: ${disk_free}GB (minimum 5GB required)"
    ((errors++))
  elif [[ $disk_free -lt 20 ]]; then
    log_warn "Low disk space: ${disk_free}GB (recommend >= 20GB)"
    ((warnings++))
  else
    log_info "Disk space: ${disk_free}GB free"
  fi
  
  # Memory check
  local total_mem
  total_mem=$(check_memory)
  
  if [[ $total_mem -lt 1024 ]]; then
    log_error "Insufficient memory: ${total_mem}MB (minimum 1GB required)"
    ((errors++))
  elif [[ $total_mem -lt 2048 ]]; then
    log_warn "Low memory: ${total_mem}MB (recommend >= 2GB)"
    ((warnings++))
  else
    log_info "Memory: ${total_mem}MB"
  fi
  
  # Architecture check
  local arch
  arch=$(uname -m)
  if [[ "$arch" == "x86_64" || "$arch" == "aarch64" ]]; then
    log_info "Architecture: $arch"
  else
    log_warn "Architecture $arch may have limited image support"
    ((warnings++))
  fi
  
  if [[ $errors -gt 0 ]]; then
    return 1
  fi
  
  return 0
}

# =============================================================================
# Check port availability
# =============================================================================
check_ports() {
  log_step "Checking port availability..."
  
  local ports=(53 80 443 3000 8080 8443 9000)
  local conflicts=0
  
  for port in "${ports[@]}"; do
    if ss -tlnp 2>/dev/null | grep -q ":${port} " || \
       netstat -tlnp 2>/dev/null | grep -q ":${port} "; then
      local process
      process=$(ss -tlnp 2>/dev/null | grep ":${port} " | awk '{print $7}' | cut -d'"' -f2 || echo "unknown")
      log_warn "Port $port is in use by: $process"
      ((conflicts++))
    else
      log_info "Port $port is available"
    fi
  done
  
  if [[ $conflicts -gt 0 ]]; then
    log_warn "$conflicts port conflict(s) detected"
    log_warn "Some services may fail to start"
    return 1
  fi
  
  return 0
}

# =============================================================================
# Check firewall
# =============================================================================
check_firewall() {
  log_step "Checking firewall..."
  
  # Check UFW
  if command -v ufw &>/dev/null; then
    local ufw_status
    ufw_status=$(ufw status 2>/dev/null | head -1 || echo "inactive")
    
    if [[ "$ufw_status" == *"active"* ]]; then
      log_warn "UFW firewall is active"
      log_info "Required ports: 80, 443"
      log_info "Allow with: sudo ufw allow 80/tcp && sudo ufw allow 443/tcp"
    else
      log_info "UFW: $ufw_status"
    fi
  fi
  
  # Check firewalld
  if command -v firewall-cmd &>/dev/null; then
    if systemctl is-active firewalld &>/dev/null; then
      log_warn "firewalld is active"
      log_info "Required ports: 80, 443"
      log_info "Allow with: sudo firewall-cmd --add-port={80,443}/tcp --permanent"
    fi
  fi
  
  # Check iptables
  if command -v iptables &>/dev/null; then
    if iptables -L -n 2>/dev/null | grep -q "DROP"; then
      log_warn "iptables rules detected - check if ports 80/443 are allowed"
    fi
  fi
  
  return 0
}

# =============================================================================
# Add user to docker group
# =============================================================================
ensure_docker_group() {
  local user="${SUDO_USER:-$USER}"
  
  if groups "$user" 2>/dev/null | grep -q docker; then
    log_info "User '$user' is in docker group"
    return 0
  fi
  
  log_info "Adding user '$user' to docker group..."
  usermod -aG docker "$user"
  
  log_warn "You may need to log out and back in for group changes to take effect"
  log_warn "Or run: newgrp docker"
}

# =============================================================================
# CN Network check
# =============================================================================
check_cn_network() {
  log_step "Checking network environment..."
  
  # Run connectivity check
  if [[ -f "$SCRIPT_DIR/scripts/check-connectivity.sh" ]]; then
    bash "$SCRIPT_DIR/scripts/check-connectivity.sh"
    local rc=$?
    
    if [[ $rc -ne 0 ]]; then
      log_warn "Network connectivity issues detected"
      
      # Prompt for CN setup
      read -r -p "Configure CN mirrors for better connectivity? [Y/n] " response
      response="${response:-Y}"
      
      if [[ "$response" =~ ^[Yy] ]]; then
        if [[ -f "$SCRIPT_DIR/scripts/setup-cn-mirrors.sh" ]]; then
          log_info "Running CN mirror setup..."
          bash "$SCRIPT_DIR/scripts/setup-cn-mirrors.sh" -y || true
        fi
        
        if [[ -f "$SCRIPT_DIR/scripts/localize-images.sh" ]]; then
          log_info "Localizing images..."
          bash "$SCRIPT_DIR/scripts/localize-images.sh" --cn || true
        fi
      fi
    fi
  fi
}

# =============================================================================
# Create data directories
# =============================================================================
create_directories() {
  log_step "Creating data directories..."
  
  mkdir -p \
    data/traefik/certs \
    data/portainer \
    data/prometheus \
    data/grafana \
    data/loki \
    data/authentik/media \
    data/nextcloud \
    data/gitea \
    data/vaultwarden \
    config/traefik
  
  # Create acme.json with correct permissions
  local acme_file="config/traefik/acme.json"
  if [[ ! -f "$acme_file" ]]; then
    touch "$acme_file"
    chmod 600 "$acme_file"
    log_info "Created $acme_file with permissions 600"
  else
    chmod 600 "$acme_file"
    log_info "Set $acme_file permissions to 600"
  fi
  
  log_info "Directories created"
}

# =============================================================================
# Launch base stack
# =============================================================================
launch_base() {
  log_step "Launching base infrastructure..."
  
  local compose_file="docker-compose.base.yml"
  
  if [[ ! -f "$compose_file" ]]; then
    compose_file="stacks/base/docker-compose.yml"
  fi
  
  if [[ ! -f "$compose_file" ]]; then
    log_error "Base compose file not found"
    return 1
  fi
  
  docker compose -f "$compose_file" up -d
  
  # Wait for healthy
  if [[ -f "$SCRIPT_DIR/scripts/wait-healthy.sh" ]]; then
    bash "$SCRIPT_DIR/scripts/wait-healthy.sh" --stack base --timeout 120 || true
  fi
}

# =============================================================================
# Banner
# =============================================================================
show_banner() {
  echo -e ""
  echo -e "${BOLD}  ██╗  ██╗ ██████╗ ███╗   ███╗███████╗██╗      █████╗ ██████╗ ${NC}"
  echo -e "${BOLD}  ██║  ██║██╔═══██╗████╗ ████║██╔════╝██║     ██╔══██╗██╔══██╗${NC}"
  echo -e "${BOLD}  ███████║██║   ██║██╔████╔██║█████╗  ██║     ███████║██████╔╝${NC}"
  echo -e "${BOLD}  ██╔══██║██║   ██║██║╚██╔╝██║██╔══╝  ██║     ██╔══██║██╔══██╗${NC}"
  echo -e "${BOLD}  ██║  ██║╚██████╔╝██║ ╚═╝ ██║███████╗███████╗██║  ██║██████╔╝${NC}"
  echo -e "${BOLD}  ╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝╚═════╝ ${NC}"
  echo -e "${BOLD}                    S T A C K   v${VERSION}${NC}"
  echo -e ""
}

# =============================================================================
# Usage
# =============================================================================
usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --skip-docker     Skip Docker installation if not found
  --skip-network    Skip network connectivity checks
  --cn              Force CN mirror configuration
  -y, --yes         Auto-confirm all prompts
  -h, --help        Show this help

Examples:
  $0                  # Interactive installation
  $0 -y               # Auto-confirm
  $0 --cn             # Configure CN mirrors

EOF
  exit 0
}

# =============================================================================
# Main
# =============================================================================
main() {
  local skip_docker=false
  local skip_network=false
  local force_cn=false
  local auto_confirm=false
  
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      --skip-docker) skip_docker=true ;;
      --skip-network) skip_network=true ;;
      --cn) force_cn=true ;;
      -y|--yes) auto_confirm=true ;;
      -h|--help) usage ;;
      *) log_error "Unknown option: $1"; usage ;;
    esac
    shift
  done
  
  # Check root
  if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root"
    log_info "Try: sudo $0"
    exit 1
  fi
  
  show_banner
  
  # Step 1: System requirements
  check_system_requirements || {
    log_error "System requirements not met"
    exit 1
  }
  
  # Step 2: Install Docker if needed
  if ! check_docker; then
    if $skip_docker; then
      log_error "Docker not found and --skip-docker specified"
      exit 1
    fi
    
    if $auto_confirm; then
      install_docker
    else
      read -r -p "Docker not found. Install now? [Y/n] " response
      response="${response:-Y}"
      [[ "$response" =~ ^[Yy] ]] && install_docker || exit 1
    fi
  fi
  
  # Step 3: Check Docker Compose
  check_docker_compose || {
    log_error "Docker Compose v2 is required"
    exit 1
  }
  
  # Step 4: Ensure user in docker group
  ensure_docker_group
  
  # Step 5: Check ports
  check_ports || true  # Don't fail, just warn
  
  # Step 6: Check firewall
  check_firewall
  
  # Step 7: Network check (unless skipped)
  if ! $skip_network; then
    if $force_cn; then
      check_cn_network
    else
      bash "$SCRIPT_DIR/scripts/check-connectivity.sh" || true
    fi
  fi
  
  # Step 8: Setup environment
  log_step "Environment configuration"
  if [[ ! -f .env ]]; then
    if [[ -f "$SCRIPT_DIR/scripts/setup-env.sh" ]]; then
      bash "$SCRIPT_DIR/scripts/setup-env.sh"
    else
      log_warn "setup-env.sh not found, creating minimal .env"
      cp .env.example .env 2>/dev/null || echo "# HomeLab Stack Environment" > .env
    fi
  else
    log_warn ".env already exists, skipping setup"
  fi
  
  # Step 9: Create directories
  create_directories
  
  # Step 10: Launch base
  launch_base
  
  # Success!
  echo ""
  log_info "${GREEN}${BOLD}✓ Installation complete!${NC}"
  echo ""
  echo "Next steps:"
  echo "  ./scripts/stack-manager.sh start sso        # Set up SSO first"
  echo "  ./scripts/stack-manager.sh start monitoring # Launch monitoring"
  echo "  ./scripts/stack-manager.sh list             # See all stacks"
  echo ""
  echo "Documentation: docs/getting-started.md"
  echo "Diagnostics:   ./scripts/diagnose.sh --full"
}

main "$@"
