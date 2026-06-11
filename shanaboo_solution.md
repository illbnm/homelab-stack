 ```diff
--- /dev/null
+++ b/scripts/backup.sh
@@ -0,0 +1,518 @@
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
+BACKUP_DIR="${ROOT_DIR}/backups"
+LOG_DIR="${BACKUP_DIR}/logs"
+CONFIG_BACKUP_DIR="${BACKUP_DIR}/config"
+DATE=$(date +%Y%m%d_%H%M%S)
+BACKUP_NAME="homelab-backup-${DATE}"
+DRY_RUN=false
+TARGET="all"
+RESTORE_ID=""
+LIST_BACKUPS=false
+VERIFY_BACKUP=false
+NOTIFY_URL=""
+
+# Colors for output
+RED='\033[0;31m'
+GREEN='\033[0;32m'
+YELLOW='\033[1;33m'
+BLUE='\033[0;34m'
+NC='\033[0m' # No Color
+
+# ============================================
+# Logging
+# ============================================
+
+log() {
+    local level="$1"
+    shift
+    local message="$*"
+    local timestamp
+    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
+    case "$level" in
+        INFO)  echo -e "${GREEN}[INFO]${NC} $message" ;;
+        WARN)  echo -e "${YELLOW}[WARN]${NC} $message" ;;
+        ERROR) echo -e "${RED}[ERROR]${NC} $message" ;;
+        DEBUG) echo -e "${BLUE}[DEBUG]${NC} $message" ;;
+    esac
+    # Write to log file
+    mkdir - posh -p "$LOG_DIR"
+    echo "[$timestamp] [$level] $message" >> "${LOG_DIR}/backup.log"
+}
+
+# ============================================
+# Notification
+# ============================================
+
+send_notification() {
+    local status="$1"
+    local message="$2"
+    
+    # Load ntfy settings from .env
+    if [[ -f "$ENV_FILE" ]]; then
+        source "$ENV_FILE"
+    fi
+    
+    if [[ -n "${NTFY_URL:-}" ]]; then
+        local ntfy_topic="${NTFY_TOPIC:-homelab-backup}"
+        local ntfy_url="${NTFY_URL}/${ntfy_topic}"
+        local priority="${NTFY_PRIORITY:-3}"
+        
+        local title="Backup ${status}"
+        local tags=""
+        if [[ "$status" == "SUCCESS" ]]; then
+            tags="white_check_mark"
+        elif [[ "$status" == "FAILED" ]]; then
+            priority="5"
+            tags="x"
+        fi
+        
+        curl -s -o /dev/null -w "%{http_code}" \
+            -H "Title: ${title}" \
+            -H "Priority: ${priority}" \
+            -H "Tags: ${tags}" \
+            -d "${message}" \
+            "$ntfy_url" || log WARN "Failed to send notification"
+    fi
+}
+
+# ============================================
+# Environment Loading
+# ============================================
+
+load_env() {
+    if [[ ! -f "$ENV_FILE" ]]; then
+        log ERROR "Environment file not found: $ENV_FILE"
+        exit 1
+    fi
+    
+    source "$ENV_FILE"
+    
+    # Set defaults
+    BACKUP_TARGET="${BACKUP_TARGET:-local}"
+    BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
+    BACKUP_ENCRYPT="${BACKUP_ENCRYPT:-true}"
+    BACKUP_PASSWORD="${BACKUP_PASSWORD:-}"
+    LOCAL_BACKUP_PATH="${LOCAL_BACKUP_PATH:-${BACKUP_DIR}/local}"
+    
+    # S3/MinIO settings
+    S3_ENDPOINT="${S3_ENDPOINT:-}"
+    S3_BUCKET="${S3_BUCKET:-}"
+    S3_ACCESS_KEY="${S3_ACCESS_KEY:-}"
+    S3_SECRET_KEY="${S3_SECRET_KEY:-}"
+    S3_REGION="${S3_REGION:-us-east-1}"
+    
+    # B2 settings
+    B2_ACCOUNT_ID="${B2_ACCOUNT_ID:-}"
+    B2_ACCOUNT_KEY="${B2_ACCOUNT_KEY:-}"
+    B2_BUCKET="${B2_BUCKET:-}"
+    
+    # SFTP settings
+    SFTP_HOST="${SFTP_HOST:-}"
+    SFTP_PORT="${SFTP_PORT:-22}"
+    SFTP_USER="${SFTP_USER:-}"
+    SFTP_KEY_PATH="${SFTP_KEY_PATH:-}"
+    SFTP_REMOTE_PATH="${SFTP_REMOTE_PATH:-}"
+    
+    # R2 settings
+    R2_ACCOUNT_ID="${R2_ACCOUNT_ID:-}"
+    R2_ACCESS_KEY="${R2_ACCESS_KEY:-}"
+    R2_SECRET_KEY="${R2_SECRET_KEY:-}"
+    R2_BUCKET="${R2_BUCKET:-}"
+}
+
+# ============================================
+# Stack Discovery
+# ============================================
+
+get_stack_volumes() {
+    local stack_name="$1"
+    local volumes=()
+    
+    case "$stack_name" in
+        all)
+            for stack in base media storage monitoring network productivity ai home-automation sso dashboard notifications; do
+                if [[ -d "${ROOT_DIR}/stacks/${stack}" ]]; then
+                    volumes+=("${stack}")
+                fi
+            done
+            ;;
+        media)
+            volumes=("media")
+            ;;
+        storage)
+            volumes=("storage")
+            ;;
+        monitoring)
+            volumes=("monitoring")
+            ;;
+        network)
+            volumes=("network")
+            ;;
+        productivity)
+            volumes=("productivity")
+            ;;
+        ai)
+            volumes=("ai")
+            ;;
+        home-automation)
+            volumes=("home-automation")
+            ;;
+        sso)
+            volumes=("sso")
+            ;;
+        dashboard)
+            volumes=("dashboard")
+            ;;
+        notifications)
+            volumes=("notifications")
+            ;;
+        *)
+            log ERROR "Unknown stack: $stack_name"
+            exit 1
+            ;;
+    esac
+    
+    echo "${volumes[@]}"
+}
+
+# ============================================
+# Volume Backup
+# ============================================
+
+backup_volumes() {
+    local stack="$1"
+    local backup_path="$2"
+    local stack_dir="${ROOT_DIR}/stacks/${stack}"
+    
+    log INFO "Backing up stack: $stack"
+    
+    # Find all named volumes used by this stack
+