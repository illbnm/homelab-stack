#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Robust Installer
# Handles Docker installation, system checks, CN network adaptation, and
# base infrastructure launch.
#
# Usage: sudo ./install.sh
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
LOG_DIR="$HOME/.homelab"
LOG_FILE="$LOG_DIR/install.log"

mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

cleanup() {
  local exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    log_error "Installation failed (exit code: $exit_code). Check logs at $LOG_FILE"
  fi
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Network request wrapper with exponential backoff
# ---------------------------------------------------------------------------
curl_retry() {
  local max_attempts=3
  local delay=5
  local i
  for i in $(seq 1 "$max_attempts"); do
    if curl --connect-timeout 10 --max-time 60 "$@"; then
      return 0
    fi
    if [[ $i -lt $max_attempts ]]; then
      log_warn "Attempt $i failed, retrying in ${delay}s..."
      sleep "$delay"
      delay=$((delay * 2))
    fi
  done
  log_error "All $max_attempts attempts failed for: curl $*"
  return 1
}

# ---------------------------------------------------------------------------
# Detect OS distribution
# ---------------------------------------------------------------------------
detect_os() {
  if [[ -f /etc/os-release ]]; then
    # shellcheck source=/dev/null
    . /etc/os-release
    OS_ID="${ID:-unknown}"
    OS_ID_LIKE="${ID_LIKE:-}"
  elif [[ -f /etc/redhat-release ]]; then
    OS_ID="centos"
    OS_ID_LIKE="rhel"
  else
    OS_ID="unknown"
    export OS_ID_LIKE=""
  fi
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

detect_os

# =============================================================================
# Step 1: System Resource Checks
# =============================================================================
log_step "Step 1/8: System resource checks"

# Disk space check
free_gb=$(df -BG / | awk 'NR==2 {gsub(/G/,"",$4); print $4}')
if [[ "$free_gb" -lt 5 ]]; then
  log_error "Insufficient disk space: ${free_gb}GB free. Minimum 5GB required."
  exit 1
elif [[ "$free_gb" -lt 20 ]]; then
  log_warn "Low disk space: ${free_gb}GB free. Recommended: >= 20GB."
else
  log_info "Disk space: ${free_gb}GB free ✓"
fi

# Memory check
if command -v free &>/dev/null; then
  mem_mb=$(free -m | awk '/^Mem:/ {print $2}')
  if [[ "$mem_mb" -lt 2048 ]]; then
    log_warn "Low memory: ${mem_mb}MB. Recommended: >= 2048MB (2GB)."
  else
    log_info "Memory: ${mem_mb}MB ✓"
  fi
fi

# =============================================================================
# Step 2: Docker Installation
# =============================================================================
log_step "Step 2/8: Docker installation"

if command -v docker &>/dev/null; then
  docker_ver=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo '0.0.0')
  log_info "Docker already installed: v${docker_ver}"
else
  log_info "Docker not found. Installing..."

  case "$OS_ID" in
    ubuntu|debian|linuxmint|pop)
      apt-get update -qq
      apt-get install -y -qq ca-certificates curl gnupg lsb-release

      install -m 0755 -d /etc/apt/keyrings
      curl_retry -fsSL "https://download.docker.com/linux/${OS_ID}/gpg" -o /etc/apt/keyrings/docker.asc
      chmod a+r /etc/apt/keyrings/docker.asc

      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${OS_ID} $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list

      apt-get update -qq
      apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
      ;;
    centos|rhel|rocky|almalinux|fedora)
      if command -v dnf &>/dev/null; then
        PKG_MGR="dnf"
      else
        PKG_MGR="yum"
      fi
      $PKG_MGR install -y -q yum-utils
      yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
      $PKG_MGR install -y -q docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
      ;;
    arch|manjaro)
      pacman -Sy --noconfirm docker docker-compose
      ;;
    *)
      log_error "Unsupported OS: $OS_ID. Please install Docker manually."
      log_info "  https://docs.docker.com/get-docker/"
      exit 1
      ;;
  esac

  systemctl enable docker
  systemctl start docker
  log_info "Docker installed and started ✓"
fi

# =============================================================================
# Step 3: Docker Compose v2 check
# =============================================================================
log_step "Step 3/8: Docker Compose check"

if docker compose version &>/dev/null; then
  compose_ver=$(docker compose version --short 2>/dev/null)
  log_info "Docker Compose v2 found: $compose_ver ✓"
elif command -v docker-compose &>/dev/null; then
  log_warn "Docker Compose v1 detected. Please upgrade to v2 (plugin)."
  log_info "  https://docs.docker.com/compose/migrate/"
  log_info "  On Debian/Ubuntu: apt install docker-compose-plugin"
  exit 1
else
  log_error "Docker Compose not found. Install docker-compose-plugin."
  exit 1
fi

# =============================================================================
# Step 4: User & Permissions
# =============================================================================
log_step "Step 4/8: User & permissions"

if [[ $EUID -ne 0 ]]; then
  # Non-root: check docker group membership
  if groups | grep -q docker; then
    log_info "User $(whoami) is in docker group ✓"
  else
    log_info "Adding $(whoami) to docker group..."
    usermod -aG docker "$(whoami)"
    log_warn "Added to docker group. Please log out and back in, then re-run this script."
    exit 0
  fi
else
  log_info "Running as root ✓"
fi

# =============================================================================
# Step 5: Port Conflict Detection
# =============================================================================
log_step "Step 5/8: Port conflict detection"

port_conflict=false
for port in 53 80 443 3000 8080 9090; do
  if ss -tlnp 2>/dev/null | grep -q ":${port} "; then
    proc=$(ss -tlnp 2>/dev/null | grep ":${port} " | head -1 | sed 's/.*users:(("//' | cut -d'"' -f1)
    log_warn "Port $port is in use by: ${proc:-unknown}"
    port_conflict=true
  fi
done

if [[ "$port_conflict" == "false" ]]; then
  log_info "All required ports available ✓"
else
  log_warn "Some ports are in use. Services may fail to start. Resolve conflicts above."
fi

# =============================================================================
# Step 6: Firewall Check
# =============================================================================
log_step "Step 6/8: Firewall check"

if command -v ufw &>/dev/null && ufw status 2>/dev/null | grep -q "Status: active"; then
  log_info "UFW is active. Checking rules..."
  for port in 80 443; do
    if ufw status | grep -qE "^${port}.*ALLOW"; then
      log_info "  Port $port: allowed ✓"
    else
      log_warn "  Port $port: not explicitly allowed. Run: ufw allow $port/tcp"
    fi
  done
elif command -v firewall-cmd &>/dev/null && firewall-cmd --state 2>/dev/null | grep -q "running"; then
  log_info "Firewalld is active. Checking rules..."
  for port in 80 443; do
    if firewall-cmd --query-port="${port}/tcp" &>/dev/null; then
      log_info "  Port $port: allowed ✓"
    else
      log_warn "  Port $port: not open. Run: firewall-cmd --permanent --add-port=${port}/tcp && firewall-cmd --reload"
    fi
  done
else
  log_info "No active firewall detected (ufw/firewalld) ✓"
fi

# =============================================================================
# Step 7: Network Environment & CN Detection
# =============================================================================
log_step "Step 7/8: Network environment detection"

if [[ -x "$SCRIPT_DIR/scripts/check-connectivity.sh" ]]; then
  bash "$SCRIPT_DIR/scripts/check-connectivity.sh" || true
fi

# =============================================================================
# Step 8: Environment Setup & Launch
# =============================================================================
log_step "Step 8/8: Environment configuration & launch"

# Create proxy network if needed
if ! docker network inspect proxy &>/dev/null; then
  docker network create proxy
  log_info "Created docker network 'proxy' ✓"
else
  log_info "Docker network 'proxy' exists ✓"
fi

# Setup .env
if [[ ! -f "$SCRIPT_DIR/.env" ]]; then
  if [[ -x "$SCRIPT_DIR/scripts/setup-env.sh" ]]; then
    bash "$SCRIPT_DIR/scripts/setup-env.sh"
  else
    log_warn ".env not found. Copy .env.example and configure it."
  fi
else
  log_warn ".env already exists, skipping setup. Remove it to reconfigure."
fi

# Create data directories
mkdir -p \
  "$SCRIPT_DIR/data/traefik/certs" \
  "$SCRIPT_DIR/data/portainer" \
  "$SCRIPT_DIR/data/prometheus" \
  "$SCRIPT_DIR/data/grafana" \
  "$SCRIPT_DIR/data/loki" \
  "$SCRIPT_DIR/data/authentik/media" \
  "$SCRIPT_DIR/data/nextcloud" \
  "$SCRIPT_DIR/data/gitea" \
  "$SCRIPT_DIR/data/vaultwarden"

# Setup acme.json
acme_path="$SCRIPT_DIR/config/traefik/acme.json"
if [[ ! -f "$acme_path" ]]; then
  touch "$acme_path"
fi
chmod 600 "$acme_path"

# Launch base infrastructure
log_step "Launching base infrastructure"
cd "$SCRIPT_DIR/stacks/base"
docker compose up -d

log_info ""
log_info "${GREEN}${BOLD}✓ Base infrastructure is up!${NC}"
log_info ""
log_info "Next steps:"
log_info "  ./scripts/stack-manager.sh start sso        # Set up SSO first (recommended)"
log_info "  ./scripts/stack-manager.sh start monitoring  # Launch monitoring"
log_info "  ./scripts/stack-manager.sh list              # See all available stacks"
log_info ""
log_info "CN users: run 'sudo ./scripts/setup-cn-mirrors.sh' for Docker acceleration."
log_info "Documentation: docs/getting-started.md"
log_info "Logs saved to: $LOG_FILE"
