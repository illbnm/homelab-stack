#!/usr/bin/env bash
# scripts/fix-dns-port.sh
# Detect and disable systemd-resolved 53 port binding

set -e

ACTION=$1

case "$ACTION" in
  --check)
    if systemctl is-active --quiet systemd-resolved; then
      if grep -q "^DNSStubListener=no" /etc/systemd/resolved.conf; then
        echo "systemd-resolved is active, but DNSStubListener is disabled. Port 53 is free."
        exit 0
      else
        echo "systemd-resolved is active and may be using port 53."
        exit 1
      fi
    else
      echo "systemd-resolved is not active."
      exit 0
    fi
    ;;
  --apply)
    echo "Disabling DNSStubListener in systemd-resolved..."
    if ! grep -q "^DNSStubListener=no" /etc/systemd/resolved.conf; then
        sudo sed -i 's/^#*DNSStubListener=.*/DNSStubListener=no/' /etc/systemd/resolved.conf
        if ! grep -q "^DNSStubListener=no" /etc/systemd/resolved.conf; then
            echo "DNSStubListener=no" | sudo tee -a /etc/systemd/resolved.conf
        fi
    fi
    sudo systemctl restart systemd-resolved
    echo "systemd-resolved restarted. Port 53 should now be free."
    ;;
  --restore)
    echo "Restoring DNSStubListener in systemd-resolved..."
    sudo sed -i 's/^DNSStubListener=no/#DNSStubListener=yes/' /etc/systemd/resolved.conf
    sudo systemctl restart systemd-resolved
    echo "systemd-resolved restored."
    ;;
  *)
    echo "Usage: $0 {--check|--apply|--restore}"
    exit 1
    ;;
esac
