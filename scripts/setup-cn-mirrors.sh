#!/bin/bash
# setup-cn-mirrors.sh - Docker Mirror Setup for China Network
# Usage: ./setup-cn-mirrors.sh [--restore]
#
# This script configures Docker to use Chinese mirror registries
# for faster and more reliable image pulls in mainland China.
#
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
MIRROR_CONFIG="/etc/docker/daemon.json"
BACKUP_FILE="/etc/docker/daemon.json.bak"

# Mirror configurations (multiple sources for reliability)
MIRRORS='{
  "registry-mirrors": [
    "https://mirror.baidubce.com",
    "https://docker.m.daocloud.io",
    "https://docker.rainbond.io",
    "https://hub.ratgod.dev"
  ]
}'

info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }

restore_mode=false
[[ "${1:-}" == "--restore" ]] && restore_mode=true

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Please run as root (use sudo)"
        echo "Usage: sudo $0 [--restore]"
        exit 1
    fi
}

# Check if in mainland China (approximate check via network)
check_cn() {
    info "Checking network environment..."
    if curl -s --connect-timeout 5 "https://docker.io" > /dev/null 2>&1; then
        info "International network detected - no mirror needed"
        return 1
    fi
    if curl -s --connect-timeout 5 "https://mirror.baidubce.com" > /dev/null 2>&1; then
        return 0
    fi
    warn "Could not detect network environment. Proceeding with mirror configuration."
    return 0
}

# Backup current Docker config
backup_config() {
    if [[ -f "$MIRROR_CONFIG" ]]; then
        info "Backing up current config to $BACKUP_FILE"
        cp "$MIRROR_CONFIG" "$BACKUP_FILE"
    fi
}

# Restore original Docker config
restore_config() {
    info "Restoring original Docker config..."
    if [[ -f "$BACKUP_FILE" ]]; then
        cp "$BACKUP_FILE" "$MIRROR_CONFIG"
        ok "Config restored. Restart Docker: sudo systemctl restart docker"
    else
        warn "No backup found. Nothing to restore."
    fi
}

# Apply mirror configuration
apply_config() {
    info "Applying Docker mirror configuration..."
    sudo mkdir -p "$(dirname "$MIRROR_CONFIG")"
    echo "$MIRRORS" | sudo tee "$MIRROR_CONFIG" > /dev/null
    ok "Mirror config written to $MIRROR_CONFIG"
}

# Verify configuration by pulling hello-world
verify_config() {
    info "Verifying Docker pull..."
    if sudo docker pull hello-world > /dev/null 2>&1; then
        ok "Docker pull successful with mirror!"
    else
        warn "Docker pull failed - mirrors may not be reachable"
        warn "Try: sudo systemctl restart docker && $0"
        return 1
    fi
    return 0
}

# Main logic
check_root

if [[ $restore_mode == true ]]; then
    restore_config
    exit 0
fi

if check_cn; then
    info "Mainland China network detected. Configuring mirrors..."
    backup_config
    apply_config

    info "Restarting Docker to apply changes..."
    sudo systemctl restart docker

    if verify_config; then
        ok "Setup complete! Docker is now configured with CN mirrors."
        echo ""
        echo "To restore original config:"
        echo "  sudo $0 --restore"
    else
        warn "Setup completed but verification failed."
        warn "You may need to restart Docker manually:"
        echo "  sudo systemctl restart docker"
    fi
else
    ok "No mirror configuration needed."
fi
