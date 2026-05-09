#!/usr/bin/env bash
# =============================================================================
# Fix DNS Port (53) — Handles systemd-resolved conflict for AdGuard Home
# Usage: fix-dns-port.sh [--check|--apply|--restore]
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RESET='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

ACTION="${1:---check}"

check_port() {
  if ss -tuln | grep -q ':53 '; then
    log_warn "Port 53 is in use!"
    ss -tuln | grep ':53 '
    return 1
  fi
  log_info "Port 53 is free"
  return 0
}

case "$ACTION" in
  --check)
    check_port
    ;;
  --apply)
    log_info "Disabling systemd-resolved DNS stub listener..."
    
    if [ -f /etc/systemd/resolved.conf ]; then
      # Backup original config
      cp /etc/systemd/resolved.conf /etc/systemd/resolved.conf.bak.$(date +%s) 2>/dev/null || true
      
      # Disable DNSStubListener
      sed -i 's/^#DNSStubListener=.*/DNSStubListener=no/' /etc/systemd/resolved.conf
      if ! grep -q '^DNSStubListener=no' /etc/systemd/resolved.conf; then
        echo "DNSStubListener=no" >> /etc/systemd/resolved.conf
      fi
      
      # Disable DNSOverTLS for now (conflicts with port 853 if needed)
      sed -i 's/^#DNSOverTLS=.*/DNSOverTLS=no/' /etc/systemd/resolved.conf
      
      systemctl restart systemd-resolved
      log_info "systemd-resolved restarted with DNSStubListener=no"
    fi
    
    # Verify
    sleep 2
    if check_port; then
      log_info "Port 53 is now available for AdGuard Home"
    else
      log_error "Port 53 is still in use. Check: sudo lsof -i :53"
      exit 1
    fi
    ;;
  --restore)
    log_info "Restoring systemd-resolved configuration..."
    local latest_backup=$(ls -t /etc/systemd/resolved.conf.bak.* 2>/dev/null | head -1)
    if [ -n "$latest_backup" ]; then
      cp "$latest_backup" /etc/systemd/resolved.conf
      systemctl restart systemd-resolved
      log_info "Restored from: $latest_backup"
    else
      log_warn "No backup found"
    fi
    ;;
  *)
    echo "Usage: fix-dns-port.sh [--check|--apply|--restore]"
    exit 1
    ;;
esac
