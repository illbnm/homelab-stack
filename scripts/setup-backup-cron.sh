#!/usr/bin/env bash
# scripts/setup-backup-cron.sh
# Configures daily 2:00 AM automated backup job via system crontab

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BACKUP_SCRIPT="${SCRIPT_DIR}/backup.sh"

CRON_JOB="0 2 * * * ${BACKUP_SCRIPT} --target all >> /var/log/homelab-backup.log 2>&1"

(crontab -l 2>/dev/null | grep -Fv "${BACKUP_SCRIPT}"; echo "${CRON_JOB}") | crontab -

echo "[cron] Scheduled automated daily backup at 2:00 AM: ${CRON_JOB}"
