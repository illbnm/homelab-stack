 ```diff
--- /dev/null
+++ b/scripts/backup.sh
@@ -0,0 +1,530 @@
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
+# Source environment variables
+if [[ -f "${ENV_FILE}" ]]; then
+    # shellcheck source=/dev/null
+    source "${ENV_FILE}"
+fi
+
+# Default values
+BACKUP_TARGET="${BACKUP_TARGET:-local}"
+BACKUP_LOCAL_DIR="${BACKUP_LOCAL_DIR:-/var/backups/homelab}"
+BACKUP_S3_BUCKET="${BACKUP_S3_BUCKET:-}"
+BACKUP_S3_ENDPOINT="${BACKUP_S3_ENDPOINT:-}"
+BACKUP_S3_ACCESS_KEY="${BACKUP_S3_ACCESS_KEY:-}"
+BACKUP_S3_SECRET_KEY="${BACKUP_S3_SECRET_KEY:-}"
+BACKUP_B2_BUCKET="${BACKUP_B2_BUCKET:-}"
+BACKUP_B2_ACCOUNT_ID="${BACKUP_B2_ACCOUNT_ID:-}"
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
+BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
+NTFY_URL="${NTFY_URL:-}"
+NTFY_TOPIC="${NTFY_TOPIC:-homelab-backup}"
+
+# Restic configuration
+RESTIC_REPOSITORY="${RESTIC_REPOSITORY:-}"
+RESTIC_PASSWORD="${RESTIC_PASSWORD:-}"
+RESTIC_CACHE_DIR="${RESTIC_CACHE_DIR:-/var/cache/restic}"
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
+mkdir -p "${LOG_DIR}"
+
+# ============================================
+# Helper Functions
+# ============================================
+
+log() {
+    local level="$1"
+    shift
+    local message="$*"
+    local timestamp
+    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
+    echo -e "${timestamp} [${level}] ${message}" | tee -a "${LOG_FILE}"
+}
+
+info() {
+    log "INFO" "$*"
+}
+
+warn() {
+    log "WARN" "${YELLOW}$*${NC}"
+}
+
+error() {
+    log "ERROR" "${RED}$*${NC}"
+}
+
+success() {
+    log "SUCCESS" "${GREEN}$*${NC}"
+}
+
+notify() {
+    local status="$1"
+    local message="$2"
+    
+    if [[ -n "${NTFY_URL}" ]]; then
+        local ntfy_full_url="${NTFY_URL}/${NTFY_TOPIC}"
+        local priority="3"
+        [[ "${status}" == "failed" ]] && priority="5"
+        [[ "${status}" == "success" ]] && priority="3"
+        
+        curl -s -o /dev/null -w "%{http_code}" \
+            -H "Title: Backup ${status}" \
+            -H "Priority: ${priority}" \
+            -d "${message}" \
+            "${ntfy_full_url}" || warn "Failed to send ntfy notification"
+    fi
+}
+
+check_dependencies() {
+    local deps=("docker" "restic")
+    for dep in "${deps[@]}"; do
+        if ! command -v "${dep}" &> /dev/null; then
+            error "Required dependency not found: ${dep}"
+            exit 1
+        fi
+    done
+}
+
+setup_restic_repo() {
+    case "${BACKUP_TARGET}" in
+        local)
+            RESTIC_REPOSITORY="file:${BACKUP_LOCAL_DIR}"
+            ;;
+        s3)
+            RESTIC_REPOSITORY="s3:${BACKUP_S3_ENDPOINT}/${BACKUP_S3_BUCKET}"
+            export AWS_ACCESS_KEY_ID="${BACKUP_S3_ACCESS_KEY}"
+            export AWS_SECRET_ACCESS_KEY="${BACKUP_S3_SECRET_KEY}"
+            ;;
+        b2)
+            RESTIC_REPOSITORY="b2:${BACKUP_B2_BUCKET}"
+            export B2_ACCOUNT_ID="${BACKUP_B2_ACCOUNT_ID}"
+            export B2_ACCOUNT_KEY="${BACKUP_B2_APPLICATION_KEY}"
+            ;;
+        sftp)
+            RESTIC_REPOSITORY="sftp:${BACKUP_SFTP_USER}@${BACKUP_SFTP_HOST}:${BACKUP_SFTP_PATH}"
+            export RESTIC_REPOSITORY
+            ;;
+        r2)
+            RESTIC_REPOSITORY="s3:https://${BACKUP_R2_ACCOUNT_ID}.r2.cloudflarestorage.com/${BACKUP_R2_BUCKET}"
+            export AWS_ACCESS_KEY_ID="${BACKUP_R2_ACCESS_KEY}"
+            export AWS_SECRET_ACCESS_KEY="${BACKUP_R2_SECRET_KEY}"
+            ;;
+        *)
+            error "Unknown backup target: ${BACKUP_TARGET}"
+            exit 1
+            ;;
+    esac
+    
+    export RESTIC_REPOSITORY
+    export RESTIC_PASSWORD
+    export RESTIC_CACHE_DIR
+    
+    # Initialize repository if it doesn't exist
+    if ! restic snapshots &>/dev/null; then
+        info "Initializing restic repository: ${RESTIC_REPOSITORY}"
+        restic init || {
+            error "Failed to initialize restic repository"
+            exit 1
+        }
+    fi
+}
+
+get_stack_volumes() {
+    local stack