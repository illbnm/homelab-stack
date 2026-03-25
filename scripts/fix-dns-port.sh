#!/bin/bash
# fix-dns-port.sh - Fix systemd-resolved DNS port 53 conflict
# Usage:
#   ./fix-dns-port.sh --check    Check if there's a conflict
#   ./fix-dns-port.sh --apply    Apply the fix (disable systemd-resolved)
#   ./fix-dns-port.sh --restore Restore systemd-resolved

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

check_conflict() {
    echo -e "${BLUE}[CHECK]${NC} Checking DNS port 53 conflicts..."

    # Check if systemd-resolved is running
    if systemctl is-active --quiet systemd-resolved; then
        echo -e "  ${YELLOW}systemd-resolved is ACTIVE${NC}"

        # Check if port 53 is in use by systemd-resolved
        if ss -tulpn | grep ':53' | grep -q systemd-resolve; then
            echo -e "  ${RED}Port 53 is bound by systemd-resolved${NC}"
            echo -e "  ${YELLOW}This will conflict with AdGuard Home${NC}"
            echo ""
            echo "To fix, run: $0 --apply"
            return 1
        else
            echo -e "  ${GREEN}Port 53 is not bound by systemd-resolved${NC}"
        fi
    else
        echo -e "  ${GREEN}systemd-resolved is NOT active${NC}"
    fi

    # Check if any other service is using port 53
    if ss -tulpn | grep ':53' | grep -qv systemd; then
        echo -e "  ${YELLOW}Port 53 is in use by another service:${NC}"
        ss -tulpn | grep ':53'
        return 1
    else
        echo -e "  ${GREEN}Port 53 is free${NC}"
    fi

    return 0
}

apply_fix() {
    echo -e "${BLUE}[APPLY]${NC} Applying DNS fix..."

    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}This script must be run as root${NC}"
        echo "Try: sudo $0 --apply"
        exit 1
    fi

    echo -e "${YELLOW}Warning: This will modify systemd-resolved configuration${NC}"
    read -p "Continue? (y/N): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "Cancelled"
        exit 0
    fi

    # Backup current resolve.conf
    if [ ! -f /etc/resolv.conf.bak ]; then
        echo "Backing up /etc/resolv.conf to /etc/resolv.conf.bak"
        cp /etc/resolv.conf /etc/resolv.conf.bak
    fi

    # Create new resolve.conf with cloudflare/google DNS
    echo "Creating new /etc/resolv.conf..."
    cat > /etc/resolv.conf << 'EOF'
# This file is managed by fix-dns-port.sh
# Manual changes will be lost after reboot
nameserver 1.1.1.1
nameserver 8.8.8.8
nameserver 9.9.9.9
EOF

    # Disable systemd-resolved
    echo "Disabling systemd-resolved..."
    systemctl stop systemd-resolved 2>/dev/null || true
    systemctl disable systemd-resolved 2>/dev/null || true

    # Remove systemd-resolved from docker network (if applicable)
    mkdir -p /etc/systemd/system/systemd-resolved.service.d
    cat > /etc/systemd/system/systemd-resolved.service.d/override.conf << 'EOF'
[Service]
ExecStart=
ExecStart=/lib/systemd/systemd-resolved --DNS=1.1.1.1 --FallBackDNS=8.8.8.8
EOF

    echo ""
    echo -e "${GREEN}DNS fix applied!${NC}"
    echo ""
    echo "Port 53 should now be free for AdGuard Home"
    echo ""
    echo "To verify, run: $0 --check"
}

restore() {
    echo -e "${BLUE}[RESTORE]${NC} Restoring systemd-resolved..."

    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}This script must be run as root${NC}"
        echo "Try: sudo $0 --restore"
        exit 1
    fi

    # Restore resolv.conf
    if [ -f /etc/resolv.conf.bak ]; then
        echo "Restoring /etc/resolv.conf..."
        cp /etc/resolv.conf.bak /etc/resolv.conf
    fi

    # Re-enable systemd-resolved
    echo "Re-enabling systemd-resolved..."
    systemctl enable systemd-resolved 2>/dev/null || true
    systemctl start systemd-resolved 2>/dev/null || true

    # Remove override
    rm -f /etc/systemd/system/systemd-resolved.service.d/override.conf

    echo ""
    echo -e "${GREEN}systemd-resolved restored!${NC}"
}

# Main
case "$1" in
    --check)
        check_conflict
        ;;
    --apply)
        apply_fix
        ;;
    --restore)
        restore
        ;;
    -h|--help)
        echo "Usage: $0 [--check|--apply|--restore]"
        echo ""
        echo "Options:"
        echo "  --check    Check for DNS port conflicts"
        echo "  --apply    Apply fix (disable systemd-resolved)"
        echo "  --restore  Restore systemd-resolved"
        echo ""
        echo "This script fixes port 53 conflicts between systemd-resolved and AdGuard Home."
        exit 0
        ;;
    *)
        echo "Usage: $0 [--check|--apply|--restore]"
        exit 1
        ;;
esac
