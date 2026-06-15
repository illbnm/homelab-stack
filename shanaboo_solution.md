 ```diff
--- a/scripts/backup.sh
+++ b/scripts/backup.sh
@@ -0,0 +1,530 @@
+#!/usr/bin/env bash
+set -euo pipefail
+
+# ============================================
+# HomeLab Stack Backup & Recovery Script
+# ============================================
+
+SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
+PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
+ENV_FILE="${PROJECT_ROOT}/.env"
+
+# Load environment variables
+if [[ -f "${ENV_FILE}" ]]; then
+    # shellcheck source=/dev/null
+    source "${ENV_FILE}"
+fi
+
+# Default values
+BACKUP_TARGET="${BACKUP_TARGET:-local}"
+BACKUP_DIR="${BACKUP_DIR:-${PROJECT_ROOT}/backups}"
+BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
+BACKUP_ENCRYPT_PASSWORD="${BACKUP_ENCRYPT_PASSWORD:-}"
+BACKUP_S3_BUCKET="${BACKUP_S3_BUCKET:-}"
+BACKUP_S3_ENDPOINT="${BACKUP_S3_ENDPOINT:-}"
+BACKUP_S3_ACCESS_KEY="${BACKUP_S3_ACCESS_KEY:-}"
+BACKUP_S3_SECRET_KEY="${BACKUP_S3_SECRET_KEY:-}"
+BACKUP_B2_BUCKET="${BACKUP_B2_BUCKET:-}"
+BACKUP_B2_KEY_ID="${BACKUP_B2_KEY_ID:-}"
+BACKUP_B2_APPLICATION_KEY="${BACKUP_B2_APPLICATION_KEY:-}"
+BACKUP_SFTP_HOST="${BACKUP_SFTP_HOST:-}"
+BACKUP_SFTP_PORT="${BACKUP_SFTP_PORT:-22}"
+BACKUP_SFTP_USER="${BACKUP_SFTP_USER:-}"
+BACKUP_SFTP_KEY="${BACKUP_SFTP_KEY:-}"
+BACKUP_SFTP_PATH="${BACKUP_SFTP_PATH:-}"
+NTFY_URL="${NTFY_URL:-}"
+NTFY_TOPIC="${NTFY_TOPIC:-homelab-backup}"
+RESTIC_PASSWORD="${RESTIC_PASSWORD:-}"
+RESTIC_REPOSITORY="${RESTIC_REPOSITORY:-}"
+
+# Timestamp
+TIMESTAMP=$(date +%Y%m%d_%H%M%S)
+DATE=$(date +%Y-%m-%d)
+
+# Colors
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
+log_debug() {
+    echo -e "${BLUE}[DEBUG]${NC} $*"
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
+    if [[ -n "${NTFY_URL}" ]]; then
+        local priority="default"
+        [[ "${status}" == "failed" ]] && priority="high"
+        [[ "${status}" == "success" ]] && priority="default"
+        
+        curl -s -X POST \
+            -H "Title: Backup ${status}" \
+            -H "Priority: ${priority}" \
+            -H "Tags: backup,${status}" \
+            --data-binary "${message}" \
+            "${NTFY_URL}/${NTFY_TOPIC}" >/dev/null 2>&1 || true
+    fi
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
+用法:
+  backup.sh --target <stack|all> [选项]
+
+选项:
+  --target all          备份所有 stack 数据卷
+  --target media        仅备份媒体栈
+  --target storage      仅备份存储栈
+  --target monitoring   仅备份监控栈
+  --target sso          仅备份 SSO 栈
+  --dry-run             显示将备份的内容，不实际执行
+  --restore <backup_id> 从指定备份恢复
+  --list                列出所有备份
+  --verify              验证备份完整性
+  --prune               清理过期备份
+  -h, --help            显示此帮助信息
+
+环境变量 (通过 .env 配置):
+  BACKUP_TARGET         备份目标: local, s3, b2, sftp (默认: local)
+  BACKUP_DIR            本地备份目录 (默认: ./backups)
+  BACKUP_RETENTION_DAYS 保留天数 (默认: 30)
+  BACKUP_ENCRYPT_PASSWORD 备份加密密码
+  BACKUP_S3_BUCKET      S3/MinIO 存储桶
+  BACKUP_S3_ENDPOINT    S3/MinIO 端点
+  BACKUP_S3_ACCESS_KEY  S3/MinIO Access Key
+  BACKUP_S3_SECRET_KEY  S3/MinIO Secret Key
+  BACKUP_B2_BUCKET      Backblaze B2 存储桶
+  BACKUP_B2_KEY_ID      B2 Key ID
+  BACKUP_B2_APPLICATION_KEY B2 Application Key
+  BACKUP_SFTP_HOST      SFTP 主机
+  BACKUP_SFTP_PORT      SFTP 端口 (默认: 22)
+  BACKUP_SFTP_USER      SFTP 用户名
+  BACKUP_SFTP_KEY       SFTP 私钥路径
+  BACKUP_SFTP_PATH      SFTP 远程路径
+  NTFY_URL              ntfy 服务器 URL
+  NTFY_TOPIC            ntfy 主题 (默认: homelab-backup)
+  RESTIC_PASSWORD       Restic 仓库密码
+  RESTIC_REPOSITORY     Restic 仓库路径
+EOF
+}
+
+# ============================================
+# Stack Discovery
+# ============================================
+
+get_stack_volumes() {
+    local stack="$1"
+    local compose_file="${PROJECT_ROOT}/stacks/${stack}/docker-compose.yml"
+    
+    if [[ ! -f "${compose_file}" ]]; then
+        log_error "Stack ${stack} not found"
+        return 1
+    fi
+    
+    # Extract named volumes from docker-compose.yml
+    grep -E '^\s+- .*_data:|\s+[a-zA-Z0-9_]+_data:' "${compose_file}" 2>/dev/null | \
+        sed 's/.*- //;s/:.*//' | sort -u || true
+}
+
+get_all_stacks() {
+    local stacks=()
+    for dir in "${PROJECT_ROOT}"/stacks/*/; do
+       