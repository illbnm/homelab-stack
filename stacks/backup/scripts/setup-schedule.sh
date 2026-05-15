#!/usr/bin/env bash
# =============================================================================
# HomeLab Backup — Schedule Setup
# Sets up automated daily backups via crontab or systemd timer
#
# Usage:
#   setup-schedule.sh [--method crontab|systemd] [--time HH:MM]
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="${SCRIPT_DIR}/../.."
BACKUP_SCRIPT="${SCRIPT_DIR}/backup.sh"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

log_info()  { echo -e "${GREEN}[schedule]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[schedule]${NC} $*"; }
log_error() { echo -e "${RED}[schedule]${NC} $*" >&2; }
log_step()  { echo -e "\n${BLUE}${BOLD}==> $*${NC}"; }

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
METHOD="auto"
BACKUP_HOUR="02"
BACKUP_MINUTE="00"
NOTIFY_FLAG="--notify"

usage() {
  cat <<EOF
HomeLab Backup Schedule Setup

Usage:
  $(basename "$0") [options]

Options:
  --method <crontab|systemd|auto>  Scheduling method (default: auto)
  --time HH:MM                     Backup time (default: 02:00)
  --no-notify                      Disable ntfy notifications
  --remove                         Remove existing schedule
  -h, --help                       Show this help

Examples:
  $(basename "$0")                          # Default: 2:00 AM daily
  $(basename "$0") --time 03:30             # Custom time
  $(basename "$0") --method systemd         # Force systemd timer
  $(basename "$0") --remove                 # Remove schedule
EOF
  exit 0
}

REMOVE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --method)     METHOD="$2"; shift 2 ;;
    --time)       BACKUP_HOUR="${2%%:*}"; BACKUP_MINUTE="${2##*:}"; shift 2 ;;
    --no-notify)  NOTIFY_FLAG=""; shift ;;
    --remove)     REMOVE=true; shift ;;
    -h|--help)    usage ;;
    *)            log_error "Unknown option: $1"; usage ;;
  esac
done

# ---------------------------------------------------------------------------
# Remove existing schedule
# ---------------------------------------------------------------------------
remove_schedule() {
  log_step "Removing backup schedule"

  # Remove crontab entry
  if crontab -l 2>/dev/null | grep -q 'homelab-backup'; then
    crontab -l 2>/dev/null | grep -v 'homelab-backup' | crontab -
    log_info "✓ Removed crontab entry"
  fi

  # Remove systemd timer
  if [[ -f /etc/systemd/system/homelab-backup.timer ]]; then
    systemctl disable --now homelab-backup.timer 2>/dev/null || true
    rm -f /etc/systemd/system/homelab-backup.{timer,service}
    systemctl daemon-reload 2>/dev/null || true
    log_info "✓ Removed systemd timer"
  fi

  log_info "Schedule removed"
}

if [[ "$REMOVE" == true ]]; then
  remove_schedule
  exit 0
fi

# ---------------------------------------------------------------------------
# Setup crontab
# ---------------------------------------------------------------------------
setup_crontab() {
  log_step "Setting up crontab schedule"
  local cron_line="${BACKUP_MINUTE} ${BACKUP_HOUR} * * * ${BACKUP_SCRIPT} --target all ${NOTIFY_FLAG} >> /var/log/homelab-backup.log 2>&1 # homelab-backup"

  # Remove existing entry if present
  local existing
  existing=$(crontab -l 2>/dev/null | grep -v 'homelab-backup' || true)

  # Add new entry
  echo "${existing}
${cron_line}" | crontab -

  log_info "✓ Crontab scheduled: ${BACKUP_HOUR}:${BACKUP_MINUTE} daily"
  log_info "  Log: /var/log/homelab-backup.log"
  crontab -l | grep 'homelab-backup'
}

# ---------------------------------------------------------------------------
# Setup systemd timer
# ---------------------------------------------------------------------------
setup_systemd() {
  log_step "Setting up systemd timer"

  # Service file
  cat > /etc/systemd/system/homelab-backup.service <<EOF
[Unit]
Description=HomeLab Backup
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
ExecStart=${BACKUP_SCRIPT} --target all ${NOTIFY_FLAG}
StandardOutput=append:/var/log/homelab-backup.log
StandardError=append:/var/log/homelab-backup.log

[Install]
WantedBy=multi-user.target
EOF

  # Timer file
  cat > /etc/systemd/system/homelab-backup.timer <<EOF
[Unit]
Description=HomeLab Backup Timer — daily at ${BACKUP_HOUR}:${BACKUP_MINUTE}

[Timer]
OnCalendar=*-*-* ${BACKUP_HOUR}:${BACKUP_MINUTE}:00
Persistent=true
RandomizedDelaySec=300

[Install]
WantedBy=timers.target
EOF

  systemctl daemon-reload
  systemctl enable --now homelab-backup.timer

  log_info "✓ Systemd timer scheduled: ${BACKUP_HOUR}:${BACKUP_MINUTE} daily"
  systemctl list-timers homelab-backup.timer --no-pager
}

# ---------------------------------------------------------------------------
# Auto-detect and setup
# ---------------------------------------------------------------------------
log_step "HomeLab Backup Schedule Setup"
log_info "Time: ${BACKUP_HOUR}:${BACKUP_MINUTE}"
log_info "Method: ${METHOD}"

case "$METHOD" in
  crontab)
    setup_crontab
    ;;
  systemd)
    if [[ $EUID -ne 0 ]]; then
      log_error "systemd timer requires root. Run with sudo."
      exit 1
    fi
    setup_systemd
    ;;
  auto)
    if [[ $EUID -eq 0 ]] && command -v systemctl &>/dev/null; then
      setup_systemd
    else
      setup_crontab
    fi
    ;;
  *)
    log_error "Unknown method: $METHOD"
    exit 1
    ;;
esac

log_step "Setup Complete"
log_info "Backup will run daily at ${BACKUP_HOUR}:${BACKUP_MINUTE}"
log_info ""
log_info "Manual commands:"
log_info "  ${BACKUP_SCRIPT} --target all --notify    # Run now"
log_info "  ${BACKUP_SCRIPT} --list                   # List backups"
log_info "  ${BACKUP_SCRIPT} --verify                 # Verify integrity"
log_info "  ${BACKUP_SCRIPT} --restore <id>           # Restore specific backup"
