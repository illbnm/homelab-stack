#!/usr/bin/env bash
# scripts/fix-dns-port.sh - Resolve systemd-resolved port 53 conflicts for AdGuard Home
# Usage: ./scripts/fix-dns-port.sh [--check|--apply|--restore]

set -euo pipefail

ACTION="${1:---check}"

RESOLVED_CONF="/etc/systemd/resolved.conf"
BACKUP_CONF="/etc/systemd/resolved.conf.bak"

check_port_53() {
    echo "[DNS Fix] Checking port 53 status..."
    if command -v ss >/dev/null 2>&1; then
        ss -tulpn | grep ':53 ' || echo "[DNS Fix] Port 53 is free."
    elif command -v netstat >/dev/null 2>&1; then
        netstat -tulpn | grep ':53 ' || echo "[DNS Fix] Port 53 is free."
    else
        echo "[DNS Fix] System port checkers (ss/netstat) not found."
    fi
}

apply_fix() {
    echo "[DNS Fix] Applying systemd-resolved port 53 stub listener fix..."
    if [ -f "$RESOLVED_CONF" ]; then
        cp "$RESOLVED_CONF" "$BACKUP_CONF"
        sed -i 's/#DNSStubListener=yes/DNSStubListener=no/' "$RESOLVED_CONF"
        sed -i 's/DNSStubListener=yes/DNSStubListener=no/' "$RESOLVED_CONF"
        systemctl restart systemd-resolved || true
        echo "[DNS Fix] Applied successfully. Backup saved at ${BACKUP_CONF}."
    else
        echo "[DNS Fix] systemd-resolved.conf not found. Skipping."
    fi
}

restore_fix() {
    echo "[DNS Fix] Restoring original systemd-resolved configuration..."
    if [ -f "$BACKUP_CONF" ]; then
        cp "$BACKUP_CONF" "$RESOLVED_CONF"
        systemctl restart systemd-resolved || true
        echo "[DNS Fix] Restored successfully."
    else
        echo "[DNS Fix] Backup file not found."
    fi
}

case "$ACTION" in
    --check)
        check_port_53
        ;;
    --apply)
        apply_fix
        check_port_53
        ;;
    --restore)
        restore_fix
        ;;
    *)
        echo "Usage: $0 [--check|--apply|--restore]"
        exit 1
        ;;
esac
