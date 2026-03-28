#!/bin/bash
# =============================================================================
# fix-dns-port.sh — Fix systemd-resolved port 53 conflict for AdGuard Home
#
# Usage:
#   ./fix-dns-port.sh --check   Check if systemd-resolved is using port 53
#   ./fix-dns-port.sh --apply   Disable systemd-resolved (requires sudo + reboot)
#   ./fix-dns-port.sh --restore Re-enable systemd-resolved
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

RESOLVED_CONF="/etc/systemd/resolved.conf"
RESOLVED_SERVICE="systemd-resolved"

check_port_53() {
    echo "=== Checking port 53 usage ==="

    if command -v ss &>/dev/null; then
        echo "Processes listening on port 53:"
        ss -tulpn | grep :53 || echo "  (none found on port 53)"
    elif command -v netstat &>/dev/null; then
        echo "Processes listening on port 53:"
        netstat -tulpn | grep :53 || echo "  (none found on port 53)"
    fi

    echo ""
    echo "Checking systemd-resolved status:"
    if systemctl is-active --quiet "$RESOLVED_SERVICE" 2>/dev/null; then
        echo -e "  ${YELLOW}systemd-resolved is ACTIVE${NC}"

        # Check if resolved is using port 53
        if ss -tulpn | grep -q ":53.*systemd-resolved\|:53.*$RESOLVED_SERVICE"; then
            echo -e "  ${RED}systemd-resolved is using port 53 — AdGuard Home will fail to bind!${NC}"
        else
            echo -e "  ${GREEN}systemd-resolved is active but may not be binding port 53${NC}"
        fi
    else
        echo -e "  ${GREEN}systemd-resolved is NOT active — no conflict${NC}"
    fi

    echo ""
    if grep -q "^DNS=127.0.0.53" "$RESOLVED_CONF" 2>/dev/null; then
        echo -e "  ${YELLOW}DNS stub listener is active at 127.0.0.53${NC}"
    fi
}

apply_fix() {
    echo "=== Applying fix for systemd-resolved ==="

    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Error: --apply requires root (sudo)${NC}"
        echo "Run: sudo $0 --apply"
        exit 1
    fi

    echo "Backing up $RESOLVED_CONF to ${RESOLVED_CONF}.bak"
    cp "$RESOLVED_CONF" "${RESOLVED_CONF}.bak"

    echo "Disabling DNS stub listener..."
    # Comment out DNS= line to disable stub resolver
    sed -i 's/^DNS=127.0.0.53/#DNS=127.0.0.53/' "$RESOLVED_CONF"
    sed -i 's/^DNSStubListener=yes/#DNSStubListener=yes/' "$RESOLVED_CONF"
    sed -i 's/^DNSStubListener=yes/#DNSStubListener=no/' "$RESOLVED_CONF" 2>/dev/null || true

    echo "Stopping systemd-resolved..."
    systemctl stop "$RESOLVED_SERVICE" || true

    echo "Disabling systemd-resolved..."
    systemctl disable "$RESOLVED_SERVICE" || true

    echo ""
    echo -e "${GREEN}Done!${NC}"
    echo "Changes made:"
    echo "  1. Disabled DNS stub listener in $RESOLVED_CONF"
    echo "  2. Stopped and disabled systemd-resolved service"
    echo ""
    echo -e "${YELLOW}A REBOOT is required for changes to take full effect.${NC}"
    echo ""
    echo "After reboot, verify AdGuard Home can bind to port 53:"
    echo "  docker compose up -d adguardhome"
    echo "  docker logs adguardhome | grep -i 'listening'"
}

restore() {
    echo "=== Restoring systemd-resolved ==="

    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Error: --restore requires root (sudo)${NC}"
        echo "Run: sudo $0 --restore"
        exit 1
    fi

    if [[ -f "${RESOLVED_CONF}.bak" ]]; then
        echo "Restoring $RESOLVED_CONF from backup..."
        cp "${RESOLVED_CONF}.bak" "$RESOLVED_CONF"
        echo -e "${GREEN}Restored.${NC}"
    else
        echo -e "${YELLOW}No backup found. Manual restoration may be needed.${NC}"
    fi

    echo "Re-enabling and starting systemd-resolved..."
    systemctl enable "$RESOLVED_SERVICE" || true
    systemctl start "$RESOLVED_SERVICE" || true

    echo ""
    echo -e "${GREEN}Done! systemd-resolved restored.${NC}"
    echo "A reboot may be needed for full effect."
}

case "${1:-}" in
    --check)
        check_port_53
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
        echo "  --check    Check if systemd-resolved is blocking port 53"
        echo "  --apply    Disable systemd-resolved (requires sudo, needs reboot)"
        echo "  --restore  Re-enable systemd-resolved (requires sudo)"
        exit 1
        ;;
esac
