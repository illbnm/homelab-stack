#!/usr/bin/env bash
# =============================================================================
# setup-cn-mirrors.sh — Configure Docker daemon for mainland China mirrors
# =============================================================================
# This script configures Docker daemon.json to use domestic mirrors for
# faster image pulls in mainland China network environment.
#
# Usage:
#   ./setup-cn-mirrors.sh [--dry-run] [--restore] [--check]
#
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
DAEMON_JSON="/etc/docker/daemon.json"
DAEMON_JSON_BACKUP="${DAEMON_JSON}.backup.$(date +%Y%m%d_%H%M%S)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"

# China Docker mirror registry list (ordered by reliability and speed)
CN_MIRRORS=(
  "https://docker.m.daocloud.io"
  "https://docker.mirrors.ustc.edu.cn"
  "https://hub-mirror.c.163.com"
  "https://mirror.baidubce.com"
)

# Logging functions
log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()  { echo -e "\n${BLUE}${BOLD}==>${NC} $*"; }

# Check if running as root
check_root() {
  if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
  fi
}

# Check if Docker is installed
check_docker() {
  if ! command -v docker &>/dev/null; then
    log_error "Docker is not installed. Please install Docker first."
    exit 1
  fi
  log_info "Docker found: $(docker --version)"
}

# Backup existing daemon.json
backup_daemon_json() {
  if [[ -f "$DAEMON_JSON" ]]; then
    log_step "Backing up existing daemon.json"
    cp "$DAEMON_JSON" "$DAEMON_JSON_BACKUP"
    log_info "Backup created: $DAEMON_JSON_BACKUP"
  fi
}

# Generate daemon.json with CN mirrors
generate_daemon_config() {
  local existing_config="{}"

  # Read existing config if exists
  if [[ -f "$DAEMON_JSON" ]]; then
    existing_config=$(cat "$DAEMON_JSON")
  fi

  # Build mirrors array in JSON format
  local mirrors_json
  mirrors_json=$(printf '%s\n' "${CN_MIRRORS[@]}" | jq -R . | jq -s .)

  # Merge with existing config
  echo "$existing_config" | jq --argjson mirrors "$mirrors_json" '. + {"registry-mirrors": $mirrors}' 2>/dev/null || {
    # Fallback if jq merge fails - create fresh config
    cat <<EOF
{
  "registry-mirrors": ${mirrors_json},
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "live-restore": true,
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 65535,
      "Soft": 65535
    }
  }
}
EOF
  }
}

# Configure Docker mirrors
configure_mirrors() {
  local dry_run="${1:-false}"

  log_step "Configuring Docker daemon with China mirrors"

  if [[ "$dry_run" == "true" ]]; then
    log_warn "[DRY-RUN] Would create/modify: $DAEMON_JSON"
    log_info "Preview of configuration:"
    generate_daemon_config | jq '.' 2>/dev/null || generate_daemon_config
    return
  fi

  # Backup existing config
  backup_daemon_json

  # Create new config
  generate_daemon_config > "$DAEMON_JSON"

  log_info "Docker daemon configuration updated"
  log_info "Mirrors configured:"
  jq -r '.["registry-mirrors"][]' "$DAEMON_JSON" 2>/dev/null | while read -r mirror; do
    echo "  - $mirror"
  done

  # Restart Docker daemon
  log_step "Restarting Docker daemon"
  if systemctl restart docker; then
    log_info "Docker daemon restarted successfully"

    # Wait for Docker to be ready
    sleep 3
    if docker info &>/dev/null; then
      log_info "Docker is ready"
      log_info "Verify mirrors with: docker info | grep -A 5 'Registry Mirrors'"
    else
      log_error "Docker failed to start after configuration change"
      log_error "Check logs: journalctl -u docker -n 50"
      exit 1
    fi
  else
    log_error "Failed to restart Docker daemon"
    log_error "Restoring backup..."
    if [[ -f "$DAEMON_JSON_BACKUP" ]]; then
      cp "$DAEMON_JSON_BACKUP" "$DAEMON_JSON"
      systemctl restart docker
    fi
    exit 1
  fi
}

# Restore original configuration
restore_config() {
  log_step "Restoring original Docker configuration"

  # Find the most recent backup
  local latest_backup
  latest_backup=$(ls -t /etc/docker/daemon.json.backup.* 2>/dev/null | head -1)

  if [[ -z "$latest_backup" ]]; then
    log_error "No backup found to restore"
    exit 1
  fi

  log_info "Found backup: $latest_backup"

  if [[ "${1:-}" != "--dry-run" ]]; then
    cp "$latest_backup" "$DAEMON_JSON"
    log_info "Configuration restored"

    log_step "Restarting Docker daemon"
    systemctl restart docker
    log_info "Docker daemon restarted"
  else
    log_warn "[DRY-RUN] Would restore: $latest_backup -> $DAEMON_JSON"
  fi
}

# Check current mirror configuration
check_config() {
  log_step "Checking Docker mirror configuration"

  if [[ ! -f "$DAEMON_JSON" ]]; then
    log_warn "No daemon.json found at $DAEMON_JSON"
    log_info "Docker is using default configuration (no mirrors)"
    return
  fi

  log_info "Current daemon.json:"
  jq '.' "$DAEMON_JSON" 2>/dev/null || cat "$DAEMON_JSON"

  echo
  if jq -e '.["registry-mirrors"]' "$DAEMON_JSON" &>/dev/null; then
    log_info "Configured mirrors:"
    jq -r '.["registry-mirrors"][]' "$DAEMON_JSON" | while read -r mirror; do
      echo "  - $mirror"
    done
  else
    log_warn "No registry mirrors configured"
  fi

  echo
  log_info "Docker info (mirrors section):"
  docker info 2>/dev/null | grep -A 10 "Registry Mirrors" || log_warn "No mirrors shown in docker info"
}

# Test mirror connectivity
test_mirrors() {
  log_step "Testing mirror connectivity"

  local test_image="library/alpine:latest"
  local mirrors_to_test=("${CN_MIRRORS[@]}")

  # Add mirrors from current config if available
  if [[ -f "$DAEMON_JSON" ]]; then
    while IFS= read -r mirror; do
      mirrors_to_test+=("$mirror")
    done < <(jq -r '.["registry-mirrors"][]' "$DAEMON_JSON" 2>/dev/null)
  fi

  # Remove duplicates
  IFS=' ' read -r -a mirrors_to_test <<< "$(echo "${mirrors_to_test[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' ')"

  for mirror in "${mirrors_to_test[@]}"; do
    local mirror_host
    mirror_host=$(echo "$mirror" | sed 's|https\?://||' | cut -d'/' -f1)

    if timeout 5 bash -c "curl -sf --connect-timeout 3 '$mirror/v2/'" &>/dev/null; then
      log_info "✓ $mirror (reachable)"
    else
      log_warn "✗ $mirror (unreachable or slow)"
    fi
  done
}

# Usage information
usage() {
  cat <<EOF
${BOLD}Usage:${NC}
  $0 [OPTIONS]

${BOLD}Options:${NC}
  --dry-run    Show what would be changed without making changes
  --restore    Restore the most recent backup of daemon.json
  --check      Check current mirror configuration
  --test       Test mirror connectivity
  -h, --help   Show this help message

${BOLD}Examples:${NC}
  # Configure Docker with China mirrors
  sudo $0

  # Preview changes without applying
  sudo $0 --dry-run

  # Restore original configuration
  sudo $0 --restore

  # Check current configuration
  $0 --check

${BOLD}Notes:${NC}
  - Requires root/sudo to modify /etc/docker/daemon.json
  - Automatically creates backup before modification
  - Restarts Docker daemon after configuration

${BOLD}Configured Mirrors:${NC}
EOF
  for mirror in "${CN_MIRRORS[@]}"; do
    echo "  - $mirror"
  done
}

# Main entry point
main() {
  local action="configure"
  local dry_run="false"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        dry_run="true"
        shift
        ;;
      --restore)
        action="restore"
        shift
        ;;
      --check)
        action="check"
        shift
        ;;
      --test)
        action="test"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        log_error "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
  done

  case "$action" in
    configure)
      check_root
      check_docker
      configure_mirrors "$dry_run"
      ;;
    restore)
      check_root
      restore_config "$dry_run"
      ;;
    check)
      check_config
      ;;
    test)
      test_mirrors
      ;;
  esac
}

main "$@"
