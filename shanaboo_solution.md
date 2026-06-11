 ```diff
--- /dev/null
+++ b/scripts/backup.sh
@@ -0,0 +1,462 @@
+#!/usr/bin/env bash
+set -euo pipefail
+
+# ============================================
+# HomeLab Stack Backup & Recovery Script
+# Implements 3-2-1 backup strategy
+# ============================================
+
+SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
+PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
+ENV_FILE="${PROJECT_ROOT}/.env"
+
+# Load environment variables
+if [[ -f "${ENV_FILE}" ]]; then
+    set -a
+    # shellcheck source=/dev/null
+    source "${ENV_FILE}"
+    set +a
+fi
+
+# Default configuration
+: "${BACKUP_TARGET:=local}"
+: "${BACKUP_LOCAL_DIR:=${PROJECT_ROOT}/backups}"
+: "${BACKUP_RETENTION_DAYS:=30}"
+: "${BACKUP_ENCRYPT_KEY:=}"
+: "${NTFY_URL:=}"
+: "${NTFY_TOPIC:=homelab-backup}"
+: "${MINIO_ENDPOINT:=}"
+: "${MINIO_BUCKET:=homelab-backups}"
+: "${MINIO_ACCESS_KEY:=}"
+: "${MINIO_SECRET_KEY:=}"
+: "${B2_ACCOUNT_ID:=}"
+: "${B2_ACCOUNT_KEY:=}"
+: "${B2_BUCKET:=homelab-backups}"
+: "${SFTP_HOST:=}"
+: "${SFTP_PORT:=22}"
+: "${SFTP_USER:=}"
+: "${SFTP_PATH:=/backups/homelab}"
+: "${R2_ENDPOINT:=}"
+: "${R2_BUCKET:=homelab-backups}"
+: "${R2_ACCESS_KEY_ID:=}"
+: "${R2_SECRET_ACCESS_KEY:=}"
+
+# Backup metadata
+TIMESTAMP=$(date +%Y%m%d_%H%M%S)
+BACKUP_NAME="homelab_${TIMESTAMP}"
+DRY_RUN=false
+RESTORE_MODE=false
+LIST_MODE=false
+VERIFY_MODE=false
+RESTORE_BACKUP_ID=""
+TARGET_STACK="all"
+
+# Volume mappings for each stack
+declare -A STACK_VOLUMES
+STACK_VOLUMES=(
+    ["base"]="traefik-data portainer-data"
+    ["media"]="jellyfin-data sonarr-data radarr-data prowlarr-data qbittorrent-data jellyseerr-data"
+    ["storage"]="nextcloud-data nextcloud-db minio-data filebrowser-data syncthing-data"
+    ["monitoring"]="grafana-data prometheus-data loki-data alertmanager-data uptime-kuma-data"
+    ["network"]="adguard-data wireguard-data"
+    ["productivity"]="gitea-data gitea-db vaultwarden-data outline-data outline-db stirling-pdf-data"
+    ["ai"]="ollama-data open-webui-data localai-data n8n-data"
+    ["home-automation"]="home-assistant-data node-red-data mosquitto-data zigbee2mqtt-data esphome-data"
+    ["sso"]="authentik-data authentik-db authentik-redis"
+    ["dashboard"]="homepage-data heimdall-data"
+    ["notifications"]="gotify-data ntfy-data apprise-data"
+)
+
+# ============================================
+# Utility Functions
+# ============================================
+
+log() {
+    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
+}
+
+error() {
+    log "ERROR: $*" >&2
+}
+
+warn() {
+    log "WARN: $*" >&2
+}
+
+success() {
+    log "SUCCESS: $*"
+}
+
+notify() {
+    local status="$1"
+    local message="$2"
+    
+    if [[ -n "${NTFY_URL}" ]]; then
+        local title="HomeLab Backup"
+        local priority="default"
+        [[ "${status}" == "failed" ]] && priority="high"
+        [[ "${status}" == "success" ]] && priority="default"
+        
+        curl -s -o /dev/null -w "%{http_code}" \
+            -H "Title: ${title}" \
+            -H "Priority: ${priority}" \
+            -H "Tags: backup,${status}" \
+            -d "${message}" \
+            "${NTFY_URL}/${NTFY_TOPIC}" >/dev/null 2>&1 || true
+    fi
+}
+
+die() {
+    error "$*"
+    notify "failed" "Backup failed: $*"
+    exit 1
+}
+
+# ============================================
+# Docker Volume Helpers
+# ============================================
+
+get_volume_path() {
+    local volume_name="$1"
+    docker volume inspect -f '{{ .Mountpoint }}' "${volume_name}" 2>/dev/null || echo ""
+}
+
+volume_exists() {
+    local volume_name="$1"
+    docker volume ls -q | grep -q "^${volume_name}$"
+}
+
+get_all_volumes() {
+    local volumes=""
+    for stack in "${!STACK_VOLUMES[@]}"; do
+        for vol in ${STACK_VOLUMES[$stack]}; do
+            volumes="${volumes} ${vol}"
+        done
+    done
+    echo "${volumes}" | tr ' ' '\n' | sort -u | tr '\n' ' ' | sed 's/^ *//;s/ *$//'
+}
+
+get_stack_volumes() {
+    local stack="$1"
+    if [[ -n "${STACK_VOLUMES[$stack]:-}" ]]; then
+        echo "${STACK_VOLUMES[$stack]}"
+    else
+        echo ""
+    fi
+}
+
+# ============================================
+# Backup Destination Handlers
+# ============================================
+
+backup_to_local() {
+    local backup_path="${BACKUP_LOCAL_DIR}/${BACKUP_NAME}"
+    mkdir -p "${backup_path}"
+    echo "${backup_path}"
+}
+
+backup_to_s3() {
+    local backup_path="s3:${MINIO_BUCKET}/homelab-backups/${BACKUP_NAME}"
+    echo "${backup_path}"
+}
+
+backup_to_b2() {
+    local backup_path="b2:${B2_BUCKET}/homelab-backups/${BACKUP_NAME}"
+    echo "${backup_path}"
+}
+
+backup_to_sftp() {
+    local backup_path="sftp:${SFTP_USER}@${SFTP_HOST}:${SFTP_PORT}${SFTP_PATH}/${BACKUP_NAME}"
+    echo "${backup_path}"
+}
+
+backup_to_r2() {
+    local backup_path="s3:${R2_BUCKET}/homelab-backups/${BACKUP_NAME}"
+    echo "${backup_path}"
+}
+
+get_backup_destination() {
+    case "${BACKUP_TARGET}" in
+        local)
+            backup_to_local
+            ;;
+        s3|minio)
+            backup_to_s3
+            ;;
+        b2