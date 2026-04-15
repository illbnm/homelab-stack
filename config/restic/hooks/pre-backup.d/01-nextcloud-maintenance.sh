#!/usr/bin/env bash
# =============================================================================
# Pre-backup hook: Enable Nextcloud maintenance mode
# Ensures consistent file-level backups by pausing Nextcloud writes.
# =============================================================================
set -euo pipefail

CONTAINER="nextcloud"

if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
  echo "[hook] Enabling Nextcloud maintenance mode..."
  docker exec -u www-data "${CONTAINER}" php occ maintenance:mode --on 2>/dev/null || true
else
  echo "[hook] Nextcloud container not running — skipping"
fi
