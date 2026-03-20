#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Docker CN Mirror Setup
# Interactive script to configure Docker registry mirrors for CN network
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Colors
# -----------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------
log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()  { echo; echo -e "${BOLD}${CYAN}==> $*${NC}"; }
log_ask()   { printf '%s' "${BOLD}${YELLOW}[?]${NC} $* "; }

# -----------------------------------------------------------------------------
# Mirror sources (primary + backup)
# -----------------------------------------------------------------------------
CN_MIRRORS=(
    "https://docker.m.daocloud.io"
    "https://mirror.gcr.io"
    "https://docker.mirrors.ustc.edu.cn"
    "https://hub-mirror.c.163.com"
    "https://mirror.baidubce.com"
)

DAEMON_JSON="/etc/docker/daemon.json"
BACKUP_SUFFIX=".bak.$(date +%Y%m%d%H%M%S)"

# -----------------------------------------------------------------------------
# Check if running as root
# -----------------------------------------------------------------------------
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# -----------------------------------------------------------------------------
# Ask user if in China
# -----------------------------------------------------------------------------
ask_cn_mode() {
    local answer
    log_step "Network Environment Detection"
    echo "This script configures Docker to use CN registry mirrors."
    echo "This is recommended if you're in mainland China."
    echo
    log_ask "Are you in mainland China? (y/n) [n]:"
    read -r answer
    case "$answer" in
        y|Y|yes|YES)
            return 0
            ;;
        *)
            log_info "Skipping CN mirror setup."
            exit 0
            ;;
    esac
}

# -----------------------------------------------------------------------------
# Backup existing daemon.json
# -----------------------------------------------------------------------------
backup_daemon_json() {
    if [[ -f "$DAEMON_JSON" ]]; then
        cp "$DAEMON_JSON" "${DAEMON_JSON}${BACKUP_SUFFIX}"
        log_info "Backed up existing daemon.json to ${DAEMON_JSON}${BACKUP_SUFFIX}"
    fi
}

# -----------------------------------------------------------------------------
# Generate daemon.json with mirrors
# -----------------------------------------------------------------------------
generate_daemon_json() {
    local mirrors_json
    mirrors_json=$(printf '%s\n' "${CN_MIRRORS[@]}" | jq -R . | jq -s .)
    
    local existing_config="{}"
    if [[ -f "$DAEMON_JSON" ]]; then
        existing_config=$(cat "$DAEMON_JSON")
    fi
    
    # Merge with existing config
    echo "$existing_config" | jq --argjson mirrors "$mirrors_json" '. + {registry-mirrors: $mirrors}' > "$DAEMON_JSON"
    
    log_info "Generated daemon.json with CN mirrors"
}

# -----------------------------------------------------------------------------
# Restart Docker daemon
# -----------------------------------------------------------------------------
restart_docker() {
    log_step "Restarting Docker daemon"
    
    if command -v systemctl &>/dev/null; then
        systemctl restart docker
        log_info "Docker restarted via systemctl"
    elif command -v service &>/dev/null; then
        service docker restart
        log_info "Docker restarted via service"
    else
        log_warn "Could not restart Docker automatically. Please restart Docker manually."
        return 1
    fi
    
    sleep 3
}

# -----------------------------------------------------------------------------
# Verify mirror configuration
# -----------------------------------------------------------------------------
verify_mirrors() {
    log_step "Verifying mirror configuration"
    
    # Check daemon.json
    if [[ -f "$DAEMON_JSON" ]]; then
        log_info "daemon.json contents:"
        cat "$DAEMON_JSON" | jq .
    else
        log_error "daemon.json not found"
        return 1
    fi
    
    # Test pull
    log_info "Testing docker pull with CN mirrors..."
    if docker pull hello-world:latest 2>&1 | grep -q "Pull complete\|Downloaded newer image"; then
        log_info "✓ Docker pull test successful!"
        return 0
    else
        log_warn "Docker pull test may have issues. Check the output above."
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    check_root
    ask_cn_mode
    
    log_step "Configuring Docker CN mirrors"
    
    # Check for jq
    if ! command -v jq &>/dev/null; then
        log_warn "jq not found, installing..."
        apt-get update && apt-get install -y jq || yum install -y jq
    fi
    
    backup_daemon_json
    generate_daemon_json
    restart_docker
    verify_mirrors
    
    log_step "Done!"
    log_info "Docker is now configured with CN registry mirrors."
    log_info "If you experience issues, you can restore the backup:"
    log_info "  sudo cp ${DAEMON_JSON}${BACKUP_SUFFIX} ${DAEMON_JSON}"
    log_info "  sudo systemctl restart docker"
}

main "$@"
