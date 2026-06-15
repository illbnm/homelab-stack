#!/usr/bin/env bash
# =============================================================================
# setup-cn-mirrors.sh - Docker Registry Mirrors for China Mainland
# =============================================================================
# This script helps users in China configure Docker daemon with registry
# mirrors to improve image pull speed. It interactively asks whether to
# apply CN mirrors, backs up existing /etc/docker/daemon.json, writes
# mirror entries, restarts Docker, and verifies with 'docker pull hello-world'.
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Default mirror list (primary + backup)
MIRRORS=(
  "https://docker.m.daocloud.io"
  "https://mirror.gcr.io"
  "https://hub-mirror.c.163.com"
)

# Check if running as root
check_root() {
  if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root. Use sudo."
    exit 1
  fi
}

# Check if Docker is installed
check_docker() {
  if ! command -v docker &> /dev/null; then
    error "Docker is not installed. Please install Docker first."
    exit 1
  fi
}

# Backup existing daemon.json
backup_daemon() {
  local daemon_file="/etc/docker/daemon.json"
  if [[ -f "$daemon_file" ]]; then
    local backup="${daemon_file}.bak.$(date +%Y%m%d%H%M%S)"
    cp "$daemon_file" "$backup"
    info "Backed up existing $daemon_file to $backup"
  fi
}

# Write new daemon.json with mirrors
write_mirrors() {
  local daemon_file="/etc/docker/daemon.json"
  local tmp_file
  tmp_file=$(mktemp)

  # Build JSON array of mirrors
  local mirrors_json="["
  for ((i=0; i<${#MIRRORS[@]}; i++)); do
    if [[ $i -ne 0 ]]; then
      mirrors_json+=", "
    fi
    mirrors_json+="\"${MIRRORS[$i]}\""
  done
  mirrors_json+="]"

  # Check if daemon.json already exists and has other config
  if [[ -f "$daemon_file" ]]; then
    # Merge with existing config (preserve other keys)
    if command -v jq &> /dev/null; then
      jq --argjson mirrors "$mirrors_json" '.registry-mirrors = $mirrors' "$daemon_file" > "$tmp_file"
    else
      # Without jq, simply overwrite (simple case)
      cat > "$tmp_file" <<EOF
{
  "registry-mirrors": $mirrors_json
}
EOF
    fi
  else
    cat > "$tmp_file" <<EOF
{
  "registry-mirrors": $mirrors_json
}
EOF
  fi

  # Move tmp to daemon_file
  cat "$tmp_file" > "$daemon_file"
  rm -f "$tmp_file"
  info "Written registry mirrors to $daemon_file"
}

# Restart Docker service
restart_docker() {
  info "Restarting Docker daemon..."
  if command -v systemctl &> /dev/null; then
    systemctl restart docker
  elif command -v service &> /dev/null; then
    service docker restart
  else
    error "Cannot restart Docker. Please restart manually."
    return 1
  fi
}

# Verify mirror works by pulling hello-world
verify_mirror() {
  info "Verifying mirror configuration: pulling 'hello-world'..."
  # Remove hello-world if exists locally
  docker rmi hello-world 2>/dev/null || true
  if docker pull hello-world; then
    info "Successfully pulled hello-world using mirrors."
  else
    warn "Docker pull failed. Mirrors may not be working. Check network."
    return 1
  fi
}

# Main function
main() {
  check_root
  check_docker

  echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${YELLOW}  Docker Registry Mirror Setup (CN)${NC}"
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo

  read -r -p "Are you deploying in mainland China? (y/N): " response
  if [[ ! "$response" =~ ^[Yy](es)?$ ]]; then
    info "No changes made. Exiting."
    exit 0
  fi

  echo
  info "Available mirror sources:"
  for ((i=0; i<${#MIRRORS[@]}; i++)); do
    echo "  $((i+1)). ${MIRRORS[$i]}"
  done
  echo

  # Allow user to customize mirrors (optional)
  read -r -p "Use these default mirrors? (Y/n): " use_default
  if [[ "$use_default" =~ ^[Nn](o)?$ ]]; then
    echo "Enter your own mirror URLs (one per line, empty line to finish):"
    MIRRORS=()
    while IFS= read -r line; do
      [[ -z "$line" ]] && break
      MIRRORS+=("$line")
    done
    if [[ ${#MIRRORS[@]} -eq 0 ]]; then
      error "No mirrors provided. Aborting."
      exit 1
    fi
  fi

  backup_daemon
  write_mirrors
  restart_docker
  echo
  verify_mirror

  echo
  info "Docker mirror configuration completed successfully!"
  echo -e "${GREEN}You can now enjoy faster image pulls in China.${NC}"
}

main "$@"
