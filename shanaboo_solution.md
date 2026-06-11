 ```diff
--- /dev/null
+++ b/scripts/backup.sh
@@ -0,0 +1,526 @@
+#!/usr/bin/env bash
+set -euo pipefail
+
+# ============================================
+# HomeLab Stack Backup & Recovery Script
+# 3-2-1 Backup Strategy Implementation
+# ============================================
+
+SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
+ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
+CONFIG_DIR="${ROOT_DIR}/config"
+STACKS_DIR="${ROOT_DIR}/stacks"
+LOG_DIR="${ROOT_DIR}/logs"
+BACKUP_LOG="${LOG_DIR}/backup.log"
+LOCK_FILE="/tmp/homelab-backup.lock"
+
+# Load environment variables
+if [[ -f "${ROOT_DIR}/.env" ]]; then
+    # shellcheck source=/dev/null
+    source "${ROOT_DIR}/.env"
+fi
+
+# Default values
+: "${BACKUP_TARGET:=local}"
+: "${BACKUP_LOCAL_PATH:=/backup/homelab}"
+: "${BACKUP_RETENTION_DAYS:=30}"
+: "${BACKUP_PREFIX:=homelab}"
+: "${NTFY_URL:=}"
+: "${NTFY_TOPIC:=homelab-backups}"
+: "${DUPLICATI_URL:=http://localhost:8200}"
+: "${RESTIC_REPOSITORY:=}"
+: "${RESTIC_PASSWORD:=}"
+: "${MINIO_ENDPOINT:=}"
+: "${MINIO_BUCKET:=homelab-backups}"
+: "${MINIO_ACCESS_KEY:=}"
+: "${MINIO_SECRET_KEY:=}"
+: "${B2_ACCOUNT_ID:=}"
+: "${B2_ACCOUNT_KEY:=}"
+: "${B2_BUCKET:=}"
+: "${SFTP_HOST:=}"
+: "${SFTP_USER:=}"
+: "${SFTP_PATH:=/backup}"
+: "${R2_ACCOUNT_ID:=}"
+: "${R2_ACCESS_KEY_ID:=}"
+: "${R2_SECRET_ACCESS_KEY:=}"
+: "${R2_BUCKET:=}"
+
+# Colors for output
+RED='\033[0;31m'
+GREEN='\033[0;32m'
+YELLOW='\033[1;33m'
+BLUE='\033[0;34m'
+NC='\033[0m' # No Color
+
+# ============================================
+# Logging & Notifications
+# ============================================
+
+log() {
+    local level="$1"
+    shift
+    local message="$*"
+    local timestamp
+    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
+    echo -e "${timestamp} [${level}] ${message}" | tee -a "${BACKUP_LOG}"
+}
+
+info() { log "INFO" "$@"; }
+warn() { log "WARN" "${YELLOW}$*${NC}"; }
+error() { log "ERROR" "${RED}$*${NC}"; }
+success() { log "SUCCESS" "${GREEN}$*${NC}"; }
+
+notify() {
+    local status="$1"
+    local message="$2"
+    
+    if [[ -n "${NTFY_URL}" ]]; then
+        local priority="default"
+        [[ "${status}" == "failed" ]] && priority="high"
+        
+        curl -s -o /dev/null -w "%{http_code}" \
+            -H "Title: HomeLab Backup ${status}" \
+            -H "Priority: ${priority}" \
+            -d "${message}" \
+            "${NTFY_URL}/${NTFY_TOPIC}" 2>/dev/null || warn "Failed to send ntfy notification"
+    fi
+}
+
+# ============================================
+# Utility Functions
+# ============================================
+
+check_dependencies() {
+    local deps=("docker" "docker-compose" "curl")
+    for dep in "${deps[@]}"; do
+        if ! command -v "${dep}" &> /dev/null; then
+            error "Required dependency not found: ${dep}"
+            exit 1
+        fi
+    done
+    
+    mkdir -p "${LOG_DIR}"
+}
+
+acquire_lock() {
+    if [[ -f "${LOCK_FILE}" ]]; then
+        local pid
+        pid=$(cat "${LOCK_FILE}")
+        if kill -0 "${pid}" 2>/dev/null; then
+            error "Another backup process is already running (PID: ${pid})"
+            exit 1
+        fi
+        rm -f "${LOCK_FILE}"
+    fi
+    echo $$ > "${LOCK_FILE}"
+}
+
+release_lock() {
+    rm -f "${LOCK_FILE}"
+}
+
+get_stack_volumes() {
+    local stack="$1"
+    local volumes=()
+    
+    case "${stack}" in
+        media)
+            volumes=("jellyfin-config" "sonarr-config" "radarr-config" "prowlarr-config" "qbittorrent-config" "jellyseerr-config")
+            ;;
+        monitoring)
+            volumes=("grafana-data" "prometheus-data" "loki-data" "alertmanager-data")
+            ;;
+        storage)
+            volumes=("nextcloud-data" "nextcloud-db" "minio-data" "filebrowser-data")
+            ;;
+        sso)
+            volumes=("authentik-data" "authentik-postgres" "authentik-redis")
+            ;;
+        network)
+            volumes=("adguard-data" "wireguard-data")
+            ;;
+        productivity)
+            volumes=("gitea-data" "gitea-db" "vaultwarden-data" "outline-data" "outline-db" "outline-redis")
+            ;;
+        ai)
+            volumes=("ollama-data" "open-webui-data" "localai-data" "n8n-data" "n8n-db")
+            ;;
+        home-automation)
+            volumes=("homeassistant-config" "node-red-data" "mosquitto-data" "zigbee2mqtt-data" "esphome-data")
+            ;;
+        dashboard)
+            volumes=("homepage-data" "heimdall-data")
+            ;;
+        notifications)
+            volumes=("gotify-data" "ntfy-data")
+            ;;
+        base)
+            volumes=("traefik-data" "portainer-data")
+            ;;
+        *)
+            warn "Unknown stack: ${stack}"
+            ;;
+    esac
+    
+    printf '%s\n' "${volumes[@]}"
+}
+
+get_all_stacks() {
+    echo "base media monitoring storage sso network productivity ai home-automation dashboard notifications"
+}
+
+# ============================================
+# Backup Target Configuration
+# ============================================
+
+setup_restic_repo() {
+    local repo_url=""
+    
+    case "${BACKUP_TARGET}" in
+        local)
+            mkdir -p "${BACKUP_LOCAL_PATH}"
+            repo_url="${BACKUP_LOCAL_PATH}"
+ strip_prefix="s3:${MINIO_ENDPOINT}/${MINIO_BUCKET}"
+            ;;
+        b2)
+            export B2_ACCOUNT