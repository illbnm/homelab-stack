#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Installer
# =============================================================================
set -euo pipefail
IFS=$'\n\t'

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()  { echo -e "\n${BLUE}${BOLD}==> $*${NC}"; }

cleanup() {
  if [[ $? -ne 0 ]]; then
    log_error "Installation failed. Check logs at ~/.homelab/install.log"
  fi
}
trap cleanup EXIT

curl_retry() {
  local max_attempts=3
  local delay=5
  for i in $(seq 1 $max_attempts); do
    curl --connect-timeout 10 --max-time 60 "$@" && return 0
    echo "Attempt $i failed, retrying in ${delay}s..."
    sleep $delay
    delay=$((delay * 2))
  done
  return 1
}
export -f curl_retry

check_robustness() {
  # Resource checks
  local free_gb
  free_gb=$(df -BG / | awk 'NR==2 {gsub(/G/,"",$4); print $4}' || echo "100")
  if [[ "$free_gb" -lt 5 ]]; then
    log_error "Disk space < 5GB (${free_gb}GB). Aborting."
    exit 1
  elif [[ "$free_gb" -lt 20 ]]; then
    log_warn "Disk space < 20GB (${free_gb}GB)."
  fi

  if command -v free &>/dev/null; then
    local total_mem
    total_mem=$(free -m | awk 'NR==2{print $2}')
    if [[ "$total_mem" -lt 2000 ]]; then
      log_warn "Memory < 2GB. Some services may fail."
    fi
  fi

  for port in 53 80 443 3000; do
    if (ss -tlnp 2>/dev/null || netstat -tlnp 2>/dev/null) | grep -q ":${port} "; then
      log_warn "Port $port is already in use."
    fi
  done

  # Firewall rules check
  if command -v ufw &>/dev/null && sudo ufw status 2>/dev/null | grep -q "active"; then
    log_warn "UFW is active, ensure required ports are allowed."
  fi
  if command -v firewall-cmd &>/dev/null && sudo firewall-cmd --state 2>/dev/null | grep -q "running"; then
    log_warn "firewalld is running, ensure required ports are allowed."
  fi

  # Docker installation & checks
  if ! command -v docker &>/dev/null; then
    log_info "Docker not found, attempting auto-install..."
    curl_retry -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh || { log_error "Docker installation failed."; exit 1; }
    rm -f get-docker.sh
  fi

  if command -v docker-compose &>/dev/null && ! docker compose version &>/dev/null; then
    log_warn "Docker Compose v1 detected. Please upgrade to Docker Compose v2."
  fi

  if [[ $EUID -ne 0 ]] && ! groups | grep -q docker; then
    log_info "Adding current user to docker group..."
    sudo usermod -aG docker "$USER" || true
    log_warn "You may need to log out and log back in for docker group changes to take effect."
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

# ---------------------------------------------------------------------------
# Step 1: Check dependencies and robustness
# ---------------------------------------------------------------------------
log_step "Checking system robustness"
check_robustness

log_step "Checking dependencies"
bash "$(dirname "$0")/scripts/check-deps.sh" || true

# ---------------------------------------------------------------------------
# Step 2: CN network detection
# ---------------------------------------------------------------------------
log_step "Network environment detection"
if [ -f "$(dirname "$0")/scripts/check-connectivity.sh" ]; then
  bash "$(dirname "$0")/scripts/check-connectivity.sh"
else
  log_warn "Connectivity checker not found."
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
docker compose -f docker-compose.base.yml up -d

log_info ""
log_info "${GREEN}${BOLD}✓ Base infrastructure is up!${NC}"
log_info ""
log_info "Next steps:"
log_info "  ./scripts/stack-manager.sh start sso        # Set up SSO first (recommended)"
log_info "  ./scripts/stack-manager.sh start monitoring # Launch monitoring"
log_info "  ./scripts/stack-manager.sh list             # See all available stacks"
log_info ""
log_info "Documentation: docs/getting-started.md"
