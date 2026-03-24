#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Setup CN Docker Mirror Acceleration
# Configures Docker daemon to use Chinese mirror registries for faster pulls.
# Safe to run multiple times (idempotent). Backs up existing daemon.json.
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()  { echo -e "${BLUE}[STEP]${NC}  $*"; }

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
DAEMON_JSON="/etc/docker/daemon.json"
BACKUP_DIR="/etc/docker/backups"

# Known working CN mirrors (ordered by reliability)
CN_MIRRORS=(
  "https://docker.m.daocloud.io"
  "https://mirror.baidubce.com"
  "https://ccr.ccs.tencentyun.com"
  "https://hub-mirror.c.163.com"
  "https://registry.docker-cn.com"
)

# ---------------------------------------------------------------------------
# Check root
# ---------------------------------------------------------------------------
check_root() {
  if [[ "$EUID" -ne 0 ]]; then
    log_error "This script must be run as root (sudo)"
    log_info  "Usage: sudo $0 [--restore]"
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Backup existing daemon.json
# ---------------------------------------------------------------------------
backup_daemon() {
  if [[ -f "$DAEMON_JSON" ]]; then
    mkdir -p "$BACKUP_DIR"
    local ts
    ts=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/daemon.json.bak.${ts}"
    cp "$DAEMON_JSON" "$backup_file"
    log_info "Backed up existing daemon.json -> $backup_file"
  fi
}

# ---------------------------------------------------------------------------
# Create / update daemon.json with CN mirrors
# ---------------------------------------------------------------------------
setup_mirrors() {
  log_step "Configuring Docker daemon with CN mirrors"

  local mirrors_json
  mirrors_json=$(printf '"%s",' "${CN_MIRRORS[@]}")
  mirrors_json="[${mirrors_json%,}]"

  if [[ -f "$DAEMON_JSON" ]]; then
    # Use python3 if available, otherwise jq or manual merge
    if command -v python3 &>/dev/null; then
      python3 -c "
import json, sys
mirrors = $(echo "$mirrors_json")
with open('$DAEMON_JSON', 'r') as f:
    cfg = json.load(f)
cfg['registry-mirrors'] = mirrors
with open('$DAEMON_JSON', 'w') as f:
    json.dump(cfg, f, indent=2)
" 2>/dev/null
      if [[ $? -eq 0 ]]; then
        log_info "Updated existing daemon.json with CN mirrors"
        return
      fi
    fi

    # Fallback: use jq
    if command -v jq &>/dev/null; then
      local tmp
      tmp=$(mktemp)
      jq --argjson mirrors "$mirrors_json" '.["registry-mirrors"]=$mirrors' "$DAEMON_JSON" > "$tmp"
      mv "$tmp" "$DAEMON_JSON"
      log_info "Updated existing daemon.json with jq"
      return
    fi

    # Last resort: show warning
    log_warn "Neither python3 nor jq found. Overwriting daemon.json."
    log_warn "Custom daemon.json settings will be lost!"
  fi

  # Create fresh daemon.json
  cat > "$DAEMON_JSON" <<EOF
{
  "registry-mirrors": $mirrors_json
}
EOF
  log_info "Created $DAEMON_JSON"
}

# ---------------------------------------------------------------------------
# Restart Docker daemon
# ---------------------------------------------------------------------------
restart_docker() {
  log_step "Restarting Docker daemon"

  # Detect init system
  if command -v systemctl &>/dev/null; then
    systemctl restart docker
    log_info "Docker restarted via systemctl"
  elif command -v service &>/dev/null; then
    service docker restart
    log_info "Docker restarted via service"
  else
    log_warn "Cannot detect init system. Restart Docker manually:"
    log_warn "  sudo systemctl restart docker  OR  sudo service docker restart"
    return
  fi

  # Wait for Docker to be ready
  local retries=10
  while [[ $retries -gt 0 ]]; do
    if docker info &>/dev/null; then
      log_info "Docker daemon is ready"
      return
    fi
    sleep 1
    ((retries--))
  done
  log_warn "Docker may not be fully ready yet. Try: docker info"
}

# ---------------------------------------------------------------------------
# Verify mirror pull
# ---------------------------------------------------------------------------
verify_mirrors() {
  log_step "Verifying mirror acceleration"

  local test_images=(
    "hello-world:latest"
  )

  for img in "${test_images[@]}"; do
    log_info "Pulling test image: $img"
    if docker pull "$img" &>/dev/null; then
      log_info "Successfully pulled $img"
      docker rmi "$img" &>/dev/null || true
      return 0
    else
      log_warn "Failed to pull $img"
    fi
  done

  log_warn "Test pull failed. Check your network and mirror availability."
  return 1
}

# ---------------------------------------------------------------------------
# Restore backup
# ---------------------------------------------------------------------------
restore_backup() {
  log_step "Restoring previous daemon.json"

  if [[ ! -d "$BACKUP_DIR" ]]; then
    log_error "No backups found in $BACKUP_DIR"
    exit 1
  fi

  local latest
  latest=$(ls -t "$BACKUP_DIR"/daemon.json.bak.* 2>/dev/null | head -1)

  if [[ -z "$latest" ]]; then
    log_error "No backup files found"
    exit 1
  fi

  log_info "Restoring from: $latest"
  cp "$latest" "$DAEMON_JSON"
  restart_docker
  log_info "Restored successfully"
}

# ---------------------------------------------------------------------------
# Show current mirror config
# ---------------------------------------------------------------------------
show_status() {
  echo
  echo -e "${BLUE}=== Docker Mirror Status ===${NC}"
  echo

  if [[ ! -f "$DAEMON_JSON" ]]; then
    log_warn "No daemon.json found at $DAEMON_JSON"
    return
  fi

  log_info "Current daemon.json:"
  cat "$DAEMON_JSON"

  echo
  if docker info 2>/dev/null | grep -q "Registry Mirrors"; then
    log_info "Docker is using configured mirrors"
    docker info 2>/dev/null | grep -A 10 "Registry Mirrors" || true
  else
    log_warn "No registry mirrors detected in Docker info"
  fi
}

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
usage() {
  cat <<EOF
Usage: sudo $0 [OPTIONS]

Configure Docker daemon with Chinese mirror registries for faster pulls.

Options:
  (none)      Setup CN mirrors (default)
  --restore   Restore previous daemon.json from backup
  --status    Show current mirror configuration
  --verify    Test mirror connectivity
  -h, --help  Show this help

Examples:
  sudo $0                  # Setup mirrors
  sudo $0 --restore        # Roll back
  sudo $0 --status         # Check config
EOF
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  echo
  echo -e "${BLUE}=== HomeLab Stack — CN Mirror Setup ===${NC}"
  echo

  local action="${1:-setup}"
  case "$action" in
    --restore)   check_root; restore_backup ;;
    --status)    show_status ;;
    --verify)    check_root; verify_mirrors ;;
    -h|--help)   usage; exit 0 ;;
    setup|*)
      check_root
      backup_daemon
      setup_mirrors
      restart_docker
      verify_mirrors || log_warn "Mirror verification had issues. Check manually."
      show_status
      echo
      log_info "CN mirror setup complete!"
      ;;
  esac
}

main "$@"
