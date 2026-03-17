#!/bin/bash

# Script to handle systemd-resolved port 53 conflict

check_resolved() {
    if ss -tuln | grep ':53' | grep -q 'systemd-resolved'; then
        echo "systemd-resolved is using port 53."
        return 0
    else
        echo "systemd-resolved is not using port 53."
        return 1
    fi
}

apply_fix() {
    if check_resolved; then
        sudo systemctl stop systemd-resolved
        sudo systemctl disable systemd-resolved
        sudo rm /etc/resolv.conf
        sudo ln -s /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
        echo "Disabled systemd-resolved on port 53."
    else
        echo "No action needed. systemd-resolved is not using port 53."
    fi
}

restore_resolved() {
    sudo systemctl enable systemd-resolved
    sudo systemctl start systemd-resolved
    sudo rm /etc/resolv.conf
    sudo ln -s /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
    echo "Restored systemd-resolved on port 53."
}

case "$1" in
    --check)
        check_resolved
        ;;
    --apply)
        apply_fix
        ;;
    --restore)
        restore_resolved
        ;;
    *)
        echo "Usage: $0 --check | --apply | --restore"
        exit 1
        ;;
esac