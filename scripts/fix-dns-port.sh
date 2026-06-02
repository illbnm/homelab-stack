#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — fix-dns-port.sh
# Detects and resolves systemd-resolved conflict on port 53/udp for AdGuard.
#
# Usage:
#   ./fix-dns-port.sh --check    Check if port 53 is free
#   ./fix-dns-port.sh --apply    Disable systemd-resolved stub listener
#   ./fix-dns-port.sh --restore  Re-enable systemd-resolved stub listener
#
# ARM64 compatible — works on ARM64 (DGX Atom, Raspberry Pi, etc.) and x86_64.
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()  { echo -e "${BLUE}${BOLD}[STEP]${NC} $*"; }

ARCH=$(uname -m)
log_info "Detected architecture: $ARCH"

check_port_53() {
  if ss -tuln 2>/dev/null | grep -q ':53\b'; then
    echo "occupied"
  elif netstat -tuln 2>/dev/null | grep -q ':53\b'; then
    echo "occupied"
  else
    echo "free"
  fi
}

check_resolved_stub() {
  if grep -qs '^DNSStubListener=no' /etc/systemd/resolved.conf 2>/dev/null; then
    echo "disabled"
  elif grep -qs '^DNSStubListener=yes' /etc/systemd/resolved.conf 2>/dev/null; then
    echo "enabled"
  elif [[ -f /etc/systemd/resolved.conf ]]; then
    echo "default"
  else
    echo "absent"
  fi
}

do_check() {
  log_step "Checking port 53 status..."

  local status
  status=$(check_port_53)

  if [[ "$status" == "free" ]]; then
    log_info "Port 53 is free — AdGuard Home can bind without issues."
  else
    log_warn "Port 53 is OCCUPIED!"
    echo ""
    ss -tuln 2>/dev/null | grep ':53\b' || netstat -tuln 2>/dev/null | grep ':53\b' || true
    echo ""
    log_info "This is likely systemd-resolved. Re-run with --apply to fix."
  fi

  local resolved
  resolved=$(check_resolved_stub)
  log_info "systemd-resolved stub listener: $resolved"
}

do_apply() {
  log_step "Disabling systemd-resolved DNS stub listener..."

  if [[ ! -f /etc/systemd/resolved.conf ]]; then
    log_error "/etc/systemd/resolved.conf not found — not a systemd system?"
    exit 1
  fi

  if [[ "$(check_resolved_stub)" == "disabled" ]]; then
    log_info "DNSStubListener is already disabled. No changes needed."
    return 0
  fi

  cp /etc/systemd/resolved.conf /etc/systemd/resolved.conf.bak.$(date +%Y%m%d%H%M%S)
  log_info "Backup created"

  if [[ "$(check_resolved_stub)" == "default" ]]; then
    echo "[Resolve]" >> /etc/systemd/resolved.conf
  fi

  sed -i 's/^#\?DNSStubListener=.*/DNSStubListener=no/' /etc/systemd/resolved.conf
  grep -q '^DNSStubListener=no' /etc/systemd/resolved.conf || \
    sed -i '/^\[Resolve\]/a DNSStubListener=no' /etc/systemd/resolved.conf

  log_info "DNSStubListener set to 'no'"

  if command -v systemctl &>/dev/null; then
    systemctl restart systemd-resolved
    log_info "systemd-resolved restarted"
  fi

  log_info "Port 53 should now be free. Verify with: ./fix-dns-port.sh --check"
}

do_restore() {
  log_step "Restoring systemd-resolved DNS stub listener..."

  if [[ ! -f /etc/systemd/resolved.conf ]]; then
    log_error "/etc/systemd/resolved.conf not found"
    exit 1
  fi

  local latest_backup
  latest_backup=$(ls -t /etc/systemd/resolved.conf.bak.* 2>/dev/null | head -1)

  if [[ -n "$latest_backup" ]]; then
    cp "$latest_backup" /etc/systemd/resolved.conf
    log_info "Restored from backup: $latest_backup"
  else
    sed -i 's/^DNSStubListener=no/DNSStubListener=yes/' /etc/systemd/resolved.conf
    log_warn "No backup found — set DNSStubListener=yes manually"
  fi

  if command -v systemctl &>/dev/null; then
    systemctl restart systemd-resolved
    log_info "systemd-resolved restarted"
  fi
}

usage() {
  echo ""
  echo -e "${BOLD}Usage:${NC} $0 <command>"
  echo ""
  echo "Commands:"
  echo "  --check    Check if port 53 is free for AdGuard Home"
  echo "  --apply    Disable systemd-resolved stub listener on port 53"
  echo "  --restore  Re-enable systemd-resolved stub listener"
  echo ""
  echo -e "${BOLD}Platform:${NC} ARM64 + x86_64 compatible"
  echo ""
}

case "${1:-}" in
  --check)   do_check ;;
  --apply)   do_apply ;;
  --restore) do_restore ;;
  *)         usage; exit 1 ;;
esac
