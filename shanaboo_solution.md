 ```diff
--- /dev/null
+++ b/scripts/backup.sh
@@ -0,0 +1,466 @@
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
+ENV_FILE="${ROOT_DIR}/.env"
+BACKUP_DIR="${ROOT_DIR}/backups"
+LOG_DIR="${ROOT_DIR}/logs"
+CONFIG_DIR="${ROOT_DIR}/config"
+
+# Default values
+DRY_RUN=false
+TARGET=""
+RESTORE_ID=""
+LIST_BACKUPS=false
+VERIFY_BACKUP=false
+BACKUP_ID=""
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
+    
+    case "$level" in
+        ERROR) echo -e "${RED}[ERROR]${NC} $message" ;;
+        WARN)  echo -e "${YELLOW}[WARN]${NC} $message" ;;
+        INFO)  echo -e "${GREEN}[INFO]${NC} $message" ;;
+        DEBUG) echo -e "${BLUE}[DEBUG]${NC} $message" ;;
+    esac
+    
+    # Write to log file
+    mkdir -p "$LOG_DIR"
+    echo "[$timestamp] [$level] $message" >> "${LOG_DIR}/backup.log"
+}
+
+# ============================================
+# Notification (ntfy)
+# ============================================
+
+send_notification() {
+    local status="$1"
+    local message="$2"
+    
+    if [[ -f "$ENV_FILE" ]]; then
+        # shellcheck source=/dev/null
+        source "$ENV_FILE"
+    fi
+    
+    if [[ -n "${NTFY_URL:-}" ]]; then
+        local ntfy_topic
+        ntfy_topic="${NTFY_TOPIC:-homelab-backup}"
+        local ntfy_full_url="${NTFY_URL}/${ntfy_topic}"
+        
+        local priority="default"
+        if [[ "$status" == "ERROR" ]]; then
+            priority="urgent"
+        elif [[ "$status" == "SUCCESS" ]]; then
+            priority="default"
+        fi
+        
+        curl -s -X POST \
+            -H "Title: Backup ${status}" \
+            -H "Priority: ${priority}" \
+            -H "Tags: backup,${status,,}" \
+            -d "$message" \
+            "$ntfy_full_url" > /dev/null 2>&1 || log WARN "Failed to send ntfy notification"
+    fi
+}
+
+# ============================================
+# Environment Loading
+# ============================================
+
+load_env() {
+    if [[ -f "$ENV_FILE" ]]; then
+        # shellcheck source=/dev/null
+        source "$ENV_FILE"
+    else
+        log ERROR "Environment file not found: $ENV_FILE"
+        exit 1
+    fi
+    
+    # Set defaults
+    BACKUP_TARGET="${BACKUP_TARGET:-local}"
+    BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
+    BACKUP_ENCRYPT="${BACKUP_ENCRYPT:-true}"
+    BACKUP_PASSWORD="${BACKUP_PASSWORD:-}"
+    LOCAL_BACKUP_PATH="${LOCAL_BACKUP_PATH:-${BACKUP_DIR}}"
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
+}
+
+# ============================================
+# Usage
+# ============================================
+
+usage() {
+    cat <<EOF
+HomeLab Stack Backup & Recovery Script
+
+Usage:
+  backup.sh --target <stack|all> [options]
+
+Options:
+  --target <stack|all>   Backup target stack or all stacks
+  --dry-run              Show what would be backed up without executing
+  --restore <backup_id>  Restore from specified backup ID
+  --list                 List all available backups
+  --verify               Verify backup integrity
+  -h, --help             Show this help message
+
+Examples:
+  backup.sh --target all
+  backup.sh --target media --dry-run
+  backup.sh --target all --restore 20240115-020000
+  backup.sh --list
+EOF
+}
+
+# ============================================
+# Backup Target Resolution
+# ============================================
+
+get_stack_volumes() {
+    local stack="$1"
+    local volumes=()
+    
+    case "$stack" in
+        all)
+            for s in media storage monitoring network productivity ai home-automation sso dashboard notifications; do
+                if [[ -d "${ROOT_DIR}/stacks/$s" ]]; then
+                    volumes+=("$s")
+                fi
+            done
+            ;;
+        media|storage|monitoring|network|productivity|ai|home-automation|sso|dashboard|notifications)
+            if [[ -d "${ROOT_DIR}/stacks/$stack" ]]; then
+                volumes+=("$stack")
+            else
+                log ERROR "Stack not found: $stack"
+                exit 1
+            fi
+            ;;
+        *)
+            log ERROR "Unknown target: $stack"
+            exit 1
+            ;;
+    esac
+    
+    echo "${volumes[@]}"
+}
+
+# ============================================
+# Backup Storage Helpers
+# ============================================
+
+get_backup_repo() {
+    local backup_id="$1"
+    
+    case "$BACKUP_TARGET"