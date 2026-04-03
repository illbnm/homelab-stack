#!/usr/bin/env bash
# fix-dns-port.sh — Resolve systemd-resolved port 53 conflict
#
# Usage:
#   ./fix-dns-port.sh --check    Detect conflict
#   ./fix-dns-port.sh --apply   Apply fix (disable systemd-resolved on :53)
#   ./fix-dns-port.sh --restore  Re-enable systemd-resolved

set -euo pipefail

RESOLVED_CONF="/etc/systemd/resolved.conf"
RESOLVED_STUB="/etc/resolv.conf"
BACKUP_DIR="/var/tmp/dns-fix-backup"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[✗]${NC} $*" >&2; exit 1; }
need_root() { [[ $EUID -ne 0 ]] && err "Must run as root (use sudo)"; }

do_check() {
  log "Checking port 53..."

  if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
    warn "systemd-resolved is ACTIVE — likely bound to port 53"
  else
    log "systemd-resolved is not active"
  fi

  echo ""
  log "Port 53 listeners:"
  ss -tulpn | grep ':53' || ss -tulpn | grep '53:' || warn "Nothing found"

  echo ""
  if [[ -L "$RESOLVED_STUB" ]] && readlink "$RESOLVED_STUB" | grep -q systemd; then
    warn "resolv.conf is managed by systemd-resolved"
  fi

  echo ""
  log "$RESOLVED_CONF:"
  cat "$RESOLVED_CONF" 2>/dev/null || echo "(not found)"
}

do_apply() {
  need_root
  log "Applying fix..."

  mkdir -p "$BACKUP_DIR"
  [[ -f "$RESOLVED_CONF" ]] && cp "$RESOLVED_CONF" "$BACKUP_DIR/resolved.conf.bak"

  cat > "$RESOLVED_CONF" <<'EOF'
# Written by fix-dns-port.sh
[Resolve]
DNS=1.1.1.1 8.8.8.8
DNSOverTLS=no
EOF
  log "Wrote $RESOLVED_CONF"

  rm -f "$RESOLVED_STUB"
  cat > "$RESOLVED_STUB" <<'EOF'
nameserver 1.1.1.1
nameserver 8.8.8.8
options edns0 trust-ad
EOF
  log "Created static $RESOLVED_STUB"

  systemctl restart systemd-resolved 2>/dev/null || true
  log "Done. Run: sudo systemctl restart docker"
}

do_restore() {
  need_root
  log "Restoring systemd-resolved..."
  [[ -f "$BACKUP_DIR/resolved.conf.bak" ]] && cp "$BACKUP_DIR/resolved.conf.bak" "$RESOLVED_CONF"
  ln -sf /run/systemd/resolve/stub-resolv.conf "$RESOLVED_STUB" 2>/dev/null || true
  systemctl restart systemd-resolved 2>/dev/null || true
  log "Restored."
}

case "${1:-}" in
  --check)   do_check ;;
  --apply)   do_apply ;;
  --restore) do_restore ;;
  *)         echo "Usage: $0 {--check|--apply|--restore}"; exit 1 ;;
esac
