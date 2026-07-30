#!/usr/bin/env bash
set -euo pipefail

# fix-dns-port.sh — Handle systemd-resolved port 53 conflict
# Usage:
#   ./fix-dns-port.sh --check    Check if port 53 is occupied
#   ./fix-dns-port.sh --apply    Disable systemd-resolved stub listener
#   ./fix-dns-port.sh --restore  Re-enable systemd-resolved stub listener

TEXT_RED='\033[0;31m'
TEXT_GREEN='\033[0;32m'
TEXT_YELLOW='\033[1;33m'
TEXT_RESET='\033[0m'

info()  { echo -e "${TEXT_GREEN}[INFO]${TEXT_RESET} $*"; }
warn()  { echo -e "${TEXT_YELLOW}[WARN]${TEXT_RESET} $*"; }
error() { echo -e "${TEXT_RED}[ERROR]${TEXT_RESET} $*"; }

check_port_53() {
    local listener
    listener=$(ss -tulpn 2>/dev/null | grep ':53 ' || true)
    
    if [[ -z "$listener" ]]; then
        info "Port 53 is free."
        return 0
    fi
    
    if echo "$listener" | grep -q 'systemd-resolve'; then
        warn "Port 53 is occupied by systemd-resolved:"
        echo "$listener"
        return 1
    elif echo "$listener" | grep -q 'dnsmasq'; then
        warn "Port 53 is occupied by dnsmasq:"
        echo "$listener"
        return 2
    else
        warn "Port 53 is occupied by an unknown service:"
        echo "$listener"
        return 3
    fi
}

check_systemd_resolved() {
    if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

apply_fix() {
    info "Applying port 53 fix for systemd-resolved..."
    
    if ! check_systemd_resolved; then
        info "systemd-resolved is not running. Nothing to fix."
        return 0
    fi
    
    # Method 1: Disable systemd-resolved stub listener
    info "Disabling systemd-resolved stub listener..."
    
    # Backup original config
    if [[ -f /etc/systemd/resolved.conf ]]; then
        cp /etc/systemd/resolved.conf /etc/systemd/resolved.conf.bak 2>/dev/null || true
    fi
    
    # Set DNSStubListener=no
    if grep -q '^DNSStubListener=' /etc/systemd/resolved.conf 2>/dev/null; then
        sed -i 's/^DNSStubListener=.*/DNSStubListener=no/' /etc/systemd/resolved.conf
    elif grep -q '^#DNSStubListener=' /etc/systemd/resolved.conf 2>/dev/null; then
        sed -i 's/^#DNSStubListener=.*/DNSStubListener=no/' /etc/systemd/resolved.conf
    else
        echo 'DNSStubListener=no' >> /etc/systemd/resolved.conf
    fi
    
    info "DNSStubListener=no set in /etc/systemd/resolved.conf"
    
    # Restart systemd-resolved
    systemctl restart systemd-resolved 2>/dev/null || true
    info "systemd-resolved restarted"
    
    # Update /etc/resolv.conf to use a real DNS server
    info "Updating /etc/resolv.conf..."
    if [[ -L /etc/resolv.conf ]]; then
        rm /etc/resolv.conf
    fi
    cat > /etc/resolv.conf << 'EOF'
# Managed by homelab-stack fix-dns-port.sh
nameserver 1.1.1.1
nameserver 8.8.8.8
options edns0
EOF
    info "/etc/resolv.conf updated with Cloudflare + Google DNS"
    
    # Wait and verify
    sleep 2
    if check_port_53; then
        info "Port 53 is now free! AdGuard Home can bind."
    else
        error "Port 53 is still occupied. Try rebooting or check for other DNS services."
        error "Run: systemctl stop systemd-resolved && systemctl disable systemd-resolved"
        return 1
    fi
}

restore_fix() {
    info "Restoring systemd-resolved stub listener..."
    
    if [[ -f /etc/systemd/resolved.conf.bak ]]; then
        cp /etc/systemd/resolved.conf.bak /etc/systemd/resolved.conf
        info "Restored from backup."
    else
        if grep -q '^DNSStubListener=no' /etc/systemd/resolved.conf 2>/dev/null; then
            sed -i 's/^DNSStubListener=.*/DNSStubListener=yes/' /etc/systemd/resolved.conf
        fi
        info "Set DNSStubListener=yes."
    fi
    
    systemctl restart systemd-resolved 2>/dev/null || true
    
    # Restore resolv.conf symlink
    if [[ ! -L /etc/resolv.conf ]]; then
        ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
    fi
    
    info "systemd-resolved restored. Reboot recommended."
}

# ── Main ────────────────────────────────────────────────────────
case "${1:-}" in
    --check)
        check_port_53
        ;;
    --apply)
        apply_fix
        ;;
    --restore)
        restore_fix
        ;;
    *)
        echo "Usage: $0 {--check|--apply|--restore}"
        echo ""
        echo "  --check    Check if port 53 is occupied"
        echo "  --apply    Disable systemd-resolved stub listener on port 53"
        echo "  --restore  Re-enable systemd-resolved stub listener"
        exit 1
        ;;
esac