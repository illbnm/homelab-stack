#!/bin/bash
# MinIO initialization script - creates default bucket

set -e

if [ -z "$MC_HOSTS_minio" ]; then
    echo "Configuring MinIO alias..."
    mc alias set minio http://minio:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD"
fi

# Check if bucket already exists
if ! mc ls minio/"$MINIO_DEFAULT_BUCKET" 2>/dev/null; then
    echo "Creating default bucket: $MINIO_DEFAULT_BUCKET..."
    mc mb minio/"$MINIO_DEFAULT_BUCKET"
    # Make it private by default (change to public if needed)
    mc policy set private minio/"$MINIO_DEFAULT_BUCKET"
    echo "Bucket created successfully."
else
    echo "Bucket $MINIO_DEFAULT_BUCKET already exists."
fi
