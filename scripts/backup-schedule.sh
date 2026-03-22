#!/usr/bin/env bash
# =============================================================================
# HomeLab Backup — Setup systemd timer for daily 2:00 AM backups
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$SCRIPT_DIR/.."
BACKUP_SCRIPT="$SCRIPT_DIR/backup.sh"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[schedule]${NC} $*"; }
log_error() { echo -e "${RED}[schedule]${NC} $*" >&2; }

# Check root
if [[ $EUID -ne 0 ]]; then
  log_error "This script must be run as root (for systemd)"
  echo "  Usage: sudo $0 [install|uninstall|status]"
  exit 1
fi

ACTION="${1:-install}"

case "$ACTION" in
  install)
    log_info "Creating systemd service..."

    cat > /etc/systemd/system/homelab-backup.service <<UNIT
[Unit]
Description=HomeLab Stack Backup
After=docker.service
Wants=docker.service

[Service]
Type=oneshot
ExecStart=$BACKUP_SCRIPT --target all
WorkingDirectory=$BASE_DIR
StandardOutput=journal
StandardError=journal
UNIT

    cat > /etc/systemd/system/homelab-backup.timer <<'TIMER'
[Unit]
Description=Daily HomeLab Stack Backup at 2:00 AM

[Timer]
OnCalendar=*-*-* 02:00:00
Persistent=true
RandomizedDelaySec=300

[Install]
WantedBy=timers.target
TIMER

    systemctl daemon-reload
    systemctl enable homelab-backup.timer
    systemctl start homelab-backup.timer

    log_info "✓ Installed and enabled"
    log_info "  Schedule: Daily at 02:00 (±5 min random delay)"
    log_info "  Service:  homelab-backup.service"
    log_info "  Timer:    homelab-backup.timer"
    echo ""
    log_info "Useful commands:"
    echo "  systemctl status homelab-backup.timer   # Check timer"
    echo "  systemctl list-timers                   # Next run time"
    echo "  journalctl -u homelab-backup -f         # Watch logs"
    echo "  systemctl start homelab-backup.service  # Manual trigger"
    ;;

  uninstall)
    log_info "Removing systemd timer..."
    systemctl stop homelab-backup.timer 2>/dev/null || true
    systemctl disable homelab-backup.timer 2>/dev/null || true
    rm -f /etc/systemd/system/homelab-backup.{service,timer}
    systemctl daemon-reload
    log_info "✓ Removed"
    ;;

  status)
    echo ""
    systemctl status homelab-backup.timer --no-pager 2>/dev/null || log_error "Timer not installed"
    echo ""
    systemctl list-timers homelab-backup.timer --no-pager 2>/dev/null || true
    ;;

  *)
    echo "Usage: $0 [install|uninstall|status]"
    exit 1
    ;;
esac
