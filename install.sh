#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Robust Installer
# Handles: Docker auto-install, CN network adaptation, port conflicts,
#           disk/memory checks, firewall detection, and graceful retries.
# =============================================================================
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$HOME/.homelab"
LOG_FILE="$LOG_DIR/install.log"
mkdir -p "$LOG_DIR"

# ---------------------------------------------------------------------------
# Colors & logging
# ---------------------------------------------------------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"  | tee -a "$LOG_FILE"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"  | tee -a "$LOG_FILE"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"    | tee -a "$LOG_FILE" >&2; }
log_step()  { echo -e "\n${BLUE}${BOLD}==> $*${NC}" | tee -a "$LOG_FILE"; }

# ---------------------------------------------------------------------------
# Cleanup trap
# ---------------------------------------------------------------------------
cleanup() {
  local exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    log_error "Installation failed (exit $exit_code). Full log: $LOG_FILE"
    log_error "Run ./scripts/diagnose.sh for troubleshooting."
  fi
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Retry wrapper — exponential backoff
# Usage: curl_retry <url> [curl-args...]
# ---------------------------------------------------------------------------
curl_retry() {
  local url="$1"; shift
  local max_attempts=3
  local attempt=1
  local wait_sec=2

  while [[ $attempt -le $max_attempts ]]; do
    if curl --connect-timeout 10 --max-time 30 -fsSL "$url" "$@"; then
      return 0
    fi
    log_warn "Attempt $attempt/$max_attempts failed for $url — retrying in ${wait_sec}s..."
    sleep "$wait_sec"
    ((attempt++))
    wait_sec=$((wait_sec * 2))
  done

  log_error "All $max_attempts attempts failed for $url"
  return 1
}

# ---------------------------------------------------------------------------
# Prompt helper (with timeout for non-interactive)
# ---------------------------------------------------------------------------
ask_yes_no() {
  local prompt="$1"
  local default="${2:-y}"
  if [[ ! -t 0 ]]; then
    # Non-interactive — use default
    [[ "$default" == "y" ]]
    return $?
  fi
  local reply
  read -r -p "$prompt [y/n] ($default): " reply
  reply="${reply:-$default}"
  [[ "$reply" =~ ^[Yy] ]]
}

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
echo "Install log: $LOG_FILE"
echo ""

# ===================================================================
# Pre-flight checks
# ===================================================================

# ---------------------------------------------------------------------------
# Step 1: System requirements — disk space & memory
# ---------------------------------------------------------------------------
log_step "Checking system requirements"

# Disk check (cross-platform: Linux uses -BG, macOS uses -g)
check_disk_space() {
  local free_gb
  if df -BG / &>/dev/null; then
    free_gb=$(df -BG / | awk 'NR==2 {gsub(/G/,"",$4); print $4}')
  else
    # macOS: df -g shows GB
    free_gb=$(df -g / | awk 'NR==2 {print $4}')
  fi

  if [[ "$free_gb" -lt 5 ]]; then
    log_error "Only ${free_gb}GB disk space free — minimum 5GB required!"
    log_error "Free up space before installing."
    exit 1
  elif [[ "$free_gb" -lt 20 ]]; then
    log_warn "Only ${free_gb}GB disk space free — recommend >= 20GB for all stacks."
  else
    log_info "Disk space: ${free_gb}GB free ✓"
  fi
}

# Memory check (cross-platform)
check_memory() {
  local mem_gb
  if [[ -f /proc/meminfo ]]; then
    local mem_kb
    mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    mem_gb=$((mem_kb / 1024 / 1024))
  elif command -v sysctl &>/dev/null; then
    # macOS
    local mem_bytes
    mem_bytes=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
    mem_gb=$((mem_bytes / 1024 / 1024 / 1024))
  else
    log_warn "Cannot detect system memory — skipping check."
    return
  fi

  if [[ "$mem_gb" -lt 2 ]]; then
    log_warn "System has only ${mem_gb}GB RAM — minimum 2GB recommended."
    log_warn "Some services may fail to start or run slowly."
  elif [[ "$mem_gb" -lt 4 ]]; then
    log_warn "System has ${mem_gb}GB RAM — 4GB+ recommended for full stack."
  else
    log_info "Memory: ${mem_gb}GB RAM ✓"
  fi
}

check_disk_space
check_memory

# ---------------------------------------------------------------------------
# Step 2: Docker installation/detection
# ---------------------------------------------------------------------------
log_step "Checking Docker installation"

install_docker() {
  log_info "Installing Docker via get.docker.com..."

  if curl_retry "https://get.docker.com" -o /tmp/get-docker.sh; then
    sudo sh /tmp/get-docker.sh
    rm -f /tmp/get-docker.sh
  else
    log_error "Failed to download Docker install script."
    log_error "Install manually: https://docs.docker.com/get-docker/"
    exit 1
  fi

  # Start Docker service
  if command -v systemctl &>/dev/null; then
    sudo systemctl enable docker
    sudo systemctl start docker
    log_info "Docker service started and enabled."
  fi

  # Add current user to docker group (non-root)
  if [[ "$(id -u)" -ne 0 ]] && ! groups | grep -qw docker; then
    sudo usermod -aG docker "$USER"
    log_warn "Added $USER to 'docker' group. You may need to log out and back in."
    log_warn "Or run: newgrp docker"
  fi
}

if ! command -v docker &>/dev/null; then
  log_warn "Docker is not installed."
  if ask_yes_no "Install Docker automatically?" "y"; then
    install_docker
  else
    log_error "Docker is required. Install it manually and re-run this script."
    exit 1
  fi
else
  # Check Docker daemon is running
  if ! docker info &>/dev/null; then
    log_warn "Docker is installed but the daemon is not running."
    if command -v systemctl &>/dev/null; then
      log_info "Attempting to start Docker..."
      sudo systemctl start docker
      sleep 2
      if docker info &>/dev/null; then
        log_info "Docker daemon started ✓"
      else
        log_error "Failed to start Docker daemon. Check: sudo systemctl status docker"
        exit 1
      fi
    else
      log_error "Please start Docker manually and re-run this script."
      exit 1
    fi
  fi

  # Version check
  local_docker_ver=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo '0.0.0')
  local_docker_major=$(echo "$local_docker_ver" | cut -d. -f1)
  if [[ "$local_docker_major" -ge 24 ]]; then
    log_info "Docker $local_docker_ver ✓"
  else
    log_warn "Docker $local_docker_ver detected — version >= 24.0 recommended."
    log_warn "Upgrade: https://docs.docker.com/engine/install/"
  fi
fi

# Docker Compose v2 check / upgrade hint
log_step "Checking Docker Compose"

if docker compose version &>/dev/null; then
  compose_ver=$(docker compose version --short 2>/dev/null || echo 'unknown')
  log_info "Docker Compose v2: $compose_ver ✓"
elif command -v docker-compose &>/dev/null; then
  log_warn "docker-compose v1 detected — this project requires Docker Compose v2 (plugin)."
  log_warn "Migrate guide: https://docs.docker.com/compose/migrate/"
  log_error "Please upgrade to Docker Compose v2 before continuing."
  exit 1
else
  log_error "Docker Compose not found. Install the docker-compose-plugin package."
  log_error "  Ubuntu/Debian: sudo apt install docker-compose-plugin"
  log_error "  CentOS/RHEL:   sudo yum install docker-compose-plugin"
  exit 1
fi

# Non-root docker group check
if [[ "$(id -u)" -ne 0 ]] && ! docker ps &>/dev/null; then
  log_warn "Current user cannot run Docker commands without sudo."
  if ask_yes_no "Add $USER to docker group?" "y"; then
    sudo usermod -aG docker "$USER"
    log_warn "Added $USER to 'docker' group. Please log out/in or run: newgrp docker"
  fi
fi

# ---------------------------------------------------------------------------
# Step 3: Port conflict detection
# ---------------------------------------------------------------------------
log_step "Checking for port conflicts"

CRITICAL_PORTS=(80 443)
OPTIONAL_PORTS=(53 3000 8080 8443 9090 9000)
PORT_CONFLICTS=0

check_port() {
  local port="$1"
  local severity="$2"  # critical or optional
  local in_use=false

  # Try ss first, then netstat, then lsof
  if command -v ss &>/dev/null; then
    ss -tlnp 2>/dev/null | grep -q ":${port} " && in_use=true
  elif command -v netstat &>/dev/null; then
    netstat -tlnp 2>/dev/null | grep -q ":${port} " && in_use=true
  elif command -v lsof &>/dev/null; then
    lsof -i ":${port}" -sTCP:LISTEN &>/dev/null && in_use=true
  fi

  if $in_use; then
    if [[ "$severity" == "critical" ]]; then
      log_error "Port $port is in use — Traefik requires this port!"
      # Try to identify what's using it
      if command -v lsof &>/dev/null; then
        local proc
        proc=$(lsof -i ":${port}" -sTCP:LISTEN -t 2>/dev/null | head -1)
        [[ -n "$proc" ]] && log_error "  PID $proc: $(ps -p "$proc" -o comm= 2>/dev/null || echo 'unknown')"
      fi
      ((PORT_CONFLICTS++))
    else
      log_warn "Port $port is already in use — some services may conflict."
    fi
  else
    log_info "Port $port available ✓"
  fi
}

for port in "${CRITICAL_PORTS[@]}"; do
  check_port "$port" "critical"
done
for port in "${OPTIONAL_PORTS[@]}"; do
  check_port "$port" "optional"
done

if [[ "$PORT_CONFLICTS" -gt 0 ]]; then
  log_error "Critical ports are in use. Free them before proceeding."
  log_error "Common fix: sudo systemctl stop nginx apache2 caddy"
  if ! ask_yes_no "Continue anyway (services may fail)?" "n"; then
    exit 1
  fi
fi

# ---------------------------------------------------------------------------
# Step 4: Firewall detection
# ---------------------------------------------------------------------------
log_step "Checking firewall configuration"

check_firewall() {
  local fw_found=false

  # UFW (Ubuntu/Debian)
  if command -v ufw &>/dev/null; then
    fw_found=true
    local ufw_status
    ufw_status=$(sudo ufw status 2>/dev/null | head -1 || echo "unknown")
    if echo "$ufw_status" | grep -qi "active"; then
      log_warn "UFW firewall is active."
      log_warn "Ensure ports 80, 443 are allowed: sudo ufw allow 80/tcp && sudo ufw allow 443/tcp"
      # Check if ports are allowed
      if sudo ufw status 2>/dev/null | grep -q "80/tcp.*ALLOW"; then
        log_info "  Port 80/tcp: allowed ✓"
      else
        log_warn "  Port 80/tcp: not explicitly allowed"
      fi
      if sudo ufw status 2>/dev/null | grep -q "443/tcp.*ALLOW"; then
        log_info "  Port 443/tcp: allowed ✓"
      else
        log_warn "  Port 443/tcp: not explicitly allowed"
      fi
    else
      log_info "UFW is installed but inactive ✓"
    fi
  fi

  # firewalld (CentOS/RHEL/Fedora)
  if command -v firewall-cmd &>/dev/null; then
    fw_found=true
    if firewall-cmd --state &>/dev/null; then
      log_warn "firewalld is active."
      log_warn "Ensure ports are open: sudo firewall-cmd --permanent --add-service={http,https} && sudo firewall-cmd --reload"
      if firewall-cmd --list-services 2>/dev/null | grep -q "http"; then
        log_info "  HTTP service: allowed ✓"
      else
        log_warn "  HTTP service: not enabled"
      fi
      if firewall-cmd --list-services 2>/dev/null | grep -q "https"; then
        log_info "  HTTPS service: allowed ✓"
      else
        log_warn "  HTTPS service: not enabled"
      fi
    else
      log_info "firewalld is installed but inactive ✓"
    fi
  fi

  # iptables fallback
  if ! $fw_found && command -v iptables &>/dev/null; then
    local rules
    rules=$(sudo iptables -L INPUT -n 2>/dev/null | grep -c "DROP\|REJECT" || true)
    if [[ "$rules" -gt 0 ]]; then
      log_warn "iptables has $rules DROP/REJECT rules — verify ports 80/443 are accessible."
    else
      log_info "No restrictive iptables rules detected ✓"
    fi
  fi

  if ! $fw_found; then
    log_info "No firewall detected ✓"
  fi
}

check_firewall

# ---------------------------------------------------------------------------
# Step 5: CN network detection & mirror setup
# ---------------------------------------------------------------------------
log_step "Network environment detection"

detect_cn_network() {
  # Quick connectivity test to Docker Hub
  if curl --connect-timeout 5 -fsSL "https://registry-1.docker.io/v2/" &>/dev/null || \
     curl --connect-timeout 5 -fsSL "https://hub.docker.com" &>/dev/null; then
    log_info "Docker Hub reachable ✓"
    return
  fi

  log_warn "Docker Hub is slow or unreachable — possible China mainland network."

  if [[ -f "$SCRIPT_DIR/scripts/setup-cn-mirrors.sh" ]]; then
    if ask_yes_no "Set up China registry mirrors for faster pulls?" "y"; then
      bash "$SCRIPT_DIR/scripts/setup-cn-mirrors.sh"
    fi
  fi

  if [[ -f "$SCRIPT_DIR/scripts/localize-images.sh" ]]; then
    if ask_yes_no "Localize container images to use CN mirrors?" "y"; then
      bash "$SCRIPT_DIR/scripts/localize-images.sh" --cn
    fi
  fi
}

detect_cn_network

# ---------------------------------------------------------------------------
# Step 6: Extended dependency check
# ---------------------------------------------------------------------------
log_step "Checking dependencies"

if [[ -f "$SCRIPT_DIR/scripts/check-deps.sh" ]]; then
  bash "$SCRIPT_DIR/scripts/check-deps.sh" || {
    log_error "Dependency check failed. Fix the issues above and re-run."
    exit 1
  }
fi

# Additional useful commands
for cmd in git jq envsubst; do
  if command -v "$cmd" &>/dev/null; then
    log_info "$cmd found ✓"
  else
    log_warn "$cmd not found — some scripts may not work without it."
  fi
done

# ---------------------------------------------------------------------------
# Step 7: Setup environment
# ---------------------------------------------------------------------------
log_step "Environment configuration"

if [[ ! -f "$SCRIPT_DIR/.env" ]]; then
  if [[ -f "$SCRIPT_DIR/scripts/setup-env.sh" ]]; then
    bash "$SCRIPT_DIR/scripts/setup-env.sh"
  else
    if [[ -f "$SCRIPT_DIR/.env.example" ]]; then
      cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
      log_warn "Copied .env.example → .env  — edit it with your values!"
    else
      log_error "No .env.example found. Create .env manually."
      exit 1
    fi
  fi
else
  log_warn ".env already exists, skipping setup. Remove it to reconfigure."
fi

# ---------------------------------------------------------------------------
# Step 8: Create data directories
# ---------------------------------------------------------------------------
log_step "Creating data directories"

DATA_DIRS=(
  data/traefik/certs
  data/portainer
  data/prometheus
  data/grafana
  data/loki
  data/tempo
  data/authentik/media
  data/authentik/certs
  data/nextcloud
  data/gitea
  data/vaultwarden
  data/uptime-kuma
)

for dir in "${DATA_DIRS[@]}"; do
  mkdir -p "$SCRIPT_DIR/$dir"
done
log_info "Created ${#DATA_DIRS[@]} data directories ✓"

# ACME cert file needs strict permissions
ACME_FILE="$SCRIPT_DIR/config/traefik/acme.json"
if [[ ! -f "$ACME_FILE" ]]; then
  touch "$ACME_FILE"
fi
chmod 600 "$ACME_FILE"
log_info "acme.json permissions set to 600 ✓"

# ---------------------------------------------------------------------------
# Step 9: Create Docker network
# ---------------------------------------------------------------------------
log_step "Setting up Docker network"

if docker network inspect proxy &>/dev/null; then
  log_info "Docker network 'proxy' exists ✓"
else
  docker network create proxy
  log_info "Created Docker network 'proxy' ✓"
fi

# ---------------------------------------------------------------------------
# Step 10: Launch base infrastructure
# ---------------------------------------------------------------------------
log_step "Launching base infrastructure"

cd "$SCRIPT_DIR"
docker compose -f docker-compose.base.yml up -d 2>&1 | tee -a "$LOG_FILE"

# ---------------------------------------------------------------------------
# Step 11: Wait for containers to be healthy
# ---------------------------------------------------------------------------
log_step "Waiting for services to become healthy"

if [[ -f "$SCRIPT_DIR/scripts/wait-healthy.sh" ]]; then
  bash "$SCRIPT_DIR/scripts/wait-healthy.sh" --timeout 120 || {
    log_warn "Some services may not be fully healthy yet."
    log_warn "Run ./scripts/diagnose.sh for details."
  }
else
  # Basic wait — poll docker compose ps for 60s
  local_timeout=60
  local_elapsed=0
  while [[ $local_elapsed -lt $local_timeout ]]; do
    unhealthy=$(docker compose -f docker-compose.base.yml ps --format json 2>/dev/null | \
      grep -c '"unhealthy"\|"starting"' || true)
    if [[ "$unhealthy" -eq 0 ]]; then
      break
    fi
    sleep 5
    ((local_elapsed += 5))
  done
fi

# ---------------------------------------------------------------------------
# Done!
# ---------------------------------------------------------------------------
echo ""
log_info "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
log_info "${GREEN}${BOLD}  ✓ HomeLab Stack — Base infrastructure is up!${NC}"
log_info "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
log_info "Next steps:"
log_info "  ./scripts/stack-manager.sh start sso         # Set up SSO first (recommended)"
log_info "  ./scripts/stack-manager.sh start monitoring  # Launch monitoring"
log_info "  ./scripts/stack-manager.sh list              # See all available stacks"
echo ""
log_info "Troubleshooting:"
log_info "  ./scripts/diagnose.sh                        # Run diagnostics"
log_info "  ./scripts/wait-healthy.sh                    # Check container health"
log_info "  ./scripts/check-connectivity.sh              # Test network access"
echo ""
log_info "Install log saved to: $LOG_FILE"
log_info "Documentation: docs/getting-started.md"
