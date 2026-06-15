 ```diff
--- /dev/null
+++ b/scripts/backup.sh
@@ -0,0 +1,518 @@
+#!/usr/bin/env bash
+set -euo pipefail
+
+# ==============================================================================
+# HomeLab Stack Backup & Recovery Script
+# Implements 3-2-1 backup strategy with multiple target support
+# ==============================================================================
+
+SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
+ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
+CONFIG_DIR="${ROOT_DIR}/config"
+BACKUP_DIR="${ROOT_DIR}/backups"
+LOG_DIR="${ROOT_DIR}/logs"
+ENV_FILE="${ROOT_DIR}/.env"
+
+# Load environment variables
+if [[ -f "${ENV_FILE}" ]]; then
+    # shellcheck source=/dev/null
+    source "${ENV_FILE}"
+fi
+
+# Default configuration
+: "${BACKUP_TARGET:=local}"
+: "${BACKUP_RETENTION_DAYS:=30}"
+: "${BACKUP_ENCRYPT:=true}"
+: "${BACKUP_PASSPHRASE:=}"
+: "${NTFY_URL:=}"
+: "${NTFY_TOPIC:=homelab-backups}"
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
+: "${R2_ACCOUNT_ID:=}"
+: "${R2_ACCESS_KEY_ID:=}"
+: "${R2_SECRET_ACCESS_KEY:=}"
+: "${R2_BUCKET:=homelab-backups}"
+: "${R2_ENDPOINT:=}"
+
+# Backup metadata
+TIMESTAMP=$(date +%Y%m%d_%H%M%S)
+BACKUP_ID="backup_${TIMESTAMP}"
+
+# ==============================================================================
+# Logging
+# ==============================================================================
+
+mkdir -p "${LOG_DIR}"
+LOG_FILE="${LOG_DIR}/backup_${TIMESTAMP}.log"
+
+log() {
+    local level="$1"
+    shift
+    local message="[$(date '+%Y-%m-%d %H:%M:%S')] [${level}] $*"
+    echo "${message}" | tee -a "${LOG_FILE}"
+}
+
+info() { log "INFO" "$@"; }
+warn() { log "WARN" "$@" >&2; }
+error() { log "ERROR" "$@" >&2; }
+
+# ==============================================================================
+# Notification
+# ==============================================================================
+
+send_notification() {
+    local status="$1"
+    local message="$2"
+    
+    if [[ -z "${NTFY_URL}" ]]; then
+        return 0
+    fi
+    
+    local priority="default"
+    case "${status}" in
+        success) priority="low" ;;
+        failure) priority="high" ;;
+        *) priority="default" ;;
+    esac
+    
+    local ntfy_payload
+    ntfy_payload=$(cat <<EOF
+{
+    "topic": "${NTFY_TOPIC}",
+    "title": "HomeLab Backup ${status^^}",
+    "message": "${message}",
+    "priority": ${priority},
+    "tags": ["backup","${status}"]
+}
+EOF
+)
+    
+    curl -s -X POST \
+        -H "Content-Type: application/json" \
+        -d "${ntfy_payload}" \
+        "${NTFY_URL}" >/dev/null 2>&1 || warn "Failed to send ntfy notification"
+}
+
+# ==============================================================================
+# Utility Functions
+# ==============================================================================
+
+check_dependencies() {
+    local deps=("docker" "docker-compose" "restic")
+    for dep in "${deps[@]}"; do
+        if ! command -v "${dep}" &>/dev/null; then
+            error "Missing dependency: ${dep}"
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
+        all)
+            for s in base media storage monitoring network productivity ai home-automation sso dashboard notifications; do
+                volumes+=($(get_stack_volumes "${s}"))
+            done
+            ;;
+        base)
+            volumes=("traefik-data" "portainer-data")
+            ;;
+        media)
+            volumes=("jellyfin-config" "sonarr-config" "radarr-config" "prowlarr-config" "qbittorrent-config" "jellyseerr-config")
+            ;;
+        storage)
+            volumes=("nextcloud-data" "nextcloud-db" "minio-data" "filebrowser-data" "syncthing-data")
+            ;;
+        monitoring)
+            volumes=("grafana-data" "prometheus-data" "loki-data" "alertmanager-data" "uptime-kuma-data")
+            ;;
+        network)
+            volumes=("adguard-data" "wireguard-data" "nginxpm-data" "nginxpm-letsencrypt")
+            ;;
+        productivity)
+            volumes=("gitea-data" "gitea-db" "vaultwarden-data" "outline-data" "outline-db" "outline-redis" "stirling-pdf-data")
+            ;;
+        ai)
+            volumes=("ollama-data" "open-webui-data" "localai-data" "n8n-data" "n8n-db")
+            ;;
+        home-automation)
+            volumes=("homeassistant-config" "node-red-data" "mosquitto-data" "zigbee2mqtt-data" "esphome-data")
+            ;;
+        sso)
+            volumes=("authentik-data" "authentik-db" "authentik-redis")
+            ;;
+        dashboard)
+            volumes=("homepage-data" "heimdall-data")
+            ;;
+        notifications)
+            volumes=("gotify-data" "ntfy-data" "apprise-data")
+            ;;
+        *)
+            error "Unknown stack: ${stack}"
+            exit 1
+            ;;
+    esac
+    
+    echo "${volumes[@]}"
+}
+
+get_volume_path() {
+    local volume_name="$1"
+    docker volume inspect "${volume_name}" -f '{{ .Mountpoint }}' 2>/dev/null || echo ""
+}
+
+# ==============================================================================
+# Restic Repository Setup
+# ==============================================================================
+
+get_restic_repo() {
+    case "${BACKUP_TARGET}" in
+        local)
+            echo "/backups"
+            ;;
+        s3|minio)
+            echo "s3:${MINIO_ENDPOINT}/${MINIO_BUCKET}"
+            ;;
+        b2)
+            echo "b2:${B2_BUCKET}"
+