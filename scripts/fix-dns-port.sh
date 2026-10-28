#!/usr/bin/env bash
# scripts/fix-dns-port.sh
# Resolves port 53 UDP/TCP contention with Ubuntu/Debian systemd-resolved

set -euo pipefail

ACTION="${1:---check}"

case "${ACTION}" in
  --check)
    echo "[dns-check] Inspecting port 53 listener..."
    if ss -lntup | grep -q ':53 '; then
      echo "[dns-check] Port 53 is currently occupied:"
      ss -lntup | grep ':53 '
    else
      echo "[dns-check] Port 53 is free."
    fi
    ;;
  --apply)
    echo "[dns-fix] Disabling DNSStubListener in /etc/systemd/resolved.conf..."
    mkdir -p /etc/systemd/resolved.conf.d/
    cat <<EOF > /etc/systemd/resolved.conf.d/adguard.conf
[Resolve]
DNSStubListener=no
EOF
    systemctl restart systemd-resolved || true
    echo "[dns-fix] systemd-resolved reloaded. Port 53 released for AdGuard Home."
    ;;
  --restore)
    echo "[dns-restore] Restoring default systemd-resolved configuration..."
    rm -f /etc/systemd/resolved.conf.d/adguard.conf
    systemctl restart systemd-resolved || true
    echo "[dns-restore] Default resolver restored."
    ;;
  *)
    echo "Usage: ./scripts/fix-dns-port.sh [--check|--apply|--restore]"
    exit 1
    ;;
esac
