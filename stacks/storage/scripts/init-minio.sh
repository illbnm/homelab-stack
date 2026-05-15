#!/bin/bash
# =============================================================================
# MinIO Initialization Script
# Creates default buckets and sets policies
# =============================================================================
set -euo pipefail

MC_ALIAS="${MINIO_ALIAS:-homelab}"
MINIO_ENDPOINT="${MINIO_ENDPOINT:-http://minio:9000}"
MINIO_ROOT_USER="${MINIO_ROOT_USER:-minioadmin}"
MINIO_ROOT_PASSWORD="${MINIO_ROOT_PASSWORD:-minioadmin}"

echo "[init-minio] Waiting for MinIO to be ready..."
until mc alias set "$MC_ALIAS" "$MINIO_ENDPOINT" "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" 2>/dev/null; do
    echo "[init-minio] MinIO not ready, retrying in 5s..."
    sleep 5
done

echo "[init-minio] MinIO is ready. Creating default buckets..."

DEFAULT_BUCKETS="${MINIO_DEFAULT_BUCKETS:-nextcloud,backups,media}"
IFS=',' read -ra BUCKETS <<< "$DEFAULT_BUCKETS"
for bucket in "${BUCKETS[@]}"; do
    bucket=$(echo "$bucket" | xargs)
    if ! mc ls "$MC_ALIAS/$bucket" >/dev/null 2>&1; then
        mc mb "$MC_ALIAS/$bucket"
        echo "[init-minio] Created bucket: $bucket"
    else
        echo "[init-minio] Bucket already exists: $bucket"
    fi
done

if [ "${MINIO_MEDIA_PUBLIC:-false}" = "true" ]; then
    mc anonymous set download "$MC_ALIAS/media" 2>/dev/null || true
    echo "[init-minio] Set public download policy on media bucket"
fi

echo "[init-minio] Initialization complete."
