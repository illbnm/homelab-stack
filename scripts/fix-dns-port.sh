#!/usr/bin/env bash
# =============================================================================
# fix-dns-port.sh — 检测并处理 systemd-resolved 的 53 端口占用
#
# Usage:
#   fix-dns-port.sh --check    检测 53 端口状态
#   fix-dns-port.sh --apply    禁用 systemd-resolved 的 53 端口
#   fix-dns-port.sh --restore  恢复 systemd-resolved 默认配置
# =============================================================================

set -euo pipefail

RESOLVED_CONF="/etc/systemd/resolved.conf"
RESOLVED_BACKUP="/etc/systemd/resolved.conf.bak"

log()  { echo "[fix-dns] $*"; }
ok()   { echo "[fix-dns] ✅ $*"; }
fail() { echo "[fix-dns] ❌ $*"; }

check_port() {
  log "Checking port 53..."

  if ss -tlnp | grep -q ':53 '; then
    local proc=$(ss -tlnp | grep ':53 ' | awk '{print $NF}')
    log "Port 53 is in use by: ${proc}"

    if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
      log "systemd-resolved is active"
      if grep -q "DNSStubListener=no" "$RESOLVED_CONF" 2>/dev/null; then
        ok "DNSStubListener already disabled"
      else
        log "⚠️  DNSStubListener is enabled — run --apply to fix"
      fi
    else
      log "systemd-resolved is not active"
    fi
  else
    ok "Port 53 is free"
  fi
}

apply_fix() {
  log "Applying DNS port fix..."

  if ! systemctl is-active --quiet systemd-resolved 2>/dev/null; then
    ok "systemd-resolved not active, no fix needed"
    return 0
  fi

  # Backup
  if [[ ! -f "$RESOLVED_BACKUP" ]]; then
    cp "$RESOLVED_CONF" "$RESOLVED_BACKUP"
    ok "Backed up ${RESOLVED_CONF}"
  fi

  # Disable stub listener
  if grep -q "^DNSStubListener=" "$RESOLVED_CONF"; then
    sed -i 's/^DNSStubListener=.*/DNSStubListener=no/' "$RESOLVED_CONF"
  elif grep -q "^#DNSStubListener=" "$RESOLVED_CONF"; then
    sed -i 's/^#DNSStubListener=.*/DNSStubListener=no/' "$RESOLVED_CONF"
  else
    echo -e "\n[Resolve]\nDNSStubListener=no" >> "$RESOLVED_CONF"
  fi

  # Point DNS to localhost (AdGuard will handle it)
  if [[ -L /etc/resolv.conf ]]; then
    rm /etc/resolv.conf
    echo -e "nameserver 127.0.0.1\nnameserver 1.1.1.1" > /etc/resolv.conf
    ok "Updated /etc/resolv.conf"
  fi

  # Restart
  systemctl restart systemd-resolved
  ok "systemd-resolved restarted with DNSStubListener=no"

  # Verify
  sleep 1
  if ss -tlnp | grep -q ':53 .*systemd-resolve'; then
    fail "Port 53 still occupied by systemd-resolved"
    return 1
  else
    ok "Port 53 is now free for AdGuard Home"
  fi
}

restore() {
  log "Restoring systemd-resolved defaults..."

  if [[ -f "$RESOLVED_BACKUP" ]]; then
    cp "$RESOLVED_BACKUP" "$RESOLVED_CONF"
    systemctl restart systemd-resolved
    ok "Restored from backup"
  else
    fail "No backup found at ${RESOLVED_BACKUP}"
    return 1
  fi

  # Restore resolv.conf symlink
  if [[ ! -L /etc/resolv.conf ]]; then
    ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
    ok "Restored /etc/resolv.conf symlink"
  fi
}

# ── Main ─────────────────────────────────────────────────────────────────────

case "${1:-}" in
  --check)   check_port ;;
  --apply)   apply_fix ;;
  --restore) restore ;;
  *)
    echo "Usage: $0 {--check|--apply|--restore}"
    echo ""
    echo "  --check    Check if port 53 is occupied"
    echo "  --apply    Disable systemd-resolved stub listener"
    echo "  --restore  Restore systemd-resolved defaults"
    exit 1
    ;;
esac
