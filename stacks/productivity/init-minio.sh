#!/bin/sh
# =============================================================================
# Initialize MinIO bucket for Outline file storage
# Run once after MinIO starts: docker exec outline-minio sh /init-minio.sh
# =============================================================================
set -e

# Wait for MinIO to be ready
until curl -sf http://localhost:9000/minio/health/live; do
  echo "Waiting for MinIO..."
  sleep 2
done

# Install mc if not present
if ! command -v mc > /dev/null 2>&1; then
  curl -sL https://dl.min.io/client/mc/release/linux-amd64/mc -o /usr/local/bin/mc
  chmod +x /usr/local/bin/mc
fi

# Configure alias
mc alias set local http://localhost:9000 "${MINIO_ROOT_USER:-minioadmin}" "${MINIO_ROOT_PASSWORD}"

# Create bucket if not exists
mc mb --ignore-existing local/outline

# Set bucket policy (private by default — Outline handles auth)
echo "[init-minio] Bucket 'outline' created successfully"
