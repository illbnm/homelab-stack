#!/usr/bin/env bash
# fix-dns-port.sh — Detect and disable systemd-resolved conflict on port 53
# Usage: fix-dns-port.sh [--check|--apply|--restore]

set -euo pipefail

BACKUP_DIR="/etc/systemd/resolved.conf.d"
BACKUP_FILE="${BACKUP_DIR}/ipaship-backup.conf"

check() {
  if systemctl is-active systemd-resolved &>/dev/null; then
    local dns_listening
    dns_listening=$(resolvectl status 2>/dev/null | grep "DNS Servers" | head -1 || true)
    echo "systemd-resolved is active. DNS: ${dns_listening:-unknown}"
    if ss -tulpn 2>/dev/null | grep -q ":53 "; then
      echo "Port 53 is in use by: $(ss -tulpn 2>/dev/null | grep ':53 ' | head -1)"
      return 1
    fi
    echo "Port 53 is free."
    return 0
  else
    echo "systemd-resolved is not active."
    return 0
  fi
}

apply() {
  echo "Applying fix for systemd-resolved port 53 conflict..."

  if [ ! -d "$BACKUP_DIR" ]; then
    mkdir -p "$BACKUP_DIR"
  fi

  cat > "$BACKUP_FILE" << 'EOF'
[Resolve]
DNS=127.0.0.1
DNSStubListener=no
EOF

  systemctl restart systemd-resolved
  echo "Applied: DNSStubListener=no. systemd-resolved restarted."
  echo "AdGuard Home can now bind to port 53."
}

restore() {
  if [ -f "$BACKUP_FILE" ]; then
    rm -f "$BACKUP_FILE"
    systemctl restart systemd-resolved
    echo "Restored: removed DNSStubListener override. systemd-resolved restarted."
  else
    echo "No backup found — nothing to restore."
  fi
}

case "${1:---check}" in
  --check)
    check
    ;;
  --apply)
    apply
    ;;
  --restore)
    restore
    ;;
  *)
    echo "Usage: $0 [--check|--apply|--restore]"
    exit 1
    ;;
esac
