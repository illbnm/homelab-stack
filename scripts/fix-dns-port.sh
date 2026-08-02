#!/usr/bin/env bash
# =============================================================================
# HomeLab DNS Port Fix
# Handles systemd-resolved port 53 conflict for AdGuard Home.
# Usage: ./fix-dns-port.sh [--check|--apply|--restore]
# =============================================================================
set -euo pipefail

RESOLVED_CONF="/etc/systemd/resolved.conf"
BACKUP_CONF="${RESOLVED_CONF}.bak.homelab"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RESET='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

if [ "$EUID" -ne 0 ]; then
  log_error "Please run as root (use sudo)."
  exit 1
fi

check() {
  log_info "Checking port 53 usage..."
  if ss -tulpn | grep -q ":53 "; then
    local proc
    proc=$(ss -tulpn | grep ":53 " | head -n1 | awk '{print $NF}')
    log_warn "Port 53 is currently in use by: $proc"
    
    if grep -q "^DNSStubListener=no" "$RESOLVED_CONF" 2>/dev/null; then
        log_info "systemd-resolved DNSStubListener is already set to 'no'."
    else
        log_warn "systemd-resolved is likely causing a conflict."
        log_info "Run '$0 --apply' to resolve it."
    fi
  else
    log_info "Port 53 is available."
  fi
}

apply() {
  log_info "Applying systemd-resolved fix..."
  
  if [ ! -f "$RESOLVED_CONF" ]; then
    log_error "$RESOLVED_CONF not found. Are you using systemd-resolved?"
    exit 1
  fi
  
  if grep -q "^DNSStubListener=no" "$RESOLVED_CONF"; then
    log_info "Fix is already applied."
    exit 0
  fi
  
  log_info "Backing up $RESOLVED_CONF to $BACKUP_CONF..."
  cp "$RESOLVED_CONF" "$BACKUP_CONF"
  
  log_info "Modifying $RESOLVED_CONF..."
  sed -i 's/^#DNSStubListener=yes/DNSStubListener=no/' "$RESOLVED_CONF"
  sed -i 's/^DNSStubListener=yes/DNSStubListener=no/' "$RESOLVED_CONF"
  
  if ! grep -q "^DNSStubListener=no" "$RESOLVED_CONF"; then
      echo "DNSStubListener=no" >> "$RESOLVED_CONF"
  fi
  
  log_info "Restarting systemd-resolved..."
  systemctl restart systemd-resolved
  
  log_info "Fix applied successfully! Port 53 should now be free."
  check
}

restore() {
  log_info "Restoring systemd-resolved config..."
  if [ -f "$BACKUP_CONF" ]; then
    cp "$BACKUP_CONF" "$RESOLVED_CONF"
    log_info "Configuration restored."
    log_info "Restarting systemd-resolved..."
    systemctl restart systemd-resolved
    log_info "Restore completed."
  else
    log_error "Backup file $BACKUP_CONF not found."
    exit 1
  fi
}

case "${1:-}" in
  --check)   check ;;
  --apply)   apply ;;
  --restore) restore ;;
  *)
    echo "Usage: $0 [--check|--apply|--restore]"
    echo "  --check   : Check if port 53 is in use"
    echo "  --apply   : Disable systemd-resolved stub listener"
    echo "  --restore : Restore original systemd-resolved config"
    exit 1
    ;;
esac
