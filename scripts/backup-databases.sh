#!/bin/bash
set -e

# --- Configuration ---
BACKUP_DIR="/backups" # Directory inside the container where backups will be stored temporarily
HOST_BACKUP_DIR="./backups" # Directory on the host where final backups will be saved
RETENTION_DAYS=7 # Number of days to retain backups
MINIO_UPLOAD=false # Set to true to enable MinIO upload (requires MinIO client and config)
MINIO_BUCKET="homelab-backups" # MinIO bucket name
MINIO_ENDPOINT="http://minio:9000" # MinIO endpoint (e.g., http://minio:9000)
MINIO_ACCESS_KEY="your_minio_access_key" # MinIO access key
MINIO_SECRET_KEY="your_minio_secret_key" # MinIO secret key

# --- Load Environment Variables ---
# This script is intended to be run from the host, so it sources the .env file.
if [ -f ./.env ]; then
    echo "Loading environment variables from ./.env"
    export $(grep -v '^#' ./.env | xargs -d '\n')
else
    echo "Error: ./.env file not found. Please create one based on .env.example."
    exit 1
fi

# Ensure required passwords are set
if [ -z "${POSTGRES_ROOT_PASSWORD}" ]; then echo "POSTGRES_ROOT_PASSWORD not set!"; exit 1; fi
if [ -z "${REDIS_PASSWORD}" ]; then echo "REDIS_PASSWORD not set!"; exit 1; fi
if [ -z "${MARIADB_ROOT_PASSWORD}" ]; then echo "MARIADB_ROOT_PASSWORD not set!"; exit 1; fi

# --- Create Host Backup Directory ---
mkdir -p "${HOST_BACKUP_DIR}"

# --- PostgreSQL Backup ---
echo "Starting PostgreSQL backup..."
PG_BACKUP_FILE="postgres_dumpall_$(date +%Y%m%d_%H%M%S).sql"
docker compose exec -T postgres pg_dumpall -U postgres > "${HOST_BACKUP_DIR}/${PG_BACKUP_FILE}"
echo "PostgreSQL backup completed: ${HOST_BACKUP_DIR}/${PG_BACKUP_FILE}"

# --- Redis Backup ---
echo "Starting Redis backup..."
# Trigger BGSAVE to ensure data is written to disk
docker compose exec -T redis redis-cli -a "${REDIS_PASSWORD}" BGSAVE
# Wait a bit for BGSAVE to complete (can be improved with actual monitoring)
sleep 5
# Copy the dump.rdb file from the Redis container
REDIS_BACKUP_FILE="redis_dump_$(date +%Y%m%d_%H%M%S).rdb"
docker compose cp redis:/data/dump.rdb "${HOST_BACKUP_DIR}/${REDIS_BACKUP_FILE}"
echo "Redis backup completed: ${HOST_BACKUP_DIR}/${REDIS_BACKUP_FILE}"

# --- MariaDB Backup ---
echo "Starting MariaDB backup..."
MARIADB_BACKUP_FILE="mariadb_dumpall_$(date +%Y%m%d_%H%M%S).sql"
docker compose exec -T mariadb sh -c 'exec mariadb-dump -u root -p"$MARIADB_ROOT_PASSWORD" --all-databases' > "${HOST_BACKUP_DIR}/${MARIADB_BACKUP_FILE}"
echo "MariaDB backup completed: ${HOST_BACKUP_DIR}/${MARIADB_BACKUP_FILE}"

# --- Compress Backups ---
echo "Compressing backups..."
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
ARCHIVE_NAME="databases_backup_${TIMESTAMP}.tar.gz"
tar -czf "${HOST_BACKUP_DIR}/${ARCHIVE_NAME}" -C "${HOST_BACKUP_DIR}" \
    "${PG_BACKUP_FILE}" "${REDIS_BACKUP_FILE}" "${MARIADB_BACKUP_FILE}"

echo "Compressed backup created: ${HOST_BACKUP_DIR}/${ARCHIVE_NAME}"

# --- Clean up individual backup files ---
echo "Cleaning up individual backup files..."
rm "${HOST_BACKUP_DIR}/${PG_BACKUP_FILE}"
rm "${HOST_BACKUP_DIR}/${REDIS_BACKUP_FILE}"
rm "${HOST_BACKUP_DIR}/${MARIADB_BACKUP_FILE}"
echo "Individual backup files removed."

# --- Retention Policy ---
echo "Applying retention policy (keeping last ${RETENTION_DAYS} days)..."
find "${HOST_BACKUP_DIR}" -name "databases_backup_*.tar.gz" -mtime +${RETENTION_DAYS} -delete
echo "Old backups removed."

# --- MinIO Upload (Optional) ---
if [ "$MINIO_UPLOAD" = true ]; then
    echo "Uploading backup to MinIO..."
    # Ensure mc client is installed and configured
    # Example: docker run --rm -it -v ~/.mc:/root/.mc minio/mc config host add myminio ${MINIO_ENDPOINT} ${MINIO_ACCESS_KEY} ${MINIO_SECRET_KEY}
    # For a simple script, you might need to install 'mc' or use 'awscli' if MinIO is S3 compatible.
    # For this example, we'll assume 'mc' is available and configured.
    # If running from a container, ensure mc is installed in that container.
    
    # Example using 'mc' client (requires mc to be installed on the host or in a utility container)
    # mc config host add myminio ${MINIO_ENDPOINT} ${MINIO_ACCESS_KEY} ${MINIO_SECRET_KEY} --api S3v4
    # mc cp "${HOST_BACKUP_DIR}/${ARCHIVE_NAME}" myminio/${MINIO_BUCKET}/
    
    # A more robust way for a Docker Compose setup would be to use a dedicated backup container
    # or pass credentials directly to a temporary 'mc' container.
    
    echo "MinIO upload feature is not fully implemented in this script for direct execution."
    echo "Please configure 'mc' client or use an alternative S3 client to upload '${HOST_BACKUP_DIR}/${ARCHIVE_NAME}' to MinIO bucket '${MINIO_BUCKET}'."
fi

echo "Database backup process completed successfully."
