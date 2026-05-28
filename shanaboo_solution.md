```diff
--- a/scripts/backup.sh
+++ b/scripts/backup.sh
@@ -0,0 +1,564 @@
+#!/usr/bin/env bash
+set -euo pipefail
+
+# ============================================
+# HomeLab Stack - Backup & Recovery Script
+# 3-2-1 Backup Strategy: 3 copies, 2 media, 1 offsite
+# ============================================
+
+SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
+ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
+ENV_FILE="${ROOT_DIR}/.env"
+
+# Load environment variables
+if [[ -f "${ENV_FILE}" ]]; then
+    set -a
+    # shellcheck source=/dev/null
+    source "${ENV_FILE}"
+    set +a
+fi
+
+# Default configuration
+: "${BACKUP_TARGET:=local}"
+: "${BACKUP_LOCAL_DIR:=${ROOT_DIR}/backups}"
+: "${BACKUP_RETENTION_DAYS:=30}"
+: "${BACKUP_ENCRYPT:=true}"
+: "${BACKUP_PASSWORD:=changeme}"
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
+    local priority="default"
+    if [[ "${status}" == "failure" ]]; then
+        priority="urgent"
+    elif [[ "${status}" == "success" ]]; then
+        priority="default"
+    fi
+    
+    curl -s -o /dev/null -w "%{http_code}" \
+        -H "Title: HomeLab Backup ${status}" \
+        -H "Priority: ${priority}" \
+        -H "Tags: backup,${status}" \
+        -d "${message}" \
+        "${NTFY_URL}/${NTFY_TOPIC}" 2>/dev/null || true
+}
+
+# ============================================
+# Utility Functions
+# ============================================
+
+show_help() {
+    cat << 'EOF'
+HomeLab Stack Backup & Recovery Script
+
+Usage:
+  backup.sh --target <stack|all> [options]
+
+Options:
+  --target <stack|all>    Backup specific stack or all stacks
+  --dry-run              Show what would be backed up without executing
+  --restore <backup_id>  Restore from specified backup
+  --list                 List all available backups
+  --verify               Verify backup integrity
+  --help                 Show this help message
+
+Examples:
+  backup.sh --target all                    # Backup all stacks
+  backup.sh --target media                  # Backup media stack only
+  backup.sh --target all --dry-run          # Dry run for all stacks
+  backup.sh --target all --list             # List all backups
+  backup.sh --target all --verify           # Verify latest backup
+  backup.sh --target all --restore 20240115_020000  # Restore specific backup
+
+Environment:
+  BACKUP_TARGET          Backup target: local, s3, b2, sftp, r2 (default: local)
+  BACKUP_LOCAL_DIR       Local backup directory (default: ./backups)
+  BACKUP_RETENTION_DAYS  Number of days to keep backups (default: 30)
+  BACKUP_ENCRYPT         Enable encryption (default: true)
+  BACKUP_PASSWORD        Encryption password (default: changeme)
+  NTFY_URL               ntfy server URL for notifications
+  NTFY_TOPIC             ntfy topic for notifications (default: homelab-backups)
+EOF
+}
+
+get_timestamp() {
+    date +"%Y%m%d_%H%M%S"
+}
+
+get_date() {
+    date +"%Y-%m-%d %H:%M:%S"
+}
+
+# ============================================
+# Stack Discovery
+# ============================================
+
+discover_stacks() {
+    local stacks=()
+    for stack_dir in "${ROOT_DIR}/stacks"/*; do
+        if [[ -d "${stack_dir}" ]]; then
+            local stack_name
+            stack_name=$(basename "${stack_dir}")
+            if [[ -f "${stack_dir}/docker-compose.yml" || -f "${stack_dir}/docker-compose.yaml" ]]; then
+                stacks+=("${stack_name}")
+            fi
+        fi
+    done
+    echo "${stacks[@]}"
+}
+
+get_stack_volumes() {
+    local stack_name="$1"
+    local compose_file
+    
+    if [[ -f "${ROOT_DIR}/stacks/${stack_name}/docker-compose.yml" ]]; then
+        compose_file="${ROOT_DIR}/stacks/${stack_name}/docker-compose.yml"
+    elif [[ -f "${ROOT_DIR}/stacks/${stack_name}/docker-compose.yaml" ]]; then
+        compose_file="${ROOT_DIR}/stacks/${stack_name}/docker-compose.yaml"
+    else
+        return 1
+    fi
+    
+    # Extract volume paths from docker-compose file
+    grep -oP '(?<=-\s).*:(?=/[^/]*$)' "${compose_file}" 2>/dev/null | sed 's/["'\'']//g' | sort -u || true
+}
+
+# ============================================
+# Backup Target Implementations
+# ============================================
