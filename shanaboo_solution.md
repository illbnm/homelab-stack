 ```diff
--- a/scripts/backup.sh
+++ b/scripts/backup.sh
@@ -0,0 +1,518 @@
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
+ROOT_DIR="$(dirname "$SCRIPT_DIR")"
+ENV_FILE="${ROOT_DIR}/.env"
+
+# Load environment variables
+if [[ -f "$ENV_FILE" ]]; then
+    set -a
+    # shellcheck source=/dev/null
+    source "$ENV_FILE"
+    set +a
+fi
+
+# Default configuration
+: "${BACKUP_TARGET:=local}"
+: "${BACKUP_DIR:=${ROOT_DIR}/backups}"
+: "${BACKUP_RETENTION_DAYS:=30}"
+: "${BACKUP_PREFIX:=homelab}"
+: "${NTFY_URL:=}"
+: "${NTFY_TOPIC:=homelab-backups}"
+: "${RESTIC_PASSWORD:=}"
+: "${RESTIC_REPOSITORY:=}"
+: "${MINIO_ENDPOINT:=}"
+: "${MINIO_BUCKET:=homelab-backups}"
+: "${MINIO_ACCESS_KEY:=}"
+: "${MINIO_SECRET_KEY:=}"
+: "${B2_ACCOUNT_ID:=}"
+: "${B2_ACCOUNT_KEY:=}"
+: "${B2_BUCKET:=}"
+: "${SFTP_HOST:=}"
+: "${SFTP_PORT:=22}"
+: "${SFTP_USER:=}"
+: "${SFTP_PATH:=/backups}"
+: "${R2_ENDPOINT:=}"
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
+# Logging
+LOG_DIR="${ROOT_DIR}/logs"
+LOG_FILE="${LOG_DIR}/backup-$(date +%Y%m%d-%H%M%S).log"
+
+mkdir -p "$LOG_DIR"
+
+log() {
+    local level="$1"
+    shift
+    local message="$*"
+    local timestamp
+    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
+    echo -e "${timestamp} [${level}] ${message}" | tee -a "$LOG_FILE"
+}
+
+info() { log "INFO" "$@"; }
+warn() { log "WARN" "$@"; }
+error() { log "ERROR" "$@" >&2; }
+success() { log "SUCCESS" "$@"; }
+
+# Notification function
+send_notification() {
+    local status="$1"
+    local message="$2"
+    
+    if [[ -n "$NTFY_URL" ]]; then
+        local priority="default"
+        [[ "$status" == "failure" ]] && priority="high"
+        [[ "$status" == "success" ]] && priority="default"
+        
+        curl -s -X POST \
+            -H "Title: HomeLab Backup ${status^^}" \
+            -H "Priority: $priority" \
+            -H "Tags: backup,${status}" \
+            -d "$message" \
+            "${NTFY_URL}/${NTFY_TOPIC}" > /dev/null 2>&1 || warn "Failed to send ntfy notification"
+    fi
+}
+
+# Progress display
+show_progress() {
+    local current="$1"
+    local total="$2"
+    local width=50
+    local percentage=$((current * 100 / total))
+    local filled=$((width * current / total))
+    local empty=$((width - filled))
+    
+    printf "\r[" >&2
+    printf "%0.s#" $(seq 1 $filled) >&2
+    printf "%0.s-" $(seq 1 $empty) >&2
+    printf "] %d%%" "$percentage" >&2
+}
+
+# Get Restic repository URL based on BACKUP_TARGET
+get_restic_repo() {
+    case "$BACKUP_TARGET" in
+        local)
+            echo "rest:${BACKUP_DIR}/restic-repo"
+            ;;
+        s3|minio)
+            echo "s3:${MINIO_ENDPOINT}/${MINIO_BUCKET}"
+            ;;
+        b2)
+            echo "b2:${B2_BUCKET}:"
+            ;;
+        sftp)
+            echo "sftp:${SFTP_USER}@${SFTP_HOST}:${SFTP_PATH}"
+            ;;
+        r2)
+            echo "s3:${R2_ENDPOINT}/${R2_BUCKET}"
+            ;;
+        *)
+            error "Unknown BACKUP_TARGET: $BACKUP_TARGET"
+            exit 1
+            ;;
+    esac
+}
+
+# Initialize Restic repository
+init_repo() {
+    local repo
+    repo=$(get_restic_repo)
+    
+    info "Initializing backup repository: $BACKUP_TARGET"
+    
+    export RESTIC_REPOSITORY="$repo"
+    
+    if restic snapshots > /dev/null 2>&1; then
+        info "Repository already initialized"
+        return 0
+    fi
+    
+    case "$BACKUP_TARGET" in
+        local)
+            mkdir -p "${BACKUP_DIR}/restic-repo"
+            ;;
+        s3|minio)
+            export AWS_ACCESS_KEY_ID="$MINIO_ACCESS_KEY"
+            export AWS_SECRET_ACCESS_KEY="$MINIO_SECRET_KEY"
+            ;;
+        b2)
+            export B2_ACCOUNT_ID="$B2_ACCOUNT_ID"
+            export B2_ACCOUNT_KEY="$B2_ACCOUNT_KEY"
+            ;;
+        sftp)
+            # Ensure SSH key is available or password is set
+            ;;
+        r2)
+            export AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID"
+            export AWS_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY"
+            ;;
+    esac
+    
+    restic init || {
+        error "Failed to initialize repository"
+        return 1
+    }
+    
+    success "Repository initialized"
+}
+
+# Get list of volumes for a stack
+get_stack_volumes() {
+    local stack="$1"
+    local volumes=()
+    
+    if [[ "$stack" == "all" ]]; then
+        for stack_dir in "${ROOT_DIR}/st