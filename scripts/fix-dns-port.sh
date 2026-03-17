#!/bin/bash
#
# fix-dns-port.sh - Fix systemd-resolved DNS port 53 conflict
#
# Usage:
#   ./fix-dns-port.sh --check    # Check if port 53 is in use
#   ./fix-dns-port.sh --apply    # Disable systemd-resolved port 53
#   ./fix-dns-port.sh --restore  # Restore systemd-resolved
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

check_port() {
    echo -e "${YELLOW}Checking port 53 usage...${NC}"
    
    if command -v ss &> /dev/null; then
        echo "Port 53 (UDP) usage:"
        ss -ulnp | grep :53 || echo "  Port 53 is free"
        
        echo "Port 53 (TCP) usage:"
        ss -tlnp | grep :53 || echo "  Port 53 is free"
    elif command -v netstat &> /dev/null; then
        netstat -ulnp | grep :53 || echo "Port 53 is free"
    fi
    
    # Check systemd-resolved
    if systemctl is-active --quiet systemd-resolved; then
        echo -e "${YELLOW}systemd-resolved is ACTIVE${NC}"
    else
        echo -e "${GREEN}systemd-resolved is INACTIVE${NC}"
    fi
}

apply_fix() {
    echo -e "${YELLOW}Applying fix for port 53...${NC}"
    
    # Check if we have systemd-resolved
    if ! command -v systemctl &> /dev/null; then
        echo -e "${RED}systemctl not found. This script requires systemd.${NC}"
        exit 1
    fi
    
    # Stop systemd-resolved
    echo "Stopping systemd-resolved..."
    sudo systemctl stop systemd-resolved
    
    # Disable systemd-resolved (prevent auto-start)
    echo "Disabling systemd-resolved..."
    sudo systemctl disable systemd-resolved 2>/dev/null || true
    
    # Backup and modify resolve.conf
    if [ -f /etc/resolv.conf ]; then
        echo "Backing up /etc/resolv.conf..."
        sudo cp /etc/resolv.conf /etc/resolv.conf.backup
        
        # Add Google DNS as fallback
        echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf > /dev/null
        echo "nameserver 8.8.4.4" | sudo tee -a /etc/resolv.conf > /dev/null
    fi
    
    echo -e "${GREEN}Fix applied successfully!${NC}"
    echo "Port 53 should now be available for AdGuard Home."
}

restore() {
    echo -e "${YELLOW}Restoring systemd-resolved...${NC}"
    
    if ! command -v systemctl &> /dev/null; then
        echo -e "${RED}systemctl not found.${NC}"
        exit 1
    fi
    
    # Re-enable systemd-resolved
    echo "Enabling systemd-resolved..."
    sudo systemctl enable systemd-resolved 2>/dev/null || true
    
    # Start systemd-resolved
    echo "Starting systemd-resolved..."
    sudo systemctl start systemd-resolved
    
    # Restore resolv.conf
    if [ -f /etc/resolv.conf.backup ]; then
        echo "Restoring /etc/resolv.conf..."
        sudo cp /etc/resolv.conf.backup /etc/resolv.conf
    fi
    
    echo -e "${GREEN}Restored successfully!${NC}"
}

# Main
case "${1}" in
    --check)
        check_port
        ;;
    --apply)
        apply_fix
        ;;
    --restore)
        restore
        ;;
    *)
        echo "Usage: $0 {--check|--apply|--restore}"
        echo ""
        echo "Options:"
        echo "  --check    Check if port 53 is in use"
        echo "  --apply    Disable systemd-resolved and free port 53"
        echo "  --restore  Restore systemd-resolved"
        exit 1
        ;;
esac
