 ```diff
--- /dev/null
+++ b/scripts/backup.sh
@@ -0,0 +1,384 @@
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
+STACKS_DIR="${ROOT_DIR}/stacks"
+CONFIG_DIR="${ROOT_DIR}/config"
+BACKUP_DIR="${ROOT_DIR}/backups"
+LOG_DIR="${ROOT_DIR}/logs"
+ENV_FILE="${ROOT_DIR}/.env"
+
+# Default values
+DRY_RUN=false
+TARGET=""
+RESTORE_ID=""
+LIST_BACKUPS=false
+VERIFY_BACKUP=false
+BACKUP_ID=""
+
+# Source environment if exists
+if [[ -f "${ENV_FILE}" ]]; then
+    # shellcheck source=/dev/null
+    source "${ENV_FILE}"
+fi
+
+# Configuration from .env with defaults
+BACKUP_TARGET="${BACKUP_TARGET:-local}"
+BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
+BACKUP_ENCRYPT_PASSPHRASE="${BACKUP_ENCRYPT_PASSPHRASE:-}"
+BACKUP_LOCAL_PATH="${BACKUP_LOCAL_PATH:-${BACKUP_DIR}}"
+BACKUP_S3_ENDPOINT="${BACKUP_S3_ENDPOINT:-}"
+BACKUP_S3_BUCKET="${BACKUP_S3_BUCKET:-}"
+BACKUP_S3_ACCESS_KEY="${BACKUP_S3_ACCESS_KEY:-}"
+BACKUP_S3_SECRET_KEY="${BACKUP_S3_SECRET_KEY:-}"
+BACKUP_B2_ACCOUNT_ID="${BACKUP_B2_ACCOUNT_ID:-}"
+BACKUP_B2_ACCOUNT_KEY="${BACKUP_B2_ACCOUNT_KEY:-}"
+BACKUP_B2_BUCKET="${BACKUP_B2_BUCKET:-}"
+BACKUP_SFTP_HOST="${BACKUP_SFTP_HOST:-}"
+BACKUP_SFTP_PORT="${BACKUP_SFTP_PORT:-22}"
+BACKUP_SFTP_USER="${BACKUP_SFTP_USER:-}"
+BACKUP_SFTP_KEY="${BACKUP_SFTP_KEY:-}"
+BACKUP_SFTP_PATH="${BACKUP_SFTP_PATH:-}"
+BACKUP_R2_ENDPOINT="${BACKUP_R2_ENDPOINT:-}"
+BACKUP_R2_BUCKET="${BACKUP_R2_BUCKET:-}"
+BACKUP_R2_ACCESS_KEY="${BACKUP_R2_ACCESS_KEY:-}"
+BACKUP_R2_SECRET_KEY="${BACKUP_R2_SECRET_KEY:-}"
+NTFY_URL="${NTFY_URL:-}"
+NTFY_TOPIC="${NTFY_TOPIC:-homelab-backup}"
+
+# Logging
+LOG_FILE="${LOG_DIR}/backup-$(date +%Y%m%d-%H%M%S).log"
+
+# ============================================
+# Utility Functions
+# ============================================
+
+log() {
+    local level="$1"
+    shift
+    local message="[$(date '+%Y-%m-%d %H:%M:%S')] [${level}] $*"
+    echo "${message}"
+    if [[ -d "${LOG_DIR}" ]]; then
+        echo "${message}" >> "${LOG_FILE}" 2>/dev/null || true
+    fi
+}
+
+info() { log "INFO" "$@"; }
+warn() { log "WARN" "$@" >&2; }
+error() { log "ERROR" "$@" >&2; }
+
+notify() {
+    local status="$1"
+    local message="$2"
+    
+    if [[ -n "${NTFY_URL}" ]]; then
+        local priority="default"
+        [[ "${status}" == "failed" ]] && priority="high"
+        [[ "${status}" == "success" ]] && priority="default"
+        
+        curl -s -X POST \
+            -H "Title: Backup ${status}" \
+            -H "Priority: ${priority}" \
+            -d "${message}" \
+            "${NTFY_URL}/${NTFY_TOPIC}" >/dev/null 2>&1 || warn "Failed to send ntfy notification"
+    fi
+}
+
+usage() {
+    cat <<EOF
+HomeLab Stack Backup Script
+
+用法:
+  backup.sh --target <stack|all> [选项]
+
+选项:
+  --target all          备份所有 stack 数据卷
+  --target media        仅备份媒体栈
+  --target storage      仅备份存储栈
+  --target monitoring   仅备份监控栈
+  --target sso          仅备份SSO栈
+  --dry-run             显示将备份的内容，不实际执行
+  --restore <backup_id> 从指定备份恢复
+  --list                列出所有备份
+  --verify              验证备份完整性
+  -h, --help            显示此帮助信息
+
+环境变量 (通过 .env 配置):
+  BACKUP_TARGET         备份目标: local, s3, b2, sftp, r2 (默认: local)
+  BACKUP_RETENTION_DAYS 保留天数 (默认: 30)
+EOF
+}
+
+parse_args() {
+    while [[ $# -gt 0 ]]; do
+        case "$1" in
+            --target)
+                TARGET="$2"
+                shift 2
+                ;;
+            --dry-run)
+                DRY_RUN=true
+                shift
+                ;;
+            --restore)
+                RESTORE_ID="$2"
+                shift 2
+                ;;
+            --list)
+                LIST_BACKUPS=true
+                shift
+                ;;
+            --verify)
+                VERIFY_BACKUP=true
+                shift
+                ;;
+            -h|--help)
+                usage
+                exit 0
+                ;;
+            *)
+                error "未知选项: $1"
+                usage
+                exit 1
+                ;;
+        esac
+    done
+}
+
+# ============================================
+# Backup Core Functions
+# ============================================
+
+init_backup_env() {
+    mkdir -p "${BACKUP_DIR}" "${LOG_DIR}"
+    
+    if [[ "${DRY_RUN}" == true ]]; then
+        info "DRY RUN MODE - 不会实际执行备份操作"
+    fi
+}
+
+get_stack_volumes() {
+    local stack="$1"
+    local compose_file="${STACKS_DIR}/${stack}/docker-compose.yml"
+    
+    if [[ ! -f "${compose_file}" ]]; then
+        warn "Stack ${stack} 的 docker-compose.yml 不存在"
+        return 1
+    fi
+    
+    # Extract volume names from docker-compose.yml
+    grep -E '^\s+-|^(\s+)[a-zA-Z0-9_-]+:' "${compose_file}" 2>/dev/null | \
+        grep -oE '[a-zA-Z0