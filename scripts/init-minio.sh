#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — MinIO Initialization Script
# Creates default bucket and access policy.
# Usage: ./scripts/init-minio.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")
if [ -f "$ROOT_DIR/.env" ]; then
  set -a; source "$ROOT_DIR/.env"; set +a
fi

GREEN='\033[0;32m'; RESET='\033[0m'
log_ok() { echo -e "${GREEN}[OK]${RESET} $*"; }

MINIO_HOST="${MINIO_HOST:-minio}"
MINIO_PORT="${MINIO_PORT:-9000}"
MINIO_USER="${MINIO_ROOT_USER:-minioadmin}"
MINIO_PASS="${MINIO_ROOT_PASSWORD:-minioadmin}"

# Wait for MinIO
echo "Waiting for MinIO..."
for i in $(seq 1 15); do
  if curl -sf http://${MINIO_HOST}:${MINIO_PORT}/minio/health/live > /dev/null 2>&1; then
    log_ok "MinIO is ready"
    break
  fi
  sleep 2
done

# Configure mc alias
mc alias set myminio http://${MINIO_HOST}:${MINIO_PORT} ${MINIO_USER} ${MINIO_PASS} 2>/dev/null

# Create default buckets
mc mb --ignore-existing myminio/backups 2>/dev/null && log_ok "Bucket: backups"
mc mb --ignore-existing myminio/media 2>/dev/null && log_ok "Bucket: media"
mc mb --ignore-existing myminio/documents 2>/dev/null && log_ok "Bucket: documents"

# Set bucket policies
mc anonymous set download myminio/media 2>/dev/null && log_ok "Policy: media → public download"

log_ok "MinIO initialization complete"