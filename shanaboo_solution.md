 ```diff
--- a/scripts/backup.sh
+++ b/scripts/backup.sh
@@ -0,0 +1,564 @@
+#!/usr/bin/env bash
+set -euo pipefail
+
+# ============================================
+# HomeLab Stack Backup & Recovery Script
+# ============================================
+# Usage:
+#   backup.sh --target <stack|all> [options]
+#
+# Options:
+#   --target all          Backup all stack data volumes
+#   --target media        Backup only media stack
+#   --dry-run             Show what would be backed up, don't execute
+#   --restore <backup_id> Restore from specified backup
+#   --list                List all backups
+#   --verify              Verify backup integrity
+# ============================================
+
+SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
+ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
+ENV_FILE="${ROOT_DIR}/.env"
+
+# Load environment variables
+if [[ -f "${ENV_FILE}" ]]; then
+    # shellcheck source=/dev/null
+    source "${ENV_FILE}"
+fi
+
+# Default values
+BACKUP_TARGET="${BACKUP_TARGET:-local}"
+BACKUP_LOCAL_DIR="${BACKUP_LOCAL_DIR:-${ROOT_DIR}/backups}"
+BACKUP_S3_BUCKET="${BACKUP_S3_BUCKET:-}"
+BACKUP_S3_ENDPOINT="${BACKUP_S3_ENDPOINT:-}"
+BACKUP_S3_ACCESS_KEY="${BACKUP_S3_ACCESS_KEY:-}"
+BACKUP_S3_SECRET_KEY="${BACKUP_S3_SECRET_KEY:-}"
+BACKUP_B2_BUCKET="${BACKUP_B2_BUCKET:-}"
+BACKUP_B2_KEY_ID="${BACKUP_B2_KEY_ID:-}"
+BACKUP_B2_APPLICATION_KEY="${BACKUP_B2_APPLICATION_KEY:-}"
+BACKUP_SFTP_HOST="${BACKUP_SFTP_HOST:-}"
+BACKUP_SFTP_PORT="${BACKUP_SFTP_PORT:-22}"
+BACKUP_SFTP_USER="${BACKUP_SFTP_USER:-}"
+BACKUP_SFTP_KEY="${BACKUP_SFTP_KEY:-}"
+BACKUP_SFTP_PATH="${BACKUP_SFTP_PATH:-}"
+BACKUP_R2_BUCKET="${BACKUP_R2_BUCKET:-}"
+BACKUP_R2_ACCOUNT_ID="${BACKUP_R2_ACCOUNT_ID:-}"
+BACKUP_R2_ACCESS_KEY="${BACKUP_R2_ACCESS_KEY:-}"
+BACKUP_R2_SECRET_KEY="${BACKUP_R2_SECRET_KEY:-}"
+NTFY_URL="${NTFY_URL:-}"
+NTFY_TOPIC="${NTFY_TOPIC:-homelab-backups}"
+RESTIC_PASSWORD="${RESTIC_PASSWORD:-}"
+RESTIC_REST_SERVER="${RESTIC_REST_SERVER:-http://localhost:8000}"
+
+# Stack definitions
+declare -A STACK_VOLUMES
+STACK_VOLUMES=(
+    ["base"]="traefik-data portainer-data"
+    ["media"]="jellyfin-config sonarr-config radarr-config prowlarr-config qbittorrent-config jellyseerr-config"
+    ["storage"]="nextcloud-data nextcloud-db minio-data filebrowser-data syncthing-data"
+    ["monitoring"]="grafana-data prometheus-data loki-data alertmanager-data uptime-kuma-data"
+    ["network"]="adguard-data wireguard-data"
+    ["productivity"]="gitea-data vaultwarden-data outline-data stirling-pdf-data"
+    ["ai"]="ollama-data open-webui-data localai-data n8n-data"
+    ["home-automation"]="home-assistant-data node-red-data mosquitto-data zigbee2mqtt-data esphome-data"
+    ["sso"]="authentik-data authentik-db redis-data"
+    ["dashboard"]="homepage-data heimdall-data"
+    ["notifications"]="gotify-data ntfy-data"
+)
+
+# Colors for output
+RED='\033[0;31m'
+GREEN='\033[0;32m'
+YELLOW='\033[1;33m'
+BLUE='\033[0;34m'
+NC='\033[0m' # No Color
+
+# Logging
+log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
+log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
+log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
+log_debug() { echo -e "${BLUE}[DEBUG]${NC} $*"; }
+
+# ============================================
+# Notification Functions
+# ============================================
+
+send_notification() {
+    local status="$1"
+    local message="$2"
+    
+    if [[ -z "${NTFY_URL}" ]]; then
+        return 0
+    fi
+    
+    local ntfy_full_url="${NTFY_URL}/${NTFY_TOPIC}"
+    local priority="default"
+    
+    if [[ "${status}" == "failure" ]]; then
+        priority="high"
+    elif [[ "${status}" == "success" ]]; then
+        priority="default"
+    fi
+    
+    curl -s -X POST \
+        -H "Title: HomeLab Backup ${status}" \
+        -H "Priority: ${priority}" \
+        -H "Tags: backup,${status}" \
+        --data-binary "${message}" \
+        "${ntfy_full_url}" > /dev/null 2>&1 || true
+}
+
+# ============================================
+# Restic Repository Functions
+# ============================================
+
+get_restic_repo() {
+    case "${BACKUP_TARGET}" in
+        local)
+            echo "${BACKUP_LOCAL_DIR}/restic-repo"
+            ;;
+        s3|minio)
+            echo "s3:${BACKUP_S3_ENDPOINT}/${BACKUP_S3_BUCKET}"
+            ;;
+        b2)
+            echo "b2:${BACKUP_B2_BUCKET}"
+            ;;
+        sftp)
+            echo "sftp:${BACKUP_SFTP_USER}@${BACKUP_SFTP_HOST}:${BACKUP_SFTP_PATH}"
+            ;;
+        r2)
+            echo "s3:https://${BACKUP_R2_ACCOUNT_ID}.r2.cloudflarestorage.com/${BACKUP_R2_BUCKET}"
+            ;;
+        rest-server)
+            echo "${RESTIC_REST_SERVER}"
+            ;;
+        *)
+            log_error "Unknown backup target: ${BACKUP_TARGET}"
+            exit 1
+            ;;
+    esac
+}
+
+setup_restic_env() {
+    export RESTIC_PASSWORD
+    export RESTIC_REPOSITORY
+    
+    case "${BACKUP_TARGET}" in
+        s3|minio)
+            export AWS_ACCESS_KEY_ID="${BACKUP_S3_ACCESS_KEY}"
+            export AWS_SECRET_ACCESS_KEY="${BACKUP_S3_SECRET_KEY}"
+            ;;
+        b2)
+            export B2_ACCOUNT_ID="${BACKUP_B2_KEY_ID}"
+            export B2_ACCOUNT_KEY="${BACKUP_B2_APPLICATION_KEY}"
+            ;;
+        sftp)
+            if [[ -n