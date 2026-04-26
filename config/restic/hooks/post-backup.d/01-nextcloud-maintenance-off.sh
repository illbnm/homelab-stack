#!/usr/bin/env bash
# =============================================================================
# Post-backup hook: Disable Nextcloud maintenance mode
# Re-enables normal Nextcloud operation after backup completes.
# =============================================================================
set -euo pipefail

CONTAINER="nextcloud"

if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
  echo "[hook] Disabling Nextcloud maintenance mode..."
  docker exec -u www-data "${CONTAINER}" php occ maintenance:mode --off 2>/dev/null || true
else
  echo "[hook] Nextcloud container not running — skipping"
fi
