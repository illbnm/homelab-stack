#!/usr/bin/env bash
# Fix systemd-resolved port 53 conflict for AdGuard DNS
# Usage: ./scripts/fix-dns-port.sh [--check|--apply|--restore]
set -euo pipefail

CMD="${1:---check}"
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; RESET='\033[0m'

case "$CMD" in
  --check)
    if ss -tuln | grep -q ':53 '; then
      echo -e "${RED}Port 53 is in use:${RESET}"
      ss -tuln | grep ':53 '
      echo -e "\nRun: $0 --apply"
      exit 1
    else
      echo -e "${GREEN}Port 53 is free${RESET}"
    fi
    ;;
  --apply)
    if systemctl is-active systemd-resolved &>/dev/null; then
      echo "Disabling systemd-resolved DNS stub..."
      sed -i 's/^#DNSStubListener=yes/DNSStubListener=no/' /etc/systemd/resolved.conf 2>/dev/null || true
      [ ! -f /etc/systemd/resolved.conf ] && echo -e "[Resolve]\nDNSStubListener=no" > /etc/systemd/resolved.conf
      systemctl restart systemd-resolved
      echo -e "${GREEN}Port 53 freed for AdGuard${RESET}"
    fi
    ;;
  --restore)
    sed -i 's/^DNSStubListener=no/#DNSStubListener=yes/' /etc/systemd/resolved.conf 2>/dev/null || true
    systemctl restart systemd-resolved 2>/dev/null || true
    echo -e "${GREEN}systemd-resolved restored${RESET}"
    ;;
  *) echo "Usage: $0 --check|--apply|--restore" ;;
esac