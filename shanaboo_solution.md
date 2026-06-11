 ```diff
--- /dev/null
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
+BACKUP_DIR="${BACKUP_DIR:-${ROOT_DIR}/backups}"
+BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
+BACKUP_ENCRYPT_PASSPHRASE="${BACKUP_ENCRYPT_PASSPHRASE:-}"
+NTFY_URL="${NTFY_URL:-}"
+NTFY_TOPIC="${NTFY_TOPIC:-homelab-backups}"
+NTFY_TOKEN="${NTFY_TOKEN:-}"
+
+# MinIO / S3 settings
+S3_ENDPOINT="${S3_ENDPOINT:-}"
+S3_BUCKET="${S3_BUCKET:-homelab-backups}"
+S3_ACCESS_KEY="${S3_ACCESS_KEY:-}"
+S3_SECRET_KEY="${S3_SECRET_KEY:-}"
+S3_REGION="${S3_REGION:-us-east-1}"
+
+# Backblaze B2 settings
+B2_ACCOUNT_ID="${B2_ACCOUNT_ID:-}"
+B2_APPLICATION_KEY="${B2_APPLICATION_KEY:-}"
+B2_BUCKET="${B2_BUCKET:-homelab-backups}"
+
+# SFTP settings
+SFTP_HOST="${SFTP_HOST:-}"
+SFTP_PORT="${SFTP_PORT:-22}"
+SFTP_USER="${SFTP_USER:-}"
+SFTP_PASSWORD="${SFTP_PASSWORD:-}"
+SFTP_KEY_FILE="${SFTP_KEY_FILE:-}"
+SFTP_REMOTE_PATH="${SFTP_REMOTE_PATH:-/backups}"
+
+# Cloudflare R2 settings
+R2_ACCOUNT_ID="${R2_ACCOUNT_ID:-}"
+R2_ACCESS_KEY_ID="${R2_ACCESS_KEY_ID:-}"
+R2_SECRET_ACCESS_KEY="${R2_SECRET_ACCESS_KEY:-}"
+R2_BUCKET="${R2_BUCKET:-homelab-backups}"
+
+# Restic settings
+RESTIC_REPOSITORY="${RESTIC_REPOSITORY:-}"
+RESTIC_PASSWORD="${RESTIC_PASSWORD:-}"
+
+# Stack definitions
+declare -A STACK_VOLUMES
+STACK_VOLUMES[base]="base_traefik-data base_portainer-data"
+STACK_VOLUMES[media]="media_jellyfin-config media_sonarr-config media_radarr-config media_prowlarr-config media_qbittorrent-config media_jellyseerr-config"
+STACK_VOLUMES[storage]="storage_nextcloud-data storage_minio-data storage_filebrowser-config storage_syncthing-config"
+STACK_VOLUMES[monitoring]="monitoring_grafana-data monitoring_prometheus-data monitoring_loki-data monitoring_alertmanager-data monitoring_uptime-kuma-data"
+STACK_VOLUMES[network]="network_adguard-data network_wireguard-data"
+STACK_VOLUMES[productivity]="productivity_gitea-data productivity_vaultwarden-data productivity_outline-data"
+STACK_VOLUMES[ai]="ai_ollama-data ai_open-webui-data ai_n8n-data"
+STACK_VOLUMES[home-automation]="homeassistant_homeassistant-data homeautomation_node-red-data homeautomation_mosquitto-data homeautomation_zigbee2mqtt-data homeautomation_esphome-data"
+STACK_VOLUMES[sso]="sso_authentik-data sso_postgres-data sso_redis-data"
+STACK_VOLUMES[dashboard]="dashboard_homepage-data dashboard_heimdall-data"
+STACK_VOLUMES[notifications]="notifications_gotify-data notifications_ntfy-data"
+
+# Colors
+RED='\033[0;31m'
+GREEN='\033[0;32m'
+YELLOW='\033[1;33m'
+BLUE='\033[0;34m'
+NC='\033[0m' # No Color
+
+# ============================================
+# Utility Functions
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
+    echo -e "${RED}[ERROR]${NC} $*" >&2
+}
+
+log_dry_run() {
+    echo -e "${BLUE}[DRY-RUN]${NC} $*"
+}
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
+        priority="urgent"
+    elif [[ "${status}" == "success" ]]; then
+        priority="high"
+    fi
+    
+    local curl_opts=(-s -o /dev/null -w "%{http_code}")
+    local headers=(
+        -H "Title: HomeLab Backup ${status^^}"
+        -H "Priority: ${priority}"
+        -H "Tags: backup,${status}"
+    )
+    
+    if [[ -n "${NTFY_TOKEN}" ]]; then
+        headers+=(-H "Authorization: Bearer ${NTFY_TOKEN}")
+    fi
+    
+    curl "${curl_opts[@]}" "${headers[@]}" -d "${message}" "${ntfy_full_url}" || true
+}
+
+get_timestamp() {
+    date +"%Y%m%d_%H%M%S"
+}
+
+get_restic_repo() {
+    case "${BACKUP_TARGET}" in
+        local)
+            echo "${BACKUP_DIR}/restic-repo"
+            ;;
+        s3|minio)
+            echo "s3:${S3_ENDPOINT}/${S3_BUCKET}"
+            ;;
+        b2)
+            echo "b2:${B2_BUCKET}"
+            ;;
+        sftp)
+            echo "sftp:${SFTP_USER}@${SFTP_HOST}:${SFTP_REMOTE_PATH}"
+            ;;
+        r2)
+            echo "s3:https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com/${R2_BUCKET}"
+            ;;
+        *)
+            log_error "Unknown backup target: ${BACKUP_TARGET}"
+            exit 1
+            ;;
+    esac
+}
+
+setup_restic_env() {
+    export RESTIC_REPOSITORY="$(get_restic_repo)"
+    export RESTIC_PASSWORD="${RESTIC_PASSWORD:-changeme}"
+    
+    case "${BACKUP_TARGET}" in
+        s3|minio)
+            export AWS