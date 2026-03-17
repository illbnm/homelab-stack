#!/bin/bash

# Script to handle systemd-resolved port 53 conflict

usage() {
    echo "Usage: $0 --check|--apply|--restore"
    exit 1
}

if [ "$#" -ne 1 ]; then
    usage
fi

case "$1" in
    --check)
        if systemctl is-active --quiet systemd-resolved; then
            if ss -tuln | grep -q ':53'; then
                echo "systemd-resolved is active and using port 53."
                exit 1
            else
                echo "systemd-resolved is active but not using port 53."
                exit 0
            fi
        else
            echo "systemd-resolved is not active."
            exit 0
        fi
        ;;
    --apply)
        sudo systemctl stop systemd-resolved
        sudo systemctl disable systemd-resolved
        echo "systemd-resolved has been stopped and disabled."
        ;;
    --restore)
        sudo systemctl enable systemd-resolved
        sudo systemctl start systemd-resolved
        echo "systemd-resolved has been enabled and started."
        ;;
    *)
        usage
        ;;
esac