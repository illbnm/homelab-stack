 ```diff
--- a/scripts/backup.sh
+++ b/scripts/backup.sh
@@ -0,0 +1,420 @@
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
+# Default values
+: "${BACKUP_TARGET:=local}"
+: "${BACKUP_DIR:=${PROJECT_ROOT}/backups}"
+: "${BACKUP_RETENTION_DAYS:=30}"
+: "${BACKUP_ENCRYPT_PASSWORD:=}"
+: "${NTFY_URL:=}"
+: "${NTFY_TOPIC:=homelab-backup}"
+: "${MINIO_ENDPOINT:=}"
+: "${MINIO_ACCESS_KEY:=}"
+: "${MINIO_SECRET_KEY:=}"
+: "${MINIO_BUCKET:=homelab-backups}"
+: "${B2_ACCOUNT_ID:=}"
+: "${B2_ACCOUNT_KEY:=}"
+: "${B2_BUCKET:=homelab-backups}"
+: "${SFTP_HOST:=}"
+: "${SFTP_PORT:=22}"
+: "${SFTP_USER:=}"
+: "${SFTP_KEY:=}"
+: "${SFTP_PATH:=/backups}"
+: "${R2_ENDPOINT:=}"
+: "${R2_ACCESS_KEY_ID:=}"
+: "${R2_SECRET_ACCESS_KEY:=}"
+: "${R2_BUCKET:=homelab-backups}"
+
+# Restic configuration
+RESTIC_REPOSITORY="${BACKUP_DIR}/restic-repo"
+RESTIC_PASSWORD="${BACKUP_ENCRYPT_PASSWORD:-changeme}"
+export RESTIC_REPOSITORY RESTIC_PASSWORD
+
+# Colors for output
+RED='\033[0;31m'
+GREEN='\033[0;32m'
+YELLOW='\033[1;33m'
+BLUE='\033[0;34m'
+NC='\033[0m' # No Color
+
+# Logging
+LOG_DIR="${PROJECT_ROOT}/logs"
+LOG_FILE="${LOG_DIR}/backup-$(date +%Y%m%d-%H%M%S).log"
+mkdir -p "${LOG_DIR}"
+
+exec > >(tee -a "${LOG_FILE}")
+exec 2>&1
+
+# ============================================
+# Helper Functions
+# ============================================
+
+log_info() {
+    echo -e "${GREEN}[INFO]${NC} $*"
+}
+
+log_warn() {
+    echo -e "${YELLOW}[WARN]${NC} $*"
+}
+
+log_error() {
+    echo -e "${RED}[ERROR]${NC} $*"
+}
+
+log_debug() {
+    echo -e "${BLUE}[DEBUG]${NC} $*"
+}
+
+notify() {
+    local status="$1"
+    local message="$2"
+    
+    if [[ -n "${NTFY_URL}" ]]; then
+        local title="Backup ${status}"
+        local priority="default"
+        [[ "${status}" == "FAILED" ]] && priority="urgent"
+        
+        curl -s -X POST "${NTFY_URL}/${NTFY_TOPIC}" \
+            -H "Title: ${title}" \
+            -H "Priority: ${priority}" \
+            -d "${message}" > /dev/null 2>&1 || true
+    fi
+}
+
+get_stack_volumes() {
+    local stack="$1"
+    local volumes=()
+    
+    case "${stack}" in
+        base)
+            volumes=("traefik-data" "portainer-data")
+            ;;
+        media)
+            volumes=("jellyfin-config" "sonarr-config" "radarr-config" "prowlarr-config" "qbittorrent-config" "jellyseerr-config" "media-downloads" "media-movies" "media-tv")
+            ;;
+        storage)
+            volumes=("nextcloud-data" "minio-data" "filebrowser-data" "syncthing-data")
+            ;;
+        monitoring)
+            volumes=("grafana-data" "prometheus-data" "loki-data" "alertmanager-data" "uptime-kuma-data")
+            ;;
+        network)
+            volumes=("adguard-data" "wireguard-data" "nginxpm-data")
+            ;;
+        productivity)
+            volumes=("gitea-data" "vaultwarden-data" "outline-data" "stirlingpdf-data")
+            ;;
+        ai)
+            volumes=("ollama-data" "openwebui-data" "localai-data" "n8n-data")
+            ;;
+        home-automation)
+            volumes=("hass-config" "nodered-data" "mosquitto-data" "zigbee2mqtt-data" "esphome-data")
+            ;;
+        sso)
+            volumes=("authentik-data" "authentik-postgres-data" "authentik-redis-data")
+            ;;
+        dashboard)
+            volumes=("homepage-data" "heimdall-data")
+            ;;
+        notifications)
+            volumes=("gotify-data" "ntfy-data" "apprise-data")
+            ;;
+        *)
+            log_error "Unknown stack: ${stack}"
+            return 1
+            ;;
+    esac
+    
+    echo "${volumes[@]}"
+}
+
+get_all_stacks() {
+    echo "base media storage monitoring network productivity ai home-automation sso dashboard notifications"
+}
+
+setup_restic_repo() {
+    case "${BACKUP_TARGET}" in
+        s3|minio)
+            export AWS_ACCESS_KEY_ID="${MINIO_ACCESS_KEY}"
+            export AWS_SECRET_ACCESS_KEY="${MINIO_SECRET_KEY}"
+            if [[ -n "${MINIO_ENDPOINT}" ]]; then
+                export AWS_ENDPOINT_URL="${MINIO_ENDPOINT}"
+            fi
+            RESTIC_REPOSITORY="s3:${MINIO_ENDPOINT}/${MINIO_BUCKET}"
+            ;;
+        b2)
+            export B2_ACCOUNT_ID
+            export B2_ACCOUNT_KEY
+            RESTIC_REPOSITORY="b2:${B2_BUCKET}"
+            ;;
+        sftp)
+            export RESTIC_REPOSITORY_SFTP="${SFTP_USER}@${SFTP_HOST}:${SFTP_PATH}"
+            RESTIC_REPOSITORY="sftp:${SFTP_USER}@${SFTP_HOST}:${SFTP_PATH}"
+            if [[ -n "${SFTP_KEY}" && -f "${SFTP_KEY}" ]]; then
+                export RESTIC_REPOSITORY_SFTP_IDENTITY="${SFTP_KEY}"
+            fi
+            ;;
+        r2)
+            export AWS_ACCESS_KEY_ID="${R2_ACCESS_KEY_ID}"
+            export AWS_SECRET_ACCESS_KEY="${R2_SECRET_ACCESS_KEY}"
+            export AWS_ENDPOINT_URL="${R2_ENDPOINT}"
+            REST