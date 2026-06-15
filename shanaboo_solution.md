 ```diff
--- /dev/null
+++ b/scripts/backup.sh
@@ -0,0 +1,380 @@
+#!/usr/bin/env bash
+set -euo pipefail
+
+# ==============================================================================
+# HomeLab Stack Backup & Recovery Script
+# Implements 3-2-1 backup strategy
+# ==============================================================================
+
+SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
+ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
+ENV_FILE="${ROOT_DIR}/.env"
+BACKUP_DIR="${ROOT_DIR}/backups"
+LOG_DIR="${BACKUP_DIR}/logs"
+CONFIG_DIR="${ROOT_DIR}/config"
+TIMESTAMP=$(date +%Y%m%d_%H%M%S)
+BACKUP_NAME="homelab_backup_${TIMESTAMP}"
+DRY_RUN=false
+RESTORE_MODE=false
+LIST_MODE=false
+VERIFY_MODE=false
+BACKUP_ID=""
+TARGET="all"
+
+# Colors for output
+RED='\033[0;31m'
+GREEN='\033[0;32m'
+YELLOW='\033[1;33m'
+BLUE='\033[0;34m'
+NC='\033[0m' # No Color
+
+# ==============================================================================
+# Utility Functions
+# ==============================================================================
+
+log_info() {
+    echo -e "${GREEN}[INFO]${NC} $1"
+    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1" >> "${LOG_DIR}/backup_${TIMESTAMP}.log"
+}
+
+log_warn() {
+    echo -e "${YELLOW}[WARN]${NC} $1"
+    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] $1" >> "${LOG_DIR}/backup_${TIMESTAMP}.log"
+}
+
+log_error() {
+    echo -e "${RED}[ERROR]${NC} $1"
+    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1" >> "${LOG_DIR}/backup_${TIMESTAMP}.log"
+}
+
+log_dry_run() {
+    echo -e "${BLUE}[DRY-RUN]${NC} $1"
+}
+
+notify() {
+    local status="$1"
+    local message="$2"
+    
+    if [[ -f "${ENV_FILE}" ]]; then
+        source "${ENV_FILE}"
+    fi
+    
+    if [[ -n "${NTFY_URL:-}" ]]; then
+        curl -s -X POST -H "Title: Backup ${status}" \
+            -H "Priority: ${3:-default}" \
+            -d "${message}" \
+            "${NTFY_URL}" > /dev/null 2>&1 || true
+    fi
+}
+
+show_help() {
+    cat << EOF
+HomeLab Stack Backup & Recovery Script
+
+Usage:
+  backup.sh --target <stack|all> [options]
+
+Options:
+  --target all          Backup all stack data volumes
+  --target media        Backup only media stack
+  --dry-run             Show what would be backed up, don't execute
+  --restore <backup_id> Restore from specified backup
+  --list                List all available backups
+  --verify              Verify backup integrity
+  --help                Show this help message
+
+Examples:
+  backup.sh --target all                    # Backup all stacks
+  backup.sh --target media --dry-run       # Dry run media backup
+  backup.sh --restore 20240115_020000      # Restore specific backup
+  backup.sh --list                         # List all backups
+  backup.sh --verify                       # Verify latest backup
+EOF
+}
+
+# ==============================================================================
+# Environment & Configuration
+# ==============================================================================
+
+load_env() {
+    if [[ ! -f "${ENV_FILE}" ]]; then
+        log_error "No .env file found. Run ./install.sh first."
+        exit 1
+    fi
+    
+    source "${ENV_FILE}"
+    
+    # Set defaults
+    BACKUP_TARGET="${BACKUP_TARGET:-local}"
+    BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
+    BACKUP_LOCAL_PATH="${BACKUP_LOCAL_PATH:-${BACKUP_DIR}/local}"
+    BACKUP_ENCRYPT="${BACKUP_ENCRYPT:-true}"
+    BACKUP_PASSPHRASE="${BACKUP_PASSPHRASE:-}"
+    
+    # Create directories
+    mkdir -p "${BACKUP_DIR}" "${LOG_DIR}" "${BACKUP_LOCAL_PATH}"
+}
+
+get_volumes_to_backup() {
+    local stack="$1"
+    local volumes=()
+    
+    case "$stack" in
+        all)
+            volumes=(
+                "${ROOT_DIR}/stacks/base/data"
+                "${ROOT_DIR}/stacks/media/data"
+                "${ROOT_DIR}/stacks/storage/data"
+                "${ROOT_DIR}/stacks/monitoring/data"
+                "${ROOT_DIR}/stacks/network/data"
+                "${ROOT_DIR}/stacks/productivity/data"
+                "${ROOT_DIR}/stacks/ai/data"
+                "${ROOT_DIR}/stacks/home-automation/data"
+                "${ROOT_DIR}/stacks/sso/data"
+                "${ROOT_DIR}/stacks/dashboard/data"
+                "${ROOT_DIR}/stacks/notifications/data"
+                "${CONFIG_DIR}"
+            )
+            ;;
+        media|storage|monitoring|network|productivity|ai|home-automation|sso|dashboard|notifications)
+            volumes=("${ROOT_DIR}/stacks/${stack}/data")
+            ;;
+        base)
+            volumes=("${ROOT_DIR}/stacks/base/data" "${CONFIG_DIR}")
+            ;;
+        *)
+            log_error "Unknown target: ${stack}"
+            exit 1
+            ;;
+    esac
+    
+    printf '%s\n' "${volumes[@]}"
+}
+
+# ==============================================================================
+# Backup Implementations
+# ==============================================================================
+
+backup_local() {
+    local src="$1"
+    local dest="${BACKUP_LOCAL_PATH}/${BACKUP_NAME}"
+    
+    if [[ "${DRY_RUN}" == "true" ]]; then
+        log_dry_run "Would backup ${src} -> ${dest}"
+        return 0
+    fi
+    
+    mkdir -p "${dest}"
+    
+    if [[ "${BACKUP_ENCRYPT}" == "true" && -n "${BACKUP_PASSPHRASE}" ]]; then
+        tar -czf - "${src}" | gpg --symmetric --cipher-algo AES256 --passphrase "${BACKUP_PASSPHRASE}" --batch -o "${dest}/$(basename "${src}").tar.gz.gpg"
+    else
+        tar -czf "${dest}/$(basename "${src}").tar.gz" "${src}"
+    fi
+    
+    log_info "Backed up