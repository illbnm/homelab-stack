#!/usr/bin/env bash
# Usage: ./stacks/storage/scripts/init-minio-buckets.sh
# Idempotently initializes default MinIO buckets for Nextcloud, Outline, and Backups.
set -euo pipefail

MINIO_ENDPOINT="${MINIO_ENDPOINT:-http://127.0.0.1:9000}"
MINIO_ROOT_USER="${MINIO_ROOT_USER:?MINIO_ROOT_USER is required}"
MINIO_ROOT_PASSWORD="${MINIO_ROOT_PASSWORD:?MINIO_ROOT_PASSWORD is required}"

mc alias set homelab "$MINIO_ENDPOINT" "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD"
for bucket in nextcloud-storage outline-assets homelab-backups; do
  mc mb --ignore-existing "homelab/${bucket}"
  echo "[OK] Bucket ensured: homelab/${bucket}"
done
