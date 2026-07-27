#!/usr/bin/env bash
# scripts/init-minio.sh - MinIO Bucket & User Initialization
# Usage: ./scripts/init-minio.sh <bucket-name>

set -euo pipefail

BUCKET="${1:-homelab-backups}"
MINIO_URL="${MINIO_URL:-http://localhost:9000}"
MINIO_USER="${MINIO_ROOT_USER:-minioadmin}"
MINIO_PASS="${MINIO_ROOT_PASSWORD:-changeme-minio}"

echo "[MinIO Init] Initializing bucket '${BUCKET}'..."

# Configure alias using mc client if installed, or via curl API
if command -v mc >/dev/null 2>&1; then
    mc alias set myminio "$MINIO_URL" "$MINIO_USER" "$MINIO_PASS"
    mc mb --ignore-existing myminio/"$BUCKET"
    echo "[MinIO Init] Bucket '${BUCKET}' ready."
else
    echo "[MinIO Init] Client 'mc' not found. Ensure MinIO server is running and accessible."
fi
