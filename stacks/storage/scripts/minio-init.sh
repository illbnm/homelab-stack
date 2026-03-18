#!/bin/bash
# =============================================================================
# MinIO Initialization Script
#
# Creates default buckets after MinIO starts. Runs as an init container
# that waits for MinIO to be healthy, then configures buckets via mc client.
#
# Idempotent: safe to run multiple times (mc mb --ignore-existing).
# =============================================================================
set -euo pipefail

echo "[minio-init] Waiting for MinIO to be ready..."

# Configure mc alias (mc will retry connection internally)
mc alias set homelab http://minio:9000 "${MINIO_ROOT_USER}" "${MINIO_ROOT_PASSWORD}" --api S3v4

# Wait for MinIO to respond (max 60 seconds)
for i in $(seq 1 60); do
  if mc admin info homelab > /dev/null 2>&1; then
    echo "[minio-init] MinIO is ready"
    break
  fi
  if [ "$i" -eq 60 ]; then
    echo "[minio-init] ERROR: MinIO did not become ready in 60s" >&2
    exit 1
  fi
  sleep 1
done

# Create default buckets (idempotent)
echo "[minio-init] Creating default buckets..."

mc mb homelab/nextcloud --ignore-existing
mc mb homelab/backups --ignore-existing
mc mb homelab/media --ignore-existing
mc mb homelab/documents --ignore-existing

# Set bucket policies
# nextcloud bucket: private (default)
# backups bucket: private (default)
# media bucket: allow anonymous read (for serving media)
mc anonymous set download homelab/media 2>/dev/null || true

echo "[minio-init] Bucket list:"
mc ls homelab/

echo "[minio-init] Initialization complete"
