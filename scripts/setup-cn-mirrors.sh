#!/usr/bin/env bash

# =============================================================================
# HomeLab Stack - CN Docker Mirror Configuration Script
# =============================================================================
# This script configures Docker daemon to use Chinese registry mirrors.
# It is designed for users in mainland China who experience slow or
# blocked access to Docker Hub.
#
# Usage:
#   sudo bash scripts/setup-cn-mirrors.sh
#
# The script will:
#   1. Ask if you are located in mainland China.
#   2. If yes, write /etc/docker/daemon.json with registry mirrors.
#   3. Restart Docker and test pulling hello-world.
#
# Requirements:
#   - Root privileges (sudo)
#   - jq (will attempt to install if missing)
# =============================================================================

set -euo pipefail

# ------------------------------
# Colors
# ------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ------------------------------
# Helper functions
# ------------------------------
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    exit 1
}

# ------------------------------
# Pre-flight checks
# ------------------------------
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root (use sudo)."
fi

if ! command -v docker &>/dev/null; then
    error "Docker is not installed. Please install Docker first."
fi

# Check for jq, install if needed
if ! command -v jq &>/dev/null; then
    warn "jq is not installed. Attempting to install..."
    if command -v apt-get &>/dev/null; then
        apt-get update -qq && apt-get install -y -qq jq
    elif command -v yum &>/dev/null; then
        yum install -y -q jq
    elif command -v apk &>/dev/null; then
        apk add --no-cache jq
    else
        error "jq could not be installed automatically. Please install jq manually (https://stedolan.github.io/jq/)."
    fi
    info "jq installed successfully."
fi

# ------------------------------
# Interactive question
# ------------------------------
echo -e "${YELLOW}Are you located in mainland China and need Docker registry mirrors? [y/N]${NC}"
read -r answer
case "$answer" in
    [yY][eE][sS]|[yY])
        info "Proceeding with CN mirror configuration..."
        ;;
    *)
        info "Skipping CN mirror configuration."
        exit 0
        ;;
esac

# ------------------------------
# Define mirror list (primary + fallback)
# ------------------------------
PRIMARY_MIRROR="https://docker.m.daocloud.io"
FALLBACK_MIRRORS=(
    "https://mirror.gcr.io"
    "https://hub-mirror.c.163.com"
    "https://dockerproxy.com"
)

# Build JSON array
MIRROR_ARRAY="\"$PRIMARY_MIRROR\""
for m in "${FALLBACK_MIRRORS[@]}"; do
    MIRROR_ARRAY="$MIRROR_ARRAY, \"$m\""
done

# ------------------------------
# Backup existing daemon.json
# ------------------------------
DAEMON_JSON="/etc/docker/daemon.json"
if [[ -f "$DAEMON_JSON" ]]; then
    BACKUP="${DAEMON_JSON}.backup.$(date +%Y%m%d%H%M%S)"
    cp "$DAEMON_JSON" "$BACKUP"
    warn "Existing daemon.json backed up to $BACKUP"
fi

# ------------------------------
# Write new daemon.json with mirrors
# ------------------------------
info "Writing registry mirrors to $DAEMON_JSON..."

# Create or modify daemon.json using jq
tmpfile=$(mktemp)
if [[ -f "$DAEMON_JSON" ]]; then
    # Merge with existing config
    jq --argjson mirrors "[$MIRROR_ARRAY]" \
       '. + {"registry-mirrors": $mirrors}' "$DAEMON_JSON" > "$tmpfile"
else
    # Create new file
    jq -n --argjson mirrors "[$MIRROR_ARRAY]" \
       '{"registry-mirrors": $mirrors}' > "$tmpfile"
fi

# Validate JSON
if ! jq empty "$tmpfile" 2>/dev/null; then
    error "Generated JSON is invalid. Aborting."
fi

# Move to final location
mv "$tmpfile" "$DAEMON_JSON"
chmod 644 "$DAEMON_JSON"

info "Contents of $DAEMON_JSON:"
cat "$DAEMON_JSON"

# ------------------------------
# Restart Docker daemon
# ------------------------------
info "Restarting Docker daemon..."
systemctl restart docker.service || error "Failed to restart Docker."

# Give Docker a moment to come up
sleep 3

# ------------------------------
# Test pull hello-world
# ------------------------------
info "Testing Docker with 'docker pull hello-world'..."
if docker pull hello-world; then
    info "${GREEN}Mirror configuration is working!${NC}"
    docker run --rm hello-world
else
    error "Docker pull failed. Please check your network or mirror configuration."
fi

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN} CN Docker mirror setup complete!${NC}"
echo -e "${GREEN}============================================${NC}"
