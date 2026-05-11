#!/bin/sh
# backup.sh — Automated backup with restic + Docker volume snapshot
set -e

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG="/var/log/backup_${TIMESTAMP}.log"

echo "[${TIMESTAMP}] Starting backup..." | tee -a "$LOG"

# 1. Init repo if needed
restic snapshots --json >/dev/null 2>&1 || restic init

# 2. Backup /data directory
restic backup /data \
  --tag "scheduled-${TIMESTAMP}" \
  --exclude="*.tmp" \
  --exclude="cache/" \
  --exclude=".cache/" 2>&1 | tee -a "$LOG"

# 3. Forget old snapshots (keep last 7 daily, 4 weekly, 12 monthly)
restic forget \
  --keep-daily 7 \
  --keep-weekly 4 \
  --keep-monthly 12 \
  --prune 2>&1 | tee -a "$LOG"

# 4. Check repo integrity (weekly on Sundays)
if [ "$(date +%u)" = "7" ]; then
  restic check --read-data 2>&1 | tee -a "$LOG"
fi

echo "[$(date +%Y%m%d_%H%M%S)] Backup complete" | tee -a "$LOG"
