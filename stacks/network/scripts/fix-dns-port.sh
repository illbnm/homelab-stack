#!/usr/bin/env bash
# Resolves port 53 conflict with systemd-resolved
set -e

ACTION="${1:---check}"

if [ "$ACTION" = "--check" ]; then
    if ss -lntup | grep -q ":53 "; then
        echo "[WARN] Port 53 is occupied:"
        ss -lntup | grep ":53 "
        exit 1
    else
        echo "[OK] Port 53 is free."
        exit 0
    fi
elif [ "$ACTION" = "--apply" ]; then
    echo "Disabling DNSStubListener in systemd-resolved..."
    sudo sed -i 's/#DNSStubListener=yes/DNSStubListener=no/' /etc/systemd/resolved.conf || true
    sudo systemctl restart systemd-resolved
    echo "[OK] systemd-resolved updated."
elif [ "$ACTION" = "--restore" ]; then
    sudo sed -i 's/DNSStubListener=no/#DNSStubListener=yes/' /etc/systemd/resolved.conf || true
    sudo systemctl restart systemd-resolved
    echo "[OK] systemd-resolved restored."
fi
