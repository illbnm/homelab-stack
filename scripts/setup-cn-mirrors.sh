#!/usr/bin/env bash
# =============================================================================
# setup-cn-mirrors.sh — Configure Docker registry mirrors for China
# Interactive script to set up Docker mirror acceleration for CN network
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()  { echo -e "\n${BLUE}${BOLD}==> $*${NC}"; }

# Mirror sources (ordered by reliability in CN)
MIRRORS=(
  "https://docker.m.daocloud.io"
  "https://hub-mirror.c.163.com"
  "https://mirror.baidubce.com"
  "https://mirror.gcr.io"
)

DAEMON_JSON="/etc/docker/daemon.json"
BACKUP_FILE="/etc/docker/daemon.json.backup.$(date +%Y%m%d_%H%M%S)"

# ---------------------------------------------------------------------------
# Check if running as root
# ---------------------------------------------------------------------------
check_root() {
  if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Interactive prompt for CN network detection
# ---------------------------------------------------------------------------
ask_china_network() {
  log_step "Network Environment Detection"
  echo -e "${YELLOW}Are you deploying in mainland China?${NC}"
  echo "  1) Yes - Use China mirror acceleration"
  echo "  2) No  - Skip mirror setup"
  echo "  3) Auto-detect (test connectivity)"
  echo ""
  read -rp "Select [1-3]: " choice

  case $choice in
    1)
      log_info "China network mode selected"
      return 0
      ;;
    2)
      log_info "Skipping mirror setup"
      exit 0
      ;;
    3)
      log_info "Testing connectivity..."
      if curl -sf --connect-timeout 5 --max-time 10 https://hub.docker.com &>/dev/null; then
        log_info "Docker Hub is directly accessible"
        read -rp "Still want to configure mirrors? [y/N]: " yn
        [[ "$yn" =~ ^[Yy]$ ]] || exit 0
      else
        log_warn "Docker Hub is not directly accessible"
        log_info "Mirror acceleration recommended"
      fi
      ;;
    *)
      log_error "Invalid choice"
      exit 1
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Backup existing daemon.json
# ---------------------------------------------------------------------------
backup_config() {
  if [[ -f "$DAEMON_JSON" ]]; then
    log_step "Backing up existing configuration"
    cp "$DAEMON_JSON" "$BACKUP_FILE"
    log_info "Backup saved to: $BACKUP_FILE"
  fi
}

# ---------------------------------------------------------------------------
# Generate daemon.json with mirrors
# ---------------------------------------------------------------------------
generate_config() {
  log_step "Generating Docker daemon configuration"

  local mirrors_json
  mirrors_json=$(printf '%s\n' "${MIRRORS[@]}" | jq -R . | jq -s .)

  # Preserve existing config if present
  if [[ -f "$BACKUP_FILE" ]]; then
    local existing_config
    existing_config=$(cat "$BACKUP_FILE")
    # Merge mirrors into existing config
    echo "$existing_config" | jq --argjson mirrors "$mirrors_json" '. + {"registry-mirrors": $mirrors}' > "$DAEMON_JSON"
  else
    # Create new config
    cat > "$DAEMON_JSON" <<EOF
{
  "registry-mirrors": ${mirrors_json},
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}
EOF
  fi

  log_info "Configuration written to $DAEMON_JSON"
}

# ---------------------------------------------------------------------------
# Restart Docker daemon
# ---------------------------------------------------------------------------
restart_docker() {
  log_step "Restarting Docker daemon"

  if command -v systemctl &>/dev/null; then
    systemctl restart docker
    log_info "Docker restarted via systemctl"
  elif command -v service &>/dev/null; then
    service docker restart
    log_info "Docker restarted via service"
  else
    log_warn "Could not restart Docker automatically. Please restart manually."
    return 1
  fi

  # Wait for Docker to be ready
  local attempts=0
  local max_attempts=30
  while ! docker info &>/dev/null; do
    ((attempts++))
    if [[ $attempts -ge $max_attempts ]]; then
      log_error "Docker did not start within ${max_attempts} seconds"
      return 1
    fi
    sleep 1
  done

  log_info "Docker is ready"
}

# ---------------------------------------------------------------------------
# Verify mirror configuration
# ---------------------------------------------------------------------------
verify_mirrors() {
  log_step "Verifying mirror configuration"

  log_info "Pulling hello-world image to test mirrors..."
  if timeout 60 docker pull hello-world:latest; then
    log_info "${GREEN}✓ Mirror configuration successful!${NC}"
    docker rmi hello-world:latest &>/dev/null || true
  else
    log_error "Mirror test failed. Check your network configuration."
    log_warn "You can restore backup with: cp $BACKUP_FILE $DAEMON_JSON && systemctl restart docker"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Display configuration summary
# ---------------------------------------------------------------------------
show_summary() {
  log_step "Configuration Summary"
  echo ""
  echo "  Mirror Configuration:"
  docker info 2>/dev/null | grep -A 5 "Registry Mirrors:" || true
  echo ""
  log_info "Configuration file: $DAEMON_JSON"
  [[ -f "$BACKUP_FILE" ]] && log_info "Backup file: $BACKUP_FILE"
  echo ""
  log_info "${GREEN}Mirror setup complete!${NC}"
  log_info "You can now pull images with improved speed in China network."
  echo ""
}

# ---------------------------------------------------------------------------
# Main execution
# ---------------------------------------------------------------------------
main() {
  echo -e ""
  echo -e "${BOLD}  Docker Mirror Setup for China Network${NC}"
  echo -e "${BOLD}  ======================================${NC}"
  echo -e ""

  check_root
  ask_china_network
  backup_config
  generate_config
  restart_docker
  verify_mirrors
  show_summary
}

main "$@"
