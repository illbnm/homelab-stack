#!/usr/bin/env bash
# Usage: ./scripts/fix-dns-port.sh [--check|--apply|--restore]
# Detects and resolves systemd-resolved port 53 conflict for AdGuard Home.
set -euo pipefail

MODE="${1:---check}"
RESOLVED_CONF="/etc/systemd/resolved.conf"

case "$MODE" in
  --check)
    if command -v ss >/dev/null 2>&1 && ss -tulnp | grep -q ':53 '; then
      echo "[CONFLICT] Port 53 is currently bound. Run '$0 --apply' to disable systemd-resolved stub listener."
      exit 1
    fi
    echo "[OK] Port 53 is free."
    ;;
  --apply)
    if [[ -f "$RESOLVED_CONF" ]]; then
      cp "$RESOLVED_CONF" "${RESOLVED_CONF}.bak"
      sed -i -E 's/^#?DNSStubListener=.*/DNSStubListener=no/' "$RESOLVED_CONF"
      grep -q '^DNSStubListener=no' "$RESOLVED_CONF" || echo "DNSStubListener=no" >> "$RESOLVED_CONF"
    fi
    ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf || true
    systemctl restart systemd-resolved || true
    echo "[OK] Disabled systemd-resolved stub listener on port 53."
    ;;
  --restore)
    if [[ -f "${RESOLVED_CONF}.bak" ]]; then
      mv "${RESOLVED_CONF}.bak" "$RESOLVED_CONF"
      systemctl restart systemd-resolved || true
      echo "[OK] Restored systemd-resolved configuration."
    fi
    ;;
  *)
    echo "Usage: $0 [--check|--apply|--restore]" >&2
    exit 1
    ;;
esac
