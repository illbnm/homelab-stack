#!/bin/bash

# Script to detect and disable systemd-resolved's 53 port usage

usage() {
    echo "Usage: $0 --check | --apply | --restore"
    exit 1
}

if [ "$#" -ne 1 ]; then
    usage
fi

case "$1" in
    --check)
        if ss -tuln | grep ':53' | grep 'systemd-resolved'; then
            echo "systemd-resolved is using port 53"
            exit 0
        else
            echo "systemd-resolved is not using port 53"
            exit 1
        fi
        ;;
    --apply)
        sudo systemctl stop systemd-resolved
        sudo systemctl disable systemd-resolved
        sudo rm /etc/resolv.conf
        sudo ln -s /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
        echo "systemd-resolved has been disabled on port 53"
        ;;
    --restore)
        sudo systemctl enable systemd-resolved
        sudo systemctl start systemd-resolved
        sudo rm /etc/resolv.conf
        sudo ln -s /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
        echo "systemd-resolved has been restored"
        ;;
    *)
        usage
        ;;
esac