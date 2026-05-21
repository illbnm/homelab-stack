#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — CN Network Robustness Setup
# Configures Docker mirrors, npm registries, and pip mirrors for China users
# Usage: ./scripts/setup-cn-mirrors.sh [--docker] [--npm] [--pip] [--all]
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$SCRIPT_DIR/.."

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[cn-setup]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[cn-setup]${NC} $*"; }
log_error() { echo -e "${RED}[cn-setup]${NC} $*" >&2; }

SETUP_DOCKER=false
SETUP_NPM=false
SETUP_PIP=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --docker) SETUP_DOCKER=true; shift ;;
        --npm)    SETUP_NPM=true; shift ;;
        --pip)    SETUP_PIP=true; shift ;;
        --all)    SETUP_DOCKER=true; SETUP_NPM=true; SETUP_PIP=true; shift ;;
        *)        log_error "Unknown option: $1"; exit 1 ;;
    esac
done

# If no flags specified, do everything
if [[ "$SETUP_DOCKER" == "false" && "$SETUP_NPM" == "false" && "$SETUP_PIP" == "false" ]]; then
    SETUP_DOCKER=true
    SETUP_NPM=true
    SETUP_PIP=true
fi

# =============================================================================
# Docker mirror configuration
# =============================================================================
setup_docker_mirror() {
    echo ""
    echo "=== Docker Mirror Configuration ==="

    if ! command -v docker &>/dev/null; then
        log_warn "Docker not found, skipping"
        return
    fi

    # Check if Docker daemon config exists
    local daemon_json="/etc/docker/daemon.json"
    local mirror_url="https://docker.m.daocloud.io"

    if [[ -f "$daemon_json" ]]; then
        if grep -q "$mirror_url" "$daemon_json" 2>/dev/null; then
            log_info "Docker mirror already configured: $mirror_url"
            return
        fi
    fi

    log_info "Configuring Docker mirror: $mirror_url"

    if [[ ! -f "$daemon_json" ]]; then
        echo "{\"registry-mirrors\": [\"$mirror_url\"]}" | sudo tee "$daemon_json" >/dev/null
    else
        # Add mirror to existing config
        local tmp
        tmp=$(mktemp)
        python3 -c "
import json, sys
with open('$daemon_json') as f:
    config = json.load(f)
mirrors = config.get('registry-mirrors', [])
if '$mirror_url' not in mirrors:
    mirrors.insert(0, '$mirror_url')
config['registry-mirrors'] = mirrors
with open('$tmp', 'w') as f:
    json.dump(config, f, indent=2)
" 2>/dev/null && sudo cp "$tmp" "$daemon_json" && rm -f "$tmp"
    fi

    sudo systemctl restart docker 2>/dev/null || true
    log_info "Docker mirror configured. Restart docker to apply."
}

# =============================================================================
# npm mirror configuration
# =============================================================================
setup_npm_mirror() {
    echo ""
    echo "=== NPM Mirror Configuration ==="

    local npmrc="$HOME/.npmrc"
    local mirror="https://registry.npmmirror.com"

    if [[ -f "$npmrc" ]] && grep -q "$mirror" "$npmrc" 2>/dev/null; then
        log_info "npm mirror already configured: $mirror"
        return
    fi

    log_info "Configuring npm mirror: $mirror"
    npm config set registry "$mirror" 2>/dev/null || true

    log_info "npm mirror configured"
}

# =============================================================================
# pip mirror configuration
# =============================================================================
setup_pip_mirror() {
    echo ""
    echo "=== pip Mirror Configuration ==="

    local pip_conf="$HOME/pip/pip.conf"
    local mirror="https://mirrors.aliyun.com/pypi/simple/"

    if [[ -f "$pip_conf" ]] && grep -q "$mirror" "$pip_conf" 2>/dev/null; then
        log_info "pip mirror already configured: $mirror"
        return
    fi

    log_info "Configuring pip mirror: $mirror"
    mkdir -p "$HOME/pip"
    cat > "$pip_conf" << EOF
[global]
index-url = $mirror
trusted-host = mirrors.aliyun.com
EOF

    log_info "pip mirror configured"
}

# =============================================================================
# Connectivity test
# =============================================================================
test_connectivity() {
    echo ""
    echo "=== Network Connectivity Test ==="

    local sites=(
        "docker.io:443:Docker Hub"
        "ghcr.io:443:GitHub Container Registry"
        "docker.m.daocloud.io:443:DaoCloud Mirror"
        "registry.npmmirror.com:443:npm Mirror"
        "mirrors.aliyun.com:443:Aliyun Mirror"
    )

    for site in "${sites[@]}"; do
        IFS=':' read -r host port name <<< "$site"
        if nc -z -w3 "$host" "$port" 2>/dev/null; then
            log_info "$name ($host) reachable"
        else
            log_warn "$name ($host) unreachable — mirror recommended"
        fi
    done
}

# =============================================================================
# Run
# =============================================================================
echo "============================================"
echo "  HomeLab CN Network Robustness Setup"
echo "============================================"

test_connectivity

if [[ "$SETUP_DOCKER" == "true" ]]; then setup_docker_mirror; fi
if [[ "$SETUP_NPM" == "true" ]]; then setup_npm_mirror; fi
if [[ "$SETUP_PIP" == "true" ]]; then setup_pip_mirror; fi

echo ""
echo "============================================"
echo "  Setup complete"
echo ""
echo "  To pull images via mirrors:"
echo "    ./scripts/cn-pull.sh"
echo ""
echo "  To configure .env for CN mode:"
echo "    echo 'CN_MODE=true' >> .env"
echo "============================================"
