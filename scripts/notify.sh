#!/usr/bin/env bash

# ============================================================================
# 统一通知中心脚本
# 支持 ntfy 和 gotify 双通道，自动降级
#
# 用法:
#   notify.sh <topic> <title> <message> [priority]
#
# 示例:
#   notify.sh backup-complete "Backup Done" "Daily backup completed successfully" high
#   notify.sh alert "High CPU" "CPU usage > 90% for 5min" urgent
#
# 优先级: low, normal, high, urgent (默认: normal)
# ============================================================================

set -euo pipefail

# 配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pcd)"
STACKS_DIR="${SCRIPT_DIR}/.."
NOTIFICATIONS_ENV="${STACKS_DIR}/notifications/.env"

# 加载环境变量
if [ -f "${NOTIFICATIONS_ENV}" ]; then
  set -a
  source "${NOTIFICATIONS_ENV}"
  set +a
fi

# 默认值
DOMAIN="${DOMAIN:-localhost}"
NTFY_URL="${NTFY_URL:-https://ntfy.${DOMAIN}}"
GOTIFY_URL="${GOTIFY_URL:-http://gotify.${DOMAIN}}"
DEFAULT_TOPIC="${DEFAULT_TOPIC:-homelab-alerts}"

# 参数检查
if [ $# -lt 3 ]; then
  echo "Usage: $0 <topic> <title> <message> [priority]"
  echo "Example: $0 backup-complete 'Backup Done' 'Success' high"
  exit 1
fi

TOPIC="${1}"
TITLE="${2}"
MESSAGE="${3}"
PRIORITY="${4:-normal}"

# 映射优先级到各平台
declare -A PRIORITY_MAP_NTFY
PRIORITY_MAP_NTFY=(
  [low]="min"
  [normal]="default"
  [high]="high"
  [urgent]="max"
)

PRIORITY_MAP_GOTIFY=(
  [low]="0"
  [normal]="5"
  [high]="10"
  [urgent]="15"
)

NTFY_PRIORITY="${PRIORITY_MAP_NTFY[$PRIORITY]}"
GOTIFY_PRIORITY="${PRIORITY_MAP_GOTIFY[$PRIORITY]}"

# 发送到 ntfy
send_ntfy() {
  local url="${NTFY_URL}/${TOPIC}"
  local priority_val="${NTFY_PRIORITY:-default}"

  curl -s -X POST \
    -H "Title: ${TITLE}" \
    -H "Priority: ${priority_val}" \
    -H "Tags: ${PRIORITY}" \
    -d "${MESSAGE}" \
    "${url}" > /dev/null 2>&1 && return 0 || return 1
}

# 发送到 gotify
send_gotify() {
  local url="${GOTIFY_URL}/message"
  local priority_val="${GOTIFY_PRIORITY:-5}"

  curl -s -X POST \
    -F "title=${TITLE}" \
    -F "message=${MESSAGE}" \
    -F "priority=${priority_val}" \
    "${url}" > /dev/null 2>&1 && return 0 || return 1
}

# 主逻辑: 先 ntfy 失败则用 gotify
if send_ntfy; then
  echo "[OK] Notification sent via ntfy to topic '${TOPIC}'"
  exit 0
fi

if send_gotify; then
  echo "[OK] Notification sent via gotify (ntfy failed)"
  exit 0
fi

echo "[ERROR] Both ntfy and gotify failed"
exit 1