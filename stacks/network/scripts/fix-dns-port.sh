#!/usr/bin/env bash
#
# fix-dns-port.sh — Resolve port 53 conflict with systemd-resolved
#
# Usage:
#   ./fix-dns-port.sh --check    Check if port 53 is occupied
#   ./fix-dns-port.sh --apply    Disable systemd-resolved stub listener
#   ./fix-dns-port.sh --restore  Restore original systemd-resolved config
#
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

RESOLVED_CONF="/etc/systemd/resolved.conf"
BACKUP_CONF="/etc/systemd/resolved.conf.backup"

check_port() {
    echo "Checking port 53..."
    if ss -tlnp 2>/dev/null | grep -q ':53 '; then
        local proc
        proc=$(ss -tlnp 2>/dev/null | grep ':53 ' | head -1)
        echo -e "${RED}✗ Port 53 is in use:${NC}"
        echo "  $proc"

        if echo "$proc" | grep -q "systemd-resolve"; then
            echo -e "${YELLOW}→ systemd-resolved is occupying port 53${NC}"
            echo "  Run: $0 --apply"
        fi
        return 1
    else
        echo -e "${GREEN}✓ Port 53 is available${NC}"
        return 0
    fi
}

apply_fix() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Error: Must run as root (use sudo)${NC}"
        exit 1
    fi

    if [[ ! -f "$RESOLVED_CONF" ]]; then
        echo -e "${YELLOW}systemd-resolved config not found — may not be using systemd${NC}"
        exit 0
    fi

    # Backup original
    if [[ ! -f "$BACKUP_CONF" ]]; then
        cp "$RESOLVED_CONF" "$BACKUP_CONF"
        echo -e "${GREEN}✓ Backed up $RESOLVED_CONF → $BACKUP_CONF${NC}"
    fi

    # Disable stub listener
    if grep -q "^DNSStubListener=" "$RESOLVED_CONF"; then
        sed -i 's/^DNSStubListener=.*/DNSStubListener=no/' "$RESOLVED_CONF"
    elif grep -q "^#DNSStubListener=" "$RESOLVED_CONF"; then
        sed -i 's/^#DNSStubListener=.*/DNSStubListener=no/' "$RESOLVED_CONF"
    else
        echo "DNSStubListener=no" >> "$RESOLVED_CONF"
    fi

    # Point DNS to localhost (AdGuard will handle it)
    if grep -q "^DNS=" "$RESOLVED_CONF"; then
        sed -i 's/^DNS=.*/DNS=127.0.0.1/' "$RESOLVED_CONF"
    elif grep -q "^#DNS=" "$RESOLVED_CONF"; then
        sed -i 's/^#DNS=.*/DNS=127.0.0.1/' "$RESOLVED_CONF"
    else
        echo "DNS=127.0.0.1" >> "$RESOLVED_CONF"
    fi

    # Update resolv.conf symlink
    ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf

    # Restart systemd-resolved
    systemctl restart systemd-resolved
    echo -e "${GREEN}✓ systemd-resolved stub listener disabled${NC}"
    echo -e "${GREEN}✓ DNS pointed to 127.0.0.1 (AdGuard Home)${NC}"

    # Verify
    sleep 2
    check_port
}

restore() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Error: Must run as root (use sudo)${NC}"
        exit 1
    fi

    if [[ ! -f "$BACKUP_CONF" ]]; then
        echo -e "${RED}No backup found at $BACKUP_CONF${NC}"
        exit 1
    fi

    cp "$BACKUP_CONF" "$RESOLVED_CONF"
    ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
    systemctl restart systemd-resolved
    echo -e "${GREEN}✓ Restored original systemd-resolved configuration${NC}"
}

case "${1:-}" in
    --check)   check_port ;;
    --apply)   apply_fix ;;
    --restore) restore ;;
    *)
        echo "Usage: $0 {--check|--apply|--restore}"
        echo ""
        echo "  --check    Check if port 53 is occupied"
        echo "  --apply    Disable systemd-resolved stub listener"
        echo "  --restore  Restore original configuration"
        exit 1
        ;;
esac
