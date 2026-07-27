#!/usr/bin/env bash
# =============================================================================
# fix-dns-port.sh
# Detect and disable systemd-resolved's 53 port to free it for AdGuard Home
#
# Usage:
#   ./fix-dns-port.sh --check    # Check if port 53 is occupied by systemd-resolved
#   ./fix-dns-port.sh --apply    # Disable systemd-resolved's port 53 binding
#   ./fix-dns-port.sh --restore  # Restore systemd-resolved to default
# =============================================================================

set -euo pipefail

usage() {
  echo "Usage: $0 --check|--apply|--restore"
  exit 1
}

check_port() {
  # Check if port 53 UDP is occupied by systemd-resolved
  if ss -ulpn | grep -q 'systemd-resolve.*:53'; then
    echo "[WARN] Port 53 UDP is occupied by systemd-resolved"
    return 0
  else
    echo "[OK] Port 53 UDP is free"
    return 1
  fi
}

apply_fix() {
  echo "[INFO] Applying fix: disabling systemd-resolved's port 53 binding"
  # Backup current config if not exists
  if [ ! -f /etc/systemd/resolved.conf.bak ]; then
    sudo cp /etc/systemd/resolved.conf /etc/systemd/resolved.conf.bak
  fi
  # Disable DNSStubListener
  sudo sed -i 's/^#DNSStubListener=yes/DNSStubListener=no/' /etc/systemd/resolved.conf
  sudo sed -i 's/^DNSStubListener=yes/DNSStubListener=no/' /etc/systemd/resolved.conf
  # Restart systemd-resolved
  sudo systemctl restart systemd-resolved
  echo "[INFO] systemd-resolved restarted"
}

restore_fix() {
  echo "[INFO] Restoring systemd-resolved configuration"
  if [ -f /etc/systemd/resolved.conf.bak ]; then
    sudo cp /etc/systemd/resolved.conf.bak /etc/systemd/resolved.conf
    sudo systemctl restart systemd-resolved
    echo "[INFO] systemd-resolved restored and restarted"
  else
    echo "[ERROR] Backup file /etc/systemd/resolved.conf.bak not found"
    exit 1
  fi
}

if [ $# -ne 1 ]; then
  usage
fi

case "$1" in
  --check)
    check_port
    ;;
  --apply)
    apply_fix
    ;;
  --restore)
    restore_fix
    ;;
  *)
    usage
    ;;
esac
