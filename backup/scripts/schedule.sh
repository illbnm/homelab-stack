#!/bin/bash
# Cron scheduler for automated backups
# Install: Copy to /etc/cron.d/backup-cron or use docker scheduler

# Backup container runs this script every hour
# It checks if it's time to run the backup based on cron expressions

source /etc/environment 2>/dev/null || true

# Get current time
CURRENT_HOUR=$(date +%H)
CURRENT_MINUTE=$(date +%M)
CURRENT_DOW=$(date +%u)  # 1=Monday, 7=Sunday

# Check incremental backup time (default: 2:00)
if [ "$CURRENT_HOUR" = "02" ] && [ "$CURRENT_MINUTE" = "00" ]; then
    /scripts/backup.sh backup
fi

# Check full backup time (Sunday 3:00)
if [ "$CURRENT_HOUR" = "03" ] && [ "$CURRENT_MINUTE" = "00" ] && [ "$CURRENT_DOW" = "7" ]; then
    /scripts/backup.sh backup --full
fi