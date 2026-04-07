#!/usr/bin/env bash
# =============================================================================
# Setup CN Mirrors - Configure Docker daemon with China mirror sources
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()  { echo -e "${BLUE}==>${NC} $*"; }

DAEMON_JSON="/etc/docker/daemon.json"
BACKUP_FILE="/etc/docker/daemon.json.backup.$(date +%Y%m%d_%H%M%S)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
CONFIG_FILE="$SCRIPT_DIR/../config/cn-mirrors.yml"

check_root() {
  if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
  fi
}

check_docker() {
  if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed. Please install Docker first."
    exit 1
  fi
  log_info "Docker found: $(docker --version)"
}

ask_location() {
  echo ""
  log_step "Network Environment Detection"
  echo -e "${YELLOW}Are you deploying from mainland China?${NC}"
  echo "  1) Yes - Configure CN mirrors for faster access"
  echo "  2) No  - Use default Docker Hub"
  echo "  3) Auto-detect (test connectivity)"
  echo ""
  read -rp "Select option [1-3]: " choice
  
  case $choice in
    1) return 0 ;;
    2) return 1 ;;
    3) 
      log_info "Auto-detecting network environment..."
      if timeout 5 curl -sf https://www.google.com > /dev/null 2>&1; then
        log_info "Google accessible - likely not in China"
        return 1
      else
        log_info "Google not accessible - likely in China"
        return 0
      fi
      ;;
    *)
      log_error "Invalid choice"
      exit 1
      ;;
  esac
}

backup_config() {
  if [[ -f "$DAEMON_JSON" ]]; then
    log_info "Backing up existing daemon.json to $BACKUP_FILE"
    cp "$DAEMON_JSON" "$BACKUP_FILE"
  fi
}

configure_mirrors() {
  log_step "Configuring Docker daemon mirrors"
  
  local mirrors
  if command -v yq &> /dev/null && [[ -f "$CONFIG_FILE" ]]; then
    mirrors=$(yq eval '.docker_mirrors[]' "$CONFIG_FILE" | jq -R . | jq -s .)
  else
    mirrors='["https://docker.m.daocloud.io","https://hub-mirror.c.163.com","https://mirror.baidubce.com","https://mirror.gcr.io"]'
  fi
  
  local daemon_config
  if [[ -f "$DAEMON_JSON" ]]; then
    daemon_config=$(cat "$DAEMON_JSON" | jq --argjson mirrors "$mirrors" '. + {"registry-mirrors": $mirrors}')
  else
    daemon_config=$(echo "{}" | jq --argjson mirrors "$mirrors" '{"registry-mirrors": $mirrors}')
  fi
  
  echo "$daemon_config" | jq '.' > "$DAEMON_JSON"
  log_info "Docker daemon configuration updated"
  log_info "Configured mirrors:"
  echo "$daemon_config" | jq -r '.["registry-mirrors"][]' | sed 's/^/  - /'
}

restart_docker() {
  log_step "Restarting Docker daemon"
  
  if command -v systemctl &> /dev/null; then
    log_info "Using systemctl to restart Docker"
    systemctl restart docker
    sleep 3
    if systemctl is-active --quiet docker; then
      log_info "Docker restarted successfully"
    else
      log_error "Docker failed to restart"
      exit 1
    fi
  elif command -v service &> /dev/null; then
    log_info "Using service to restart Docker"
    service docker restart
    sleep 3
  else
    log_warn "Cannot restart Docker automatically. Please restart Docker manually."
    return
  fi
}

test_mirrors() {
  log_step "Testing mirror configuration"
  
  log_info "Pulling hello-world image to test mirrors..."
  if docker pull hello-world; then
    log_info "✓ Mirror configuration working correctly!"
    docker rmi hello-world 2>/dev/null || true
    return 0
  else
    log_error "✗ Failed to pull image. Mirror configuration may be incorrect."
    return 1
  fi
}

restore_backup() {
  if [[ -f "$1" ]]; then
    log_info "Restoring from backup: $1"
    cp "$1" "$DAEMON_JSON"
    restart_docker
    log_info "Backup restored successfully"
  else
    log_error "Backup file not found: $1"
    exit 1
  fi
}

main() {
  check_root
  check_docker
  
  if [[ "${1:-}" == "--restore" ]]; then
    if [[ -z "${2:-}" ]]; then
      log_error "Please specify backup file"
      exit 1
    fi
    restore_backup "$2"
    exit 0
  fi
  
  if ! ask_location; then
    log_info "Skipping CN mirror configuration"
    exit 0
  fi
  
  backup_config
  configure_mirrors
  restart_docker
  test_mirrors
  
  echo ""
  log_info "✓ CN mirror setup complete!"
  log_info "If you experience issues, restore backup with:"
  echo "  sudo $0 --restore $BACKUP_FILE"
}

main "$@"
