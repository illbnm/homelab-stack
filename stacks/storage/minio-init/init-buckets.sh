#!/bin/sh
set -e

echo "[minio-init] Waiting for MinIO to be ready..."
until mc alias set local http://minio:9000 "${MINIO_ROOT_USER}" "${MINIO_ROOT_PASSWORD}" 2>/dev/null; do
  echo "[minio-init] MinIO not ready, retrying in 5s..."
  sleep 5
done

echo "[minio-init] MinIO ready. Creating buckets..."

# Create default buckets
for bucket in nextcloud-files backups media documents; do
  if mc ls local/${bucket} >/dev/null 2>&1; then
    echo "[minio-init] Bucket ${bucket} already exists, skipping"
  else
    mc mb local/${bucket}
    echo "[minio-init] Created bucket: ${bucket}"
  fi
done

# Set versioning on critical buckets
mc version enable local/nextcloud-files
mc version enable local/backups

echo "[minio-init] Bucket initialization complete"
