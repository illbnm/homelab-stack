 ```diff
--- a/scripts/backup.sh
+++ b/scripts/backup.sh
@@ -0,0 +1,580 @@
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
+BACKUP_CONFIG_DIR="${CONFIG_DIR}/backup"
+
+# Load environment variables
+if [[ -f "${ROOT_DIR}/.env" ]]; then
+    # shellcheck source=/dev/null
+    source "${ROOT_DIR}/.env"
+fi
+
+# Default configuration
+: "${BACKUP_TARGET:=local}"
+: "${BACKUP_LOCAL_DIR:=/var/backups/homelab}"
+: "${BACKUP_RETENTION_DAYS:=30}"
+: "${BACKUP_ENCRYPT:=true}"
+: "${BACKUP_PASSWORD:=}"
+: "${BACKUP_S3_BUCKET:=}"
+: "${BACKUP_S3_ENDPOINT:=}"
+: "${BACKUP_S3_ACCESS_KEY:=}"
+: "${BACKUP_S3_SECRET_KEY:=}"
+: "${BACKUP_B2_BUCKET:=}"
+: "${BACKUP_B2_ACCOUNT_ID:=}"
+: "${BACKUP_B2_APPLICATION_KEY:=}"
+: "${BACKUP_SFTP_HOST:=}"
+: "${BACKUP_SFTP_PORT:=22}"
+: "${BACKUP_SFTP_USER:=}"
+: "${BACKUP_SFTP_PATH:=}"
+: "${BACKUP_SFTP_KEY:=}"
+: "${NTFY_URL:=}"
+: "${NTFY_TOPIC:=homelab-backup}"
+
+# Backup metadata
+BACKUP_DATE="$(date +%Y%m%d_%H%M%S)"
+BACKUP_HOSTNAME="$(hostname)"
+BACKUP_ID="${BACKUP_HOSTNAME}_${BACKUP_DATE}"
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
+    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $*"
+}
+
+log_info() {
+    log "${GREEN}INFO${NC}: $*"
+}
+
+log_warn() {
+    log "${YELLOW}WARN${NC}: $*" >&2
+}
+
+log_error() {
+    log "${RED}ERROR${NC}: $*" >&2
+}
+
+notify() {
+    local status="$1"
+    local message="$2"
+    
+    if [[ -z "${NTFY_URL}" ]]; then
+        return 0
+    fi
+    
+    local priority="default"
+    if [[ "${status" == "failure" ]]; then
+        priority="urgent"
+    elif [[ "${status}" == "success" ]]; then
+        priority="default"
+    fi
+    
+    curl -s -X POST \
+        -H "Title: HomeLab Backup ${status}" \
+        -H "Priority: ${priority}" \
+        -d "${message}" \
+        "${NTFY_URL}/${NTFY_TOPIC}" >/dev/null 2>&1 || true
+}
+
+# ============================================
+# Utility Functions
+# ============================================
+
+check_dependencies() {
+    local deps=("docker" "docker-compose" "tar" "gzip")
+    for dep in "${deps[@]}"; do
+        if ! command -v "${dep}" &>/dev/null; then
+            log_error "Required dependency not found: ${dep}"
+            exit 1
+        fi
+    done
+}
+
+get_stack_volumes() {
+    local stack="$1"
+    local volumes=()
+    
+    case "${stack}" in
+        base)
+            volumes+=("traefik-data" "portainer-data")
+            ;;
+        media)
+            volumes+=("jellyfin-config" "sonarr-config" "radarr-config" "prowlarr-config" "qbittorrent-config" "jellyseerr-config")
+            ;;
+        storage)
+            volumes+=("nextcloud-data" "minio-data" "filebrowser-data" "syncthing-data")
+            ;;
+        monitoring)
+            volumes+=("grafana-data" "prometheus-data" "loki-data" "alertmanager-data" "uptime-kuma-data")
+            ;;
+        network)
+            volumes+=("adguard-data" "wireguard-data" "nginx-proxy-manager-data")
+            ;;
+        productivity)
+            volumes+=("gitea-data" "vaultwarden-data" "outline-data" "stirling-pdf-data")
+            ;;
+        ai)
+            volumes+=("ollama-data" "open-webui-data" "localai-data" "n8n-data")
+            ;;
+        home-automation)
+            volumes+=("home-assistant-data" "node-red-data" "mosquitto-data" "zigbee2mqtt-data" "esphome-data")
+            ;;
+        sso)
+            volumes+=("authentik-data" "authentik-postgres-data" "authentik-redis-data")
+            ;;
+        dashboard)
+            volumes+=("homepage-data" "heimdall-data")
+            ;;
+        notifications)
+            volumes+=("gotify-data" "ntfy-data" "apprise-data")
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
+backup_volume() {
+    local volume_name="$1"
+    local backup_dir="$2"
+    local dry_run="$3"
+    
+    if [[ "${dry_run}" == "true" ]]; then
+        log_info "  [DRY-RUN] Would backup volume: ${volume_name}"
+        return 0
+    fi
+    
+    log_info "  Backing up volume: ${volume_name}"
+    
+    local backup_file="${backup_dir}/${volume_name}_${BACKUP_DATE}.tar.gz"
+    
+    # Create temporary container to access volume
+    docker run --rm \
+        -v "${volume_name}:/source:ro" \
+        -v "${backup_dir}:/backup" \
+        alpine:latest \
+        tar czf "/backup/${volume_name}_${BACKUP_DATE}.tar.gz" -C /source . 2>/dev/null || {
+        log_warn "  Failed to backup volume ${volume_name}, trying alternative method"
+        # Fallback: use docker cp
+        local temp_dir