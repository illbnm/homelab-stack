#!/bin/bash
# setup-cn-mirrors.sh - Configure Docker mirror acceleration for China
# Usage: ./scripts/setup-cn-mirrors.sh [--dry-run]
#
# This script configures Docker mirror registries to speed up image pulls
# in mainland China where Docker Hub access is slow or blocked.
#
# Supports:
#   - Docker Hub (hub.docker.com)
#   - gcr.io
#   - ghcr.io
#   - registry.k8s.io

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=false
VERBOSE=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--dry-run] [--verbose]"
            echo ""
            echo "Options:"
            echo "  --dry-run    Show what would be changed"
            echo "  --verbose    Show detailed output"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Mirror configurations
declare -A MIRRORS
MIRRORS=(
    ["docker.m.daocloud.io"]="Docker Hub (DaoCloud)"
    ["m.daocloud.io"]="gcr.io/ghcr.io (DaoCloud)"
)

# Main mirrors to configure
DOCKER_MIRRORS=(
    "docker.m.daocloud.io"
    "m.daocloud.io"
)

# Configure Docker daemon
configure_docker() {
    log "Configuring Docker mirror acceleration..."

    local daemon_json="/etc/docker/daemon.json"
    local backup_json="/etc/docker/daemon.json.backup.$(date +%Y%m%d_%H%M%S)"

    # Check if file exists
    if [ -f "$daemon_json" ]; then
        if [ "$DRY_RUN" = false ]; then
            info "Backing up existing daemon.json to $backup_json"
            cp "$daemon_json" "$backup_json"
        fi
    fi

    # Create daemon.json content
    local registry_mirrors=""
    for mirror in "${DOCKER_MIRRORS[@]}"; do
        if [ -n "$registry_mirrors" ]; then
            registry_mirrors="${registry_mirrors}, "
        fi
        registry_mirrors="${registry_mirrors}\"https://${mirror}\""
    done

    local daemon_content="{
  \"registry-mirrors\": [${registry_mirrors}],
  \"live-restore\": true,
  \"log-driver\": \"json-file\",
  \"log-opts\": {
    \"max-size\": \"10m\",
    \"max-file\": \"3\"
  }
}"

    if [ "$DRY_RUN" = true ]; then
        info "[DRY RUN] Would write to $daemon_json:"
        echo "$daemon_content"
        return 0
    fi

    # Write daemon.json
    log "Writing Docker daemon configuration..."
    echo "$daemon_content" | sudo tee "$daemon_json" > /dev/null

    # Restart Docker
    log "Restarting Docker daemon..."
    if command -v systemctl &>/dev/null; then
        sudo systemctl restart docker
    elif command -v service &>/dev/null; then
        sudo service docker restart
    else
        warn "Could not restart Docker automatically. Please restart manually."
    fi

    return 0
}

# Test Docker pull speed
test_docker_pull() {
    info "Testing Docker pull speed with hello-world..."

    if docker pull hello-world &>/dev/null; then
        log "Successfully pulled hello-world"
        return 0
    else
        error "Failed to pull hello-world"
        return 1
    fi
}

# Main execution
main() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║     Docker Mirror Setup for China                 ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    echo ""

    # Check if running as root
    if [ "$EUID" -ne 0 ] && [ "$DRY_RUN" = false ]; then
        warn "This script requires root privileges to modify /etc/docker/daemon.json"
        info "Run with: sudo $0"
        exit 1
    fi

    if [ "$DRY_RUN" = true ]; then
        warn "DRY RUN MODE - No changes will be made"
        echo ""
    fi

    # Show current Docker registry mirrors
    info "Current Docker daemon.json:"
    if [ -f /etc/docker/daemon.json ]; then
        cat /etc/docker/daemon.json
    else
        echo "  (no daemon.json found)"
    fi
    echo ""

    # Show what mirrors will be configured
    info "Mirrors to configure:"
    for mirror in "${DOCKER_MIRRORS[@]}"; do
        echo "  - https://${mirror} (${MIRRORS[$mirror]})"
    done
    echo ""

    # Configure Docker
    configure_docker

    # Test if not dry run
    if [ "$DRY_RUN" = false ]; then
        echo ""
        info "Testing Docker pull..."
        if test_docker_pull; then
            echo ""
            log "Docker mirror configuration complete!"
            log "All image pulls will now use mirror acceleration."
        else
            echo ""
            warn "Docker pull test failed. Please check your network and try again."
        fi
    fi

    echo ""
    info "For more speed improvements, also consider:"
    echo "  1. Edit docker-compose.yml files to use regional mirrors"
    echo "  2. Use scripts/localize-images.sh to replace gcr.io/ghcr.io images"
    echo ""
}

main "$@"
