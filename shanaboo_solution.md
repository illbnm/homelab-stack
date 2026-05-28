```diff
--- /dev/null
+++ b/scripts/backup.sh
@@ -0,0 +1,507 @@
+#!/usr/bin/env bash
+set -euo pipefail
+
+# ==============================================================================
+# HomeLab Stack — Backup & Disaster Recovery Script
+# 3-2-1 Backup Strategy: 3 copies, 2 media types, 1 offsite
+# ==============================================================================
+
+SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
+REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
+STACKS_DIR="${REPO_ROOT}/stacks"
+CONFIG_DIR="${REPO_ROOT}/config"
+BACKUP_DIR="${REPO_ROOT}/backups"
+LOG_DIR="${REPO_ROOT}/logs"
+ENV_FILE="${REPO_ROOT}/.env"
+
+# Load environment variables
+if [[ -f "${ENV_FILE}" ]]; then
+  # shellcheck source=/dev/null
+  source "${ENV_FILE}"
+fi
+
+# Default configuration
+: "${BACKUP_TARGET:=local}"
+: "${BACKUP_RETENTION_DAYS:=30}"
+: "${BACKUP_ENCRYPT:=true}"
+: "${BACKUP_PASSPHRASE:=}"
+: "${NTFY_URL:=}"
+: "${NTFY_TOPIC:=homelab-backups}"
+: "${NTFY_TOKEN:=}"
+: "${BACKUP_S3_ENDPOINT:=}"
+: "${BACKUP_S3_BUCKET:=}"
+: "${BACKUP_S3_ACCESS_KEY:=}"
+: "${BACKUP_S3_SECRET_KEY:=}"
+: "${BACKUP_S3_REGION:=us-east-1}"
+: "${BACKUP_B2_ACCOUNT_ID:=}"
+: "${BACKUP_B2_APPLICATION_KEY:=}"
+: "${BACKUP_B2_BUCKET:=}"
+: "${BACKUP_SFTP_HOST:=}"
+: "${BACKUP_SFTP_PORT:=22}"
+: "${BACKUP_SFTP_USER:=}"
+: "${BACKUP_SFTP_KEY:=}"
+: "${BACKUP_SFTP_PATH:=}"
+: "${BACKUP_LOCAL_PATH:=${BACKUP_DIR}}"
+: "${RESTIC_REPOSITORY:=}"
+: "${RESTIC_PASSWORD:=}"
+: "${DUPLICATI_URL:=http://localhost:8200}"
+: "${DUPLICATI_API_KEY:=}"
+
+# Colors for output
+RED='\033[0;31m'
+GREEN='\033[0;32m'
+YELLOW='\033[1;33m'
+BLUE='\033[0;34m'
+NC='\033[0m' # No Color
+
+# ==============================================================================
+# Logging & Notifications
+# ==============================================================================
+
+log() {
+  local level="$1"
+  shift
+  local msg="$*"
+  local timestamp
+  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
+  case "$level" in
+    INFO)  echo -e "${GREEN}[${timestamp}] [INFO]${NC} $msg" ;;
+    WARN)  echo -e "${YELLOW}[${timestamp}] [WARN]${NC} $msg" ;;
+    ERROR) echo -e "${RED}[${timestamp}] [ERROR]${NC} $msg" ;;
+    DEBUG) echo -e "${BLUE}[${timestamp}] [DEBUG]${NC} $msg" ;;
+  esac
+  # Write to log file
+  mkdir -p "${LOG_DIR}"
+  echo "[${timestamp}] [${level}] $msg" >> "${LOG_DIR}/backup.log"
+}
+
+notify() {
+  local status="$1"
+  local message="$2"
+  
+  if [[ -z "${NTFY_URL}" ]]; then
+    log "DEBUG" "No NTFY_URL configured, skipping notification"
+    return 0
+  fi
+
+  local ntfy_full_url="${NTFY_URL}/${NTFY_TOPIC}"
+  local priority="default"
+  local tags=""
+  
+  case "$status" in
+    success)
+      priority="low"
+      tags="white_check_mark"
+      ;;
+    failure)
+      priority="high"
+      tags="x,fire"
+      ;;
+    warning)
+      priority="default"
+      tags="warning"
+      ;;
+  esac
+
+  local curl_opts=(-s -o /dev/null -w "%{http_code}")
+  local headers=(
+    -H "Title: HomeLab Backup ${status^^}"
+    -H "Priority: ${priority}"
+  )
+  
+  [[ -n "${tags}" ]] && headers+=(-H "Tags: ${tags}")
+  [[ -n "${NTFY_TOKEN}" ]] && headers+=(-H "Authorization: Bearer ${NTFY_TOKEN}")
+
+  local http_code
+  http_code=$(curl "${curl_opts[@]}" "${headers[@]}" -d "${message}" "${ntfy_full_url}")
+  
+  if [[ "${http_code}" == "200" || "${http_code}" == "202" ]]; then
+    log "INFO" "Notification sent successfully"
+  else
+    log "WARN" "Failed to send notification (HTTP ${http_code})"
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
+  $(basename "$0") --target <stack|all> [options]
+
+Targets:
+  all              Backup all stack data volumes
+  <stack_name>     Backup specific stack (e.g., media, storage, monitoring)
+
+Options:
+  --dry-run         Show what would be backed up, don't actually execute
+  --restore <id>    Restore from specified backup ID
+  --list            List all available backups
+  --verify          Verify backup integrity
+  --target <name>   Specify target (alias for positional arg)
+  -h, --help        Show this help message
+
+Examples:
+  $(basename "$0") --target all
+  $(basename "$0") --target media --dry-run
+  $(basename "$0") --target storage --restore latest
+  $(basename "$0") --list
+EOF
+}
+
+check_dependencies() {
+  local deps=("docker" "docker-compose" "curl")
+  for dep in "${deps[@]}"; do
+    if ! command -v "$dep" &>/dev/null; then
+      log "ERROR" "Required dependency not found: $dep"
+      exit 1
+    fi
+  done
+
+  # Check for restic if using restic-based targets
+  if [[ "${BACKUP_TARGET}" == "s3" || "${BACKUP_TARGET}" == "b2" || "${BACKUP_TARGET}" == "sftp" ]]; then
+    if ! command -v restic &>/dev/null; then
+      log "WARN" "restic not found, attempting to use Docker version"
+    fi
+  fi
+}
+
+get_stack_volumes() {
+  local stack="$1"
+