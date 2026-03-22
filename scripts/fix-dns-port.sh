#!/bin/bash

# Script to handle systemd-resolved 53 port conflict

usage() {
    echo "Usage: $0 {--check|--apply|--restore}"
    exit 1
}

check_conflict() {
    if ss -tuln | grep ':53' | grep -q 'systemd-resolved'; then
        echo "Conflict detected: systemd-resolved is using port 53."
        return 1
    else
        echo "No conflict detected: port 53 is not used by systemd-resolved."
        return 0
    fi
}

apply_fix() {
    if check_conflict; then
        echo "No need to apply fix."
        return 0
    fi
    sudo systemctl stop systemd-resolved
    sudo systemctl disable systemd-resolved
    sudo rm /etc/resolv.conf
    echo "nameserver 127.0.0.1" | sudo tee /etc/resolv.conf
    echo "Fixed: systemd-resolved is disabled and port 53 is now free."
}

restore_systemd_resolved() {
    sudo systemctl enable systemd-resolved
    sudo systemctl start systemd-resolved
    sudo rm /etc/resolv.conf
    sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
    echo "Restored: systemd-resolved is enabled and configured."
}

case "$1" in
    --check)
        check_conflict
        ;;
    --apply)
        apply_fix
        ;;
    --restore)
        restore_systemd_resolved
        ;;
    *)
        usage
        ;;
esac