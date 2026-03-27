#!/usr/bin/env bash
# =============================================================================
# setup-cn-mirrors.sh — Setup Docker mirror accelerators for China Mainland
# Interactive script that detects CN network and configures Docker mirrors.
# Run as: sudo ./setup-cn-mirrors.sh
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

log_info()  { echo -e "${GREEN}[cn-mirror]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[cn-mirror]${NC} $*" >&2; }
log_error() { echo -e "${RED}[cn-mirror]${NC} $*" >&2; }
log_step()  { echo -e "${BLUE}[cn-mirror]${NC} [STEP] $*"; }

DOCKER_DAEMON="/etc/docker/daemon.json"
BACKUP_SUFFIX=".backup.$(date +%Y%m%d%H%M%S)"

# Mirror options (ordered by reliability)
MIRRORS=(
    "https://docker.m.daocloud.io"
    "https://mirror.baidubce.com"
    "https://hub-mirror.c.163.com"
    "https://docker.mirrors.ustc.edu.cn"
)

detect_cn_network() {
    log_step "Detecting network environment..."
    if curl -s --max-time 5 https://www.google.com -o /dev/null 2>/dev/null; then
        log_info "International network detected — no mirror needed"
        return 1
    fi
    if curl -s --max-time 5 https://www.baidu.com -o /dev/null 2>/dev/null; then
        log_info "China Mainland network detected"
        return 0
    fi
    log_warn "Could not detect network — assuming non-CN"
    return 1
}

select_mirror() {
    echo ""
    echo "Select mirror source (or 't' to test, 'a' for auto-best):"
    echo ""
    echo "  1) DaoCloud (docker.m.daocloud.io) — RECOMMENDED"
    echo "  2) Baidu Cloud (mirror.baidubce.com)"
    echo "  3) NetEase (hub-mirror.c.163.com)"
    echo "  4) USTC (docker.mirrors.ustc.edu.cn)"
    echo ""
    read -p "Choice [1]: " choice
    choice="${choice:-1}"
    case "$choice" in
        1|"a") echo "https://docker.m.daocloud.io" ;;
        2) echo "https://mirror.baidubce.com" ;;
        3) echo "https://hub-mirror.c.163.com" ;;
        4) echo "https://docker.mirrors.ustc.edu.cn" ;;
        *) echo "https://docker.m.daocloud.io" ;;
    esac
}

test_mirror() {
    local mirror="$1"
    log_step "Testing mirror: $mirror"
    if curl -sf --max-time 10 "https://$mirror" > /dev/null 2>&1; then
        log_info "Mirror $mirror is accessible"
        return 0
    else
        log_warn "Mirror $mirror is not accessible"
        return 1
    fi
}

write_daemon_json() {
    local registry_mirrors="$1"
    log_step "Writing $DOCKER_DAEMON ..."

    # Backup existing
    if [ -f "$DOCKER_DAEMON" ]; then
        cp "$DOCKER_DAEMON" "${DOCKER_DAEMON}${BACKUP_SUFFIX}"
        log_info "Backed up existing $DOCKER_DAEMON"
    fi

    cat > "$DOCKER_DAEMON" << EOF
{
  "registry-mirrors": ["$registry_mirrors"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  }
}
EOF
    chmod 644 "$DOCKER_DAEMON"
    log_info "Written $DOCKER_DAEMON"
}

restart_docker() {
    log_step "Restarting Docker daemon ..."
    if systemctl is-active --quiet docker 2>/dev/null; then
        sudo systemctl restart docker
        sleep 3
        if systemctl is-active --quiet docker; then
            log_info "Docker restarted successfully"
        else
            log_error "Docker restart failed"
            return 1
        fi
    elif service docker restart 2>/dev/null; then
        sleep 3
        log_info "Docker restarted successfully"
    else
        log_error "Could not restart Docker — please restart manually"
        return 1
    fi
}

verify_setup() {
    log_step "Verifying setup ..."
    if docker info 2>/dev/null | grep -q "Registry Mirrors"; then
        log_info "Docker is using registry mirrors"
        docker info 2>/dev/null | grep -A5 "Registry Mirrors"
    else
        log_warn "Could not verify registry mirrors in docker info"
    fi

    # Test pull
    log_step "Testing docker pull ..."
    if docker pull hello-world:latest > /dev/null 2>&1; then
        log_info "docker pull hello-world succeeded"
        docker run --rm hello-world:latest > /dev/null 2>&1
        log_info "hello-world ran successfully"
        return 0
    else
        log_error "docker pull failed — mirror may not be working"
        return 1
    fi
}

show_help() {
    cat << EOF
Usage: sudo ./setup-cn-mirrors.sh [--auto]

Setup Docker registry mirrors for China Mainland networks.

Options:
  --auto       Run non-interactively with recommended mirror
  --help       Show this help

Examples:
  sudo ./setup-cn-mirrors.sh          # Interactive mode
  sudo ./setup-cn-mirrors.sh --auto  # Auto-select recommended mirror

Requires: sudo/root privileges
EOF
}

# Check root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root (sudo)"
    exit 1
fi

AUTO_MODE=false
[[ "${1:-}" == "--auto" ]] && AUTO_MODE=true

if ! detect_cn_network; then
    log_info "No changes made — you can still run with --auto to force setup"
    exit 0
fi

if [ -f /etc/docker/daemon.json ]; then
    if grep -q "registry-mirrors" /etc/docker/daemon.json 2>/dev/null; then
        existing=$(grep "registry-mirrors" /etc/docker/daemon.json | head -1)
        log_info "Mirror already configured: $existing"
        read -p "Overwrite? [y/N]: " confirm
        [[ "${confirm:-N}" != "y" && "${confirm:-N}" != "Y" ]] && exit 0
    fi
fi

if $AUTO_MODE; then
    MIRROR="https://docker.m.daocloud.io"
    test_mirror "$MIRROR" || log_warn "Auto-selected mirror may not be reachable"
else
    echo ""
    echo "=== Docker Mirror Setup for China Mainland ==="
    echo ""
    MIRROR=$(select_mirror)
    if [[ "$MIRROR" == "t" ]]; then
        for m in "${MIRRORS[@]}"; do
            test_mirror "$m" || true
        done
        MIRROR=$(select_mirror)
    fi
fi

write_daemon_json "$MIRROR"
restart_docker || { log_warn "Please restart Docker manually"; exit 1; }
verify_setup || { log_warn "Verification failed"; exit 1; }

echo ""
log_info "CN mirror setup complete!"
log_info "Mirror: $MIRROR"
log_info "Backup: ${DOCKER_DAEMON}${BACKUP_SUFFIX}"
