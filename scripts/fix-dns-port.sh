#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# fix-dns-port.sh — Resolve port 53 conflict with systemd-resolved
#
# AdGuard Home (and any local DNS server) needs port 53.
# On Ubuntu/Debian systems, systemd-resolved binds to 127.0.0.53:53 by default.
# This script disables the stub listener so port 53 is available.
#
# Usage:
#   sudo ./scripts/fix-dns-port.sh --check    # check current state
#   sudo ./scripts/fix-dns-port.sh --apply    # apply the fix
#   sudo ./scripts/fix-dns-port.sh --restore  # revert to default
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

RESOLVED_CONF="/etc/systemd/resolved.conf"
RESOLVED_CONF_D="/etc/systemd/resolved.conf.d/no-stub-listener.conf"
BACKUP_SUFFIX=".bak.$(date +%Y%m%d%H%M%S)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root. Use: sudo $0 $*"
        exit 1
    fi
}

check_state() {
    echo ""
    info "=== Checking DNS port 53 status ==="
    echo ""

    # Check what's listening on port 53
    if command -v ss &>/dev/null; then
        local listeners
        listeners=$(ss -tlunp 'sport = :53' 2>/dev/null || true)
        if [[ -n "$listeners" ]]; then
            warn "Port 53 is currently bound by:"
            echo "$listeners"
        else
            success "Port 53 is free — no conflicts detected"
        fi
    fi

    echo ""

    # Check systemd-resolved status
    if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
        info "systemd-resolved: ACTIVE"

        # Check stub listener status
        local stub
        stub=$(grep -i "DNSStubListener" "$RESOLVED_CONF" 2>/dev/null || echo "not set")
        info "DNSStubListener in $RESOLVED_CONF: $stub"

        if [[ -f "$RESOLVED_CONF_D" ]]; then
            info "Override config exists: $RESOLVED_CONF_D"
            cat "$RESOLVED_CONF_D"
        else
            warn "No override config — stub listener is likely active"
        fi
    else
        info "systemd-resolved: INACTIVE (no conflict expected)"
    fi

    echo ""

    # Check resolv.conf symlink
    info "Current /etc/resolv.conf:"
    ls -la /etc/resolv.conf
    echo ""
    info "Contents:"
    cat /etc/resolv.conf
    echo ""
}

apply_fix() {
    check_root

    echo ""
    info "=== Disabling systemd-resolved stub listener ==="
    echo ""

    if ! systemctl is-active --quiet systemd-resolved 2>/dev/null; then
        success "systemd-resolved is not running — no fix needed"
        return 0
    fi

    # Check if port 53 is already free
    if ! ss -tlunp 'sport = :53' 2>/dev/null | grep -q ':53'; then
        success "Port 53 is already free — nothing to do"
        return 0
    fi

    # Backup existing config
    if [[ -f "$RESOLVED_CONF" ]]; then
        cp "$RESOLVED_CONF" "${RESOLVED_CONF}${BACKUP_SUFFIX}"
        info "Backed up: ${RESOLVED_CONF}${BACKUP_SUFFIX}"
    fi

    # Create drop-in override (preferred over editing main config)
    mkdir -p "$(dirname "$RESOLVED_CONF_D")"
    cat > "$RESOLVED_CONF_D" << 'EOF'
# Disable stub listener to free port 53 for AdGuard Home / local DNS
[Resolve]
DNSStubListener=no
DNS=1.1.1.1 8.8.8.8
FallbackDNS=9.9.9.9
EOF

    info "Created override: $RESOLVED_CONF_D"

    # Fix resolv.conf — point to real upstream instead of 127.0.0.53
    if [[ -L /etc/resolv.conf ]]; then
        local link_target
        link_target=$(readlink /etc/resolv.conf)
        if [[ "$link_target" == *"stub-resolv.conf"* ]]; then
            ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
            info "Updated /etc/resolv.conf symlink → /run/systemd/resolve/resolv.conf"
        fi
    fi

    # Restart systemd-resolved
    systemctl restart systemd-resolved
    sleep 2

    # Verify
    if ss -tlunp 'sport = :53' 2>/dev/null | grep -q ':53'; then
        error "Port 53 is still occupied after fix. Check: ss -tlunp 'sport = :53'"
        exit 1
    else
        success "Port 53 is now free!"
        success "You can now start AdGuard Home: docker compose -f stacks/network/docker-compose.yml up -d adguardhome"
    fi
    echo ""
}

restore() {
    check_root

    echo ""
    info "=== Restoring systemd-resolved default configuration ==="
    echo ""

    if [[ -f "$RESOLVED_CONF_D" ]]; then
        rm -f "$RESOLVED_CONF_D"
        info "Removed override: $RESOLVED_CONF_D"
    fi

    # Restore resolv.conf symlink
    if [[ -L /etc/resolv.conf ]]; then
        ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
        info "Restored /etc/resolv.conf → stub-resolv.conf"
    fi

    systemctl restart systemd-resolved
    sleep 2
    success "systemd-resolved restored to defaults"
    warn "Port 53 is now owned by systemd-resolved again. Stop AdGuard Home before using local DNS."
    echo ""
}

usage() {
    cat << EOF
Usage: sudo $0 [OPTION]

Options:
  --check    Check current state of port 53 and systemd-resolved
  --apply    Disable systemd-resolved stub listener (free port 53)
  --restore  Restore systemd-resolved to default (re-enable stub listener)
  --help     Show this help

Examples:
  sudo ./scripts/fix-dns-port.sh --check
  sudo ./scripts/fix-dns-port.sh --apply
  sudo ./scripts/fix-dns-port.sh --restore
EOF
}

case "${1:---help}" in
    --check)   check_state ;;
    --apply)   apply_fix ;;
    --restore) restore ;;
    --help|-h) usage ;;
    *)
        error "Unknown option: $1"
        usage
        exit 1
        ;;
esac
