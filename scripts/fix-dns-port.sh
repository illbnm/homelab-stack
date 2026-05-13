#!/bin/bash
# fix-dns-port.sh — Detect and disable systemd-resolved port 53 conflict
# Usage: ./fix-dns-port.sh [--check|--apply|--restore]

set -euo pipefail

RESOLVED_CONF="/etc/systemd/resolved.conf"
RESOLVED_SERVICE="systemd-resolved.service"

log() { echo -e "\033[1m[fix-dns-port]\033[0m $*"; }
warn() { echo -e "\033[33m[fix-dns-port]\033[0m $*"; }
error() { echo -e "\033[31m[fix-dns-port]\033[0m $*"; }

check_resolved_running() {
  systemctl is-active --quiet "$RESOLVED_SERVICE" 2>/dev/null
}

check_port_53_in_use() {
  ss -tulnp | grep -q ':53 ' || netstat -tulnp 2>/dev/null | grep -q ':53 '
}

apply_fix() {
  if check_port_53_in_use; then
    warn "Port 53 is currently in use."
    if check_resolved_running; then
      log "Disabling systemd-resolved DNS stub listener on port 53…"
      if [ -f "$RESOLVED_CONF" ]; then
        cp -f "$RESOLVED_CONF" "${RESOLVED_CONF}.bak.$(date +%s)"
        sed -i 's/^#DNSStubListener=.*/DNSStubListener=yes/' "$RESOLVED_CONF"
        sed -i 's/^DNSStubListener=.*/DNSStubListener=no/' "$RESOLVED_CONF"
      fi
      systemctl restart "$RESOLVED_SERVICE"
      sleep 2
      if check_port_53_in_use; then
        error "Port 53 still occupied after restart. May need manual intervention."
        return 1
      fi
      log "systemd-resolved stub listener disabled successfully."
    else
      warn "Port 53 in use but systemd-resolved is not running."
      log "Process holding port 53:"
      ss -tulnp | grep ':53 ' || netstat -tulnp | grep ':53 '
      return 0
    fi
  else
    log "Port 53 is free."
    return 0
  fi
}

restore_fix() {
  log "Restoring systemd-resolved stub listener…"
  if [ -f "$RESOLVED_CONF" ]; then
    sed -i 's/^#DNSStubListener=.*/DNSStubListener=yes/' "$RESOLVED_CONF"
    sed -i 's/^DNSStubListener=.*/DNSStubListener=yes/' "$RESOLVED_CONF"
  fi
  systemctl restart "$RESOLVED_SERVICE"
  log "systemd-resolved stub listener restored."
}

do_check() {
  log "Checking port 53 status…"
  if check_port_53_in_use; then
    error "Port 53 is in use."
    if check_resolved_running; then
      log "systemd-resolved is active and likely holding port 53."
      log "Run: $0 --apply to disable the stub listener."
    else
      warn "Port 53 in use by another service:"
      ss -tulnp | grep ':53 ' || netstat -tulnp | grep ':53 '
    fi
    return 1
  else
    log "Port 53 is free. AdGuard Home can bind to port 53."
    return 0
  fi
}

case "${1:---check}" in
  --check)
    do_check
    ;;
  --apply)
    apply_fix
    ;;
  --restore)
    restore_fix
    ;;
  *)
    echo "Usage: $0 [--check|--apply|--restore]"
    echo ""
    echo "  --check    Check if port 53 is free"
    echo "  --apply    Disable systemd-resolved stub listener on port 53"
    echo "  --restore  Restore systemd-resolved stub listener"
    exit 1
    ;;
esac
