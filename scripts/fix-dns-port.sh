#!/bin/bash
# =============================================================================
# fix-dns-port.sh - Fix DNS port 53 conflict with systemd-resolved
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_dns_port() {
    echo "Checking if port 53 is in use..."
    if command -v lsof &> /dev/null; then
        lsof -i :53 || true
    elif command -v ss &> /dev/null; then
        ss -tulpn | grep :53 || true
    fi
    
    # Check systemd-resolved
    if systemctl is-active --quiet systemd-resolved; then
        echo -e "${YELLOW}systemd-resolved is active${NC}"
        systemd-resolve --status | grep -A2 "DNS Servers" || true
    fi
}

apply_fix() {
    echo -e "${YELLOW}Applying fix to disable systemd-resolved on port 53...${NC}"
    
    # Stop systemd-resolved
    sudo systemctl disable --now systemd-resolved || true
    
    # Backup and replace resolv.conf
    if [ -f /etc/resolv.conf ]; then
        sudo cp /etc/resolv.conf /etc/resolv.conf.backup
    fi
    
    # Create new resolv.conf with public DNS
    echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
    echo "nameserver 1.1.1.1" | sudo tee -a /etc/resolv.conf
    
    echo -e "${GREEN}Fix applied!${NC}"
    echo "Port 53 should now be available for AdGuard Home."
}

restore() {
    echo -e "${YELLOW}Restoring original DNS configuration...${NC}"
    
    if [ -f /etc/resolv.conf.backup ]; then
        sudo cp /etc/resolv.conf.backup /etc/resolv.conf
    fi
    
    sudo systemctl enable --now systemd-resolved || true
    
    echo -e "${GREEN}DNS configuration restored!${NC}"
}

case "${1:-}" in
    --check|-c)
        check_dns_port
        ;;
    --apply|-a)
        apply_fix
        ;;
    --restore|-r)
        restore
        ;;
    --help|-h|*)
        echo "Usage: $0 [--check|--apply|--restore]"
        echo ""
        echo "Options:"
        echo "  --check, -c    Check DNS port usage"
        echo "  --apply, -a    Apply fix (disable systemd-resolved)"
        echo "  --restore, -r  Restore original DNS config"
        echo "  --help, -h     Show this help message"
        ;;
esac
