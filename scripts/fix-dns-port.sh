#!/usr/bin/env bash
set -euo pipefail
CONF="/etc/systemd/resolved.conf"
BACKUP="/etc/systemd/resolved.conf.bak"

check() {
    echo "=== Checking port 53 ==="
    if ss -tulnp | grep -q ":53 "; then
        echo "Port 53 is in use:"
        ss -tulnp | grep ":53 "
        return 1
    else
        echo "Port 53 is free"
        return 0
    fi
}

apply() {
    echo "=== Disabling systemd-resolved DNS listener ==="
    [ ! -f "$BACKUP" ] && cp "$CONF" "$BACKUP"
    if grep -q "^\[Resolve\]" "$CONF"; then
        sed -i "/^\[Resolve\]/a DNSStubListener=no" "$CONF"
    else
        echo -e "\n[Resolve]\nDNSStubListener=no" >> "$CONF"
    fi
    systemctl restart systemd-resolved
    echo "systemd-resolved DNS listener disabled"
    check
}

restore() {
    echo "=== Restoring systemd-resolved ==="
    if [ -f "$BACKUP" ]; then
        cp "$BACKUP" "$CONF"
    else
        sed -i "/DNSStubListener=no/d" "$CONF"
    fi
    systemctl restart systemd-resolved
    echo "Configuration restored"
}

case "${1:---check}" in
    --check)   check ;;
    --apply)   apply ;;
    --restore) restore ;;
    *) echo "Usage: $0 [--check | --apply | --restore]"; exit 1 ;;
esac