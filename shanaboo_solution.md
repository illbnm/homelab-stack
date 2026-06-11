 ```diff
--- a/scripts/backup.sh
+++ b/scripts/backup.sh
@@ -0,0 +1,580 @@
+#!/usr/bin/env bash
+set -euo pipefail
+
+# ==============================================================================
+# HomeLab Stack — Backup & Recovery Script
+# Implements 3-2-1 backup strategy: 3 copies, 2 media, 1 offsite
+# ==============================================================================
+
+SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
+ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
+ENV_FILE="${ROOT_DIR}/adev"
+BACKUP_DIR="${ROOT_DIR}/backups"
+LOG_DIR="${ROOT_DIR}/logs"
+CONFIG_DIR="${ROOT_DIR}/config"
+DATE=$(date +%Y%m%d_%H%M%S)
+BACKUP_NAME="homelab_backup_${DATE}"
+
+# Load environment variables
+if [[ -f "${ENV_FILE}" ]]; then
+  set -a
+  # shellcheck source=/dev/null
+  source "${ENV_FILE}"
+  set +a
+fi
+
+# ==============================================================================
+# Configuration
+# ==============================================================================
+
+BACKUP_TARGET="${BACKUP_TARGET:-local}"
+BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
+BACKUP_ENCRYPTION_KEY="${BACKUP_ENCRYPTION_KEY:-}"
+NTFY_URL="${NTFY_URL:-}"
+NTFY_TOPIC="${NTFY_TOPIC:-homelab-backup}"
+MINIO_ENDPOINT="${MINIO_ENDPOINT:-}"
+MINIO_ACCESS_KEY="${MINIO_ACCESS_KEY:-}"
+MINIO_SECRET_KEY="${MINIO_SECRET_KEY:-}"
+MINIO_BUCKET="${MINIO_BUCKET:-homelab-backups}"
+B2_ACCOUNT_ID="${B2_ACCOUNT_ID:-}"
+B2_APPLICATION_KEY="${B2_APPLICATION_KEY:-}"
+B2_BUCKET="${B2_BUCKET:-homelab-backups}"
+SFTP_HOST="${SFTP_HOST:-}"
+SFTP_PORT="${SFTP_PORT:-22}"
+SFTP_USER="${SFTP_USER:-}"
+SFTP_KEY_PATH="${SFTP_KEY_PATH:-}"
+SFTP_REMOTE_PATH="${SFTP_REMOTE_PATH:-/backups}"
+R2_ACCOUNT_ID="${R2_ACCOUNT_ID:-}"
+R2_ACCESS_KEY_ID="${R2_ACCESS_KEY_ID:-}"
+R2_SECRET_ACCESS_KEY="${R2_SECRET_ACCESS_KEY:-}"
+R2_BUCKET="${R2_BUCKET:-homelab-backups}"
+R2_ENDPOINT="${R2_ENDPOINT:-}"
+
+# Stack definitions
+declare -A STACK_VOLUMES
+STACK_VOLUMES[base]="traefik-data portainer-data"
+STACK_VOLUMES[media]="jellyfin-config sonarr-config radarr-config prowlarr-config qbittorrent-config jellyseerr-config"
+STACK_VOLUMES[storage]="nextcloud-data nextcloud-db minio-data filebrowser-data syncthing-data"
+STACK_VOLUMES[monitoring]="grafana-data prometheus-data loki-data alertmanager-data uptime-kuma-data"
+STACK_VOLUMES[network]="adguard-data wireguard-data cloudflare-ddns-data nginx-proxy-manager-data"
+STACK_VOLUMES[productivity]="gitea-data vaultwarden-data outline-data stirling-pdf-data it-tools-data"
+STACK_VOLUMES[ai]="ollama-data open-webui-data localai-data n8n-data"
+STACK_VOLUMES[home-automation]="home-assistant-config node-red-data mosquitto-data zigbee2mqtt-data esphome-data"
+STACK_VOLUMES[sso]="authentik-data authentik-db authentik-redis"
+STACK_VOLUMES[dashboard]="homepage-data heimdall-data"
+STACK_VOLUMES[notifications]="gotify-data ntfy-data apprise-data"
+
+# ==============================================================================
+# Colors & Logging
+# ==============================================================================
+
+RED='\033[0;31m'
+GREEN='\033[0;32m'
+YELLOW='\033[1;33m'
+BLUE='\033[0;34m'
+CYAN='\033[0;36m'
+NC='\033[0m' # No Color
+
+log_info() {
+  echo -e "${GREEN}[INFO]${NC} $1"
+}
+
+log_warn() {
+  echo -e "${YELLOW}[WARN]${NC} $1"
+}
+
+log_error() {
+  echo -e "${RED[ERROR]${NC} $1" >&2
+}
+
+log_debug() {
+  echo -e "${CYAN}[DEBUG]${NC} $1"
+}
+
+# ==============================================================================
+# Notification
+# ==============================================================================
+
+send_notification() {
+  local status="$1"
+  local message="$2"
+  
+  if [[ -n "${NTFY_URL}" ]]; then
+    local priority="default"
+    [[ "${status}" == "failure" ]] && priority="high"
+    [[ "${status}" == "success" ]] && priority="default"
+    
+    curl -s -X POST \
+      -H "Title: HomeLab Backup ${status^^}" \
+      -H "Priority: ${priority}" \
+      -H "Tags: backup,${status}" \
+      --data-binary "${message}" \
+      "${NTFY_URL}/${NTFY_TOPIC}" 2>/dev/null || true
+  fi
+}
+
+# ==============================================================================
+# Utility Functions
+# ==============================================================================
+
+usage() {
+  cat <<EOF
+HomeLab Stack Backup & Recovery Script
+
+Usage:
+  backup.sh --target <stack|all> [options]
+
+Targets:
+  all              Backup all stack data volumes
+  base             Backup base infrastructure
+  media            Backup media stack
+  storage          Backup storage stack
+  monitoring       Backup monitoring stack
+  network          Backup network stack
+  productivity     Backup productivity stack
+  ai               Backup AI stack
+  home-automation  Backup home automation stack
+  sso              Backup SSO stack
+  dashboard        Backup dashboard stack
+  notifications    Backup notifications stack
+
+Options:
+  --dry-run             Show what would be backed up, don't execute
+  --restore <backup_id> Restore from specified backup
+  --list                List all available backups
+  --verify              Verify backup integrity
+  --help                Show this help message
+
+Environment (set in .env):
+  BACKUP_TARGET         Backup destination: local, s3, b2, sftp, r2 (default: local)
+  BACKUP_RETENTION_DAYS Number of days to keep backups (default: 30)
+  BACKUP_ENCRYPTION_KEY Encryption key for backup archives
+  
+  NTFY_URL              ntfy server URL for notifications
+  NTFY_TOPIC            ntfy topic for notifications (default: homelab-backup)
+  
+  For S3/MinIO:  MINIO_ENDPOINT, MINIO_ACCESS_KEY, MINIO_SECRET_KEY, MINIO_BUCKET
+  For B2:         B2_ACCOUNT_ID, B2_APPLICATION_KEY, B2_BUCKET
+  For SFTP: