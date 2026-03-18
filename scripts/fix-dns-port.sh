#!/usr/bin/env bash
# =============================================================================
# Fix DNS Port Conflict — 解决 systemd-resolved 占用 53 端口问题
# =============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[fix-dns]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[fix-dns]${NC} $*" >&2; }
log_error() { echo -e "${RED}[fix-dns]${NC} $*" >&2; }
log_debug() { echo -e "${BLUE}[fix-dns]${NC} $*" >&2; }

RESOLVED_CONF="/etc/systemd/resolved.conf"
BACKUP_FILE="/etc/systemd/resolved.conf.backup"

show_help() {
  cat << EOF
用法：$(basename "$0") [选项]

解决 systemd-resolved 占用 53 端口问题，使 AdGuard Home 等 DNS 服务可正常运行。

选项:
  --check     检查 53 端口占用情况
  --apply     应用修复（禁用 systemd-resolved 的 53 端口）
  --restore   恢复原始配置
  --status    显示当前 DNS 配置状态
  --help, -h  显示此帮助信息

示例:
  $(basename "$0") --check    # 检查端口占用
  $(basename "$0") --apply    # 应用修复
  $(basename "$0") --restore  # 恢复配置

注意：
  - 需要 root 权限
  - 应用修复后需要重启 systemd-resolved 服务
  - 建议在应用前备份当前配置

EOF
}

check_port_53() {
  log_info "Checking port 53 usage..."
  
  if command -v ss &> /dev/null; then
    ss -tulnp | grep ':53' || {
      log_info "Port 53 is not in use"
      return 0
    }
  elif command -v netstat &> /dev/null; then
    netstat -tulnp | grep ':53' || {
      log_info "Port 53 is not in use"
      return 0
    }
  else
    log_warn "Neither ss nor netstat available"
    return 1
  fi
  
  log_warn "Port 53 is in use"
  
  # Check if systemd-resolved is the culprit
  if systemctl is-active --quiet systemd-resolved; then
    log_info "systemd-resolved is running and may be using port 53"
  fi
}

apply_fix() {
  log_info "Applying fix for systemd-resolved..."
  
  # Check if running as root
  if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
  fi
  
  # Backup current configuration
  if [[ -f "$RESOLVED_CONF" ]] && [[ ! -f "$BACKUP_FILE" ]]; then
    log_info "Backing up current configuration to $BACKUP_FILE"
    cp "$RESOLVED_CONF" "$BACKUP_FILE"
  elif [[ -f "$BACKUP_FILE" ]]; then
    log_warn "Backup already exists, skipping backup"
  fi
  
  # Create or modify resolved.conf
  log_info "Modifying $RESOLVED_CONF..."
  
  # Ensure [Resolve] section exists
  if ! grep -q '^\[Resolve\]' "$RESOLVED_CONF" 2>/dev/null; then
    echo "[Resolve]" | tee -a "$RESOLVED_CONF" > /dev/null
  fi
  
  # Set DNSStubListener to no (disables port 53)
  if grep -q '^DNSStubListener=' "$RESOLVED_CONF" 2>/dev/null; then
    sed -i 's/^DNSStubListener=.*/DNSStubListener=no/' "$RESOLVED_CONF"
  else
    echo "DNSStubListener=no" | tee -a "$RESOLVED_CONF" > /dev/null
  fi
  
  # Set alternative DNS port (optional, for fallback)
  if ! grep -q '^DNSStubListenerExtra=' "$RESOLVED_CONF" 2>/dev/null; then
    echo "# DNSStubListenerExtra=127.0.0.53:5353" | tee -a "$RESOLVED_CONF" > /dev/null
  fi
  
  # Restart systemd-resolved
  log_info "Restarting systemd-resolved..."
  systemctl restart systemd-resolved || {
    log_error "Failed to restart systemd-resolved"
    return 1
  }
  
  # Update resolv.conf symlink
  log_info "Updating /etc/resolv.conf symlink..."
  rm -f /etc/resolv.conf
  ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
  
  # Verify fix
  sleep 2
  log_info "Verifying fix..."
  if ss -tuln | grep -q ':53 '; then
    log_warn "Port 53 is still in use. You may need to reboot."
  else
    log_info "✓ Port 53 is now free"
  fi
  
  log_info ""
  log_info "Fix applied successfully!"
  log_info "You can now start AdGuard Home or other DNS services."
  log_info ""
  log_info "To restore original configuration, run:"
  log_info "  $(basename "$0") --restore"
}

restore_config() {
  log_info "Restoring original configuration..."
  
  if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
  fi
  
  if [[ ! -f "$BACKUP_FILE" ]]; then
    log_error "No backup found at $BACKUP_FILE"
    exit 1
  fi
  
  # Restore configuration
  cp "$BACKUP_FILE" "$RESOLVED_CONF"
  log_info "Configuration restored from backup"
  
  # Restart systemd-resolved
  log_info "Restarting systemd-resolved..."
  systemctl restart systemd-resolved || {
    log_error "Failed to restart systemd-resolved"
    return 1
  }
  
  # Restore resolv.conf symlink
  rm -f /etc/resolv.conf
  ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
  
  log_info "✓ Original configuration restored"
}

show_status() {
  log_info "DNS Configuration Status"
  log_info "========================"
  log_info ""
  
  # Check systemd-resolved status
  log_info "systemd-resolved service:"
  systemctl status systemd-resolved --no-pager -l || true
  log_info ""
  
  # Check port 53
  log_info "Port 53 usage:"
  if command -v ss &> /dev/null; then
    ss -tulnp | grep ':53' || log_info "  Port 53 is free"
  fi
  log_info ""
  
  # Check current DNS servers
  log_info "Current DNS servers:"
  if [[ -f /etc/resolv.conf ]]; then
    grep -E '^nameserver' /etc/resolv.conf || log_info "  No nameservers configured"
  fi
  log_info ""
  
  # Check resolved.conf
  log_info "resolved.conf configuration:"
  if [[ -f "$RESOLVED_CONF" ]]; then
    grep -E '^(DNS|DNSStub)' "$RESOLVED_CONF" || log_info "  No custom DNS settings"
  fi
  log_info ""
  
  # Check for backup
  if [[ -f "$BACKUP_FILE" ]]; then
    log_info "Backup exists: $BACKUP_FILE"
  else
    log_info "No backup found"
  fi
}

# Parse arguments
if [[ $# -eq 0 ]]; then
  show_help
  exit 0
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check)
      check_port_53
      shift
      ;;
    --apply)
      apply_fix
      shift
      ;;
    --restore)
      restore_config
      shift
      ;;
    --status)
      show_status
      shift
      ;;
    --help|-h)
      show_help
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
done
