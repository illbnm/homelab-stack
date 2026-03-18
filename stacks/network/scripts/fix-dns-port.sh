#!/usr/bin/env bash
# fix-dns-port.sh - Detect & disable systemd-resolved on port 53
# Usage: fix-dns-port.sh [--check|--apply|--restore]

set -euo pipefail

RESOLVED_CONF="/etc/systemd/resolved.conf"

check() {
  if ss -ulnp | grep -q ':53 '; then
    local pid
    pid=$(ss -ulnp | grep ':53 ' | grep -oP 'pid=\K[0-9]+' | head -1)
    local proc
    proc=$(readlink -f "/proc/$pid/exe" 2>/dev/null || echo "unknown")
    echo "⚠️  Port 53 is in use by PID $pid ($proc)"
    if [[ "$proc" == *systemd-resolved* ]]; then
      echo "   systemd-resolved detected — run: $0 --apply"
    fi
    return 1
  else
    echo "✅ Port 53 is free"
    return 0
  fi
}

apply() {
  echo "🔧 Disabling systemd-resolved DNS stub..."
  sudo sed -i 's/^#\?DNSStubListener=.*/DNSStubListener=no/' "$RESOLVED_CONF"
  sudo sed -i 's/^#\?DNS=.*/DNS=1.1.1.1/' "$RESOLVED_CONF"
  sudo systemctl restart systemd-resolved

  # Remove symlink if present
  if [[ -L /etc/resolv.conf ]]; then
    echo "   Replacing resolv.conf symlink..."
    sudo rm -f /etc/resolv.conf
    echo -e "nameserver 127.0.0.1\nsearch lan" | sudo tee /etc/resolv.conf >/dev/null
  fi
  echo "✅ Done. Port 53 is now available for AdGuard Home."
}

restore() {
  echo "🔧 Restoring systemd-resolved defaults..."
  sudo sed -i 's/^DNSStubListener=.*/DNSStubListener=yes/' "$RESOLVED_CONF"
  sudo sed -i 's/^DNS=.*/#DNS=/' "$RESOLVED_CONF"
  sudo systemctl restart systemd-resolved
  sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
  echo "✅ Restored."
}

case "${1:---check}" in
  --check)  check ;;
  --apply)  apply ;;
  --restore) restore ;;
  *) echo "Usage: $0 [--check|--apply|--restore]"; exit 1 ;;
esac
