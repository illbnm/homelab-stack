#!/usr/bin/env bash
# scripts/fix-dns-port.sh
# Detect and resolve port 53 conflict with systemd-resolved

set -euo pipefail

RESOLVED_CONF="/etc/systemd/resolved.conf"
RESOLVED_CONF_BACKUP="/etc/systemd/resolved.conf.bak"

check_port_53() {
    echo "[*] Checking port 53 occupancy..."
    if command -v ss >/dev/null 2>&1; then
        ss -tulpn | grep ':53 ' || true
    elif command -v netstat >/dev/null 2>&1; then
        netstat -tulpn | grep ':53 ' || true
    else
        echo "[!] Neither ss nor netstat available."
    fi
}

apply_fix() {
    echo "[*] Applying systemd-resolved fix for AdGuard Home..."
    if [ ! -f "$RESOLVED_CONF" ]; then
        echo "[!] $RESOLVED_CONF not found, nothing to modify."
        return
    fi

    if [ ! -f "$RESOLVED_CONF_BACKUP" ]; then
        cp "$RESOLVED_CONF" "$RESOLVED_CONF_BACKUP"
        echo "[+] Backed up original config to $RESOLVED_CONF_BACKUP"
    fi

    # Disable DNSStubListener
    sed -i 's/^#DNSStubListener=yes/DNSStubListener=no/' "$RESOLVED_CONF"
    sed -i 's/^DNSStubListener=yes/DNSStubListener=no/' "$RESOLVED_CONF"
    if ! grep -q "^DNSStubListener=" "$RESOLVED_CONF"; then
        echo "DNSStubListener=no" >> "$RESOLVED_CONF"
    fi

    # Link /etc/resolv.conf to alternate resolv.conf
    if [ -L /etc/resolv.conf ]; then
        ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
    fi

    systemctl restart systemd-resolved || true
    echo "[+] Successfully disabled systemd-resolved 53 stub listener!"
    check_port_53
}

restore_fix() {
    echo "[*] Restoring systemd-resolved original configuration..."
    if [ -f "$RESOLVED_CONF_BACKUP" ]; then
        cp "$RESOLVED_CONF_BACKUP" "$RESOLVED_CONF"
        systemctl restart systemd-resolved || true
        echo "[+] Restored configuration from backup."
    else
        echo "[!] No backup file found ($RESOLVED_CONF_BACKUP)."
    fi
}

case "${1:-check}" in
    --check|check)
        check_port_53
        ;;
    --apply|apply)
        apply_fix
        ;;
    --restore|restore)
        restore_fix
        ;;
    *)
        echo "Usage: $0 [--check | --apply | --restore]"
        exit 1
        ;;
esac
