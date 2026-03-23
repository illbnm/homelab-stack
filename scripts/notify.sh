#!/usr/bin/env bash
# =============================================================================
# HomeLab Notify — 统一通知接口
# 支持：ntfy, Gotify
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
ENV_FILE="$SCRIPT_DIR/../config/.env"

[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"

# 通知配置
NTFY_URL="${NTFY_URL:-https://ntfy.sh}"
NTFY_TOPIC="${NTFY_TOPIC:-homelab}"
GOTIFY_URL="${GOTIFY_URL:-}"
GOTIFY_TOKEN="${GOTIFY_TOKEN:-}"

# 优先级映射
declare -A PRIORITY_MAP=(
  [1]="min"
  [2]="low"
  [3]="default"
  [4]="high"
  [5]="urgent"
)

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[notify]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[notify]${NC} $*"; }
log_error() { echo -e "${RED}[notify]${NC} $*" >&2; }

# 发送 ntfy 通知
send_ntfy() {
  local topic="$1"
  local title="$2"
  local message="$3"
  local priority="${4:-3}"
  
  log_info "Sending ntfy notification to: $topic..."
  
  curl -s \
    -H "Title: $title" \
    -H "Priority: ${PRIORITY_MAP[$priority]:-default}" \
    -d "$message" \
    "$NTFY_URL/$topic" || log_warn "ntfy notification failed"
}

# 发送 Gotify 通知
send_gotify() {
  local title="$1"
  local message="$2"
  local priority="${3:-3}"
  
  if [[ -z "$GOTIFY_URL" || -z "$GOTIFY_TOKEN" ]]; then
    log_warn "Gotify not configured, skipping..."
    return 0
  fi
  
  log_info "Sending Gotify notification..."
  
  curl -s -X POST "$GOTIFY_URL/message" \
    -H "Content-Type: application/json" \
    -H "X-Gotify-Key: $GOTIFY_TOKEN" \
    -d "{
      \"title\": \"$title\",
      \"message\": \"$message\",
      \"priority\": $priority
    }" || log_warn "Gotify notification failed"
}

# 显示帮助
show_help() {
  cat << EOF
HomeLab Notify — 统一通知接口

用法:
  $0 <topic> <title> <message> [priority]

参数:
  topic     通知主题 (ntfy topic)
  title     通知标题
  message   通知内容
  priority  优先级 1-5 (默认：3)

环境变量:
  NTFY_URL      ntfy 服务器地址 (默认：https://ntfy.sh)
  NTFY_TOPIC    默认 ntfy topic
  GOTIFY_URL    Gotify 服务器地址
  GOTIFY_TOKEN  Gotify API Token

示例:
  $0 homelab-test "Test" "Hello World"
  $0 homelab-alert "Warning" "Disk space low" 4
  $0 homelab-backup "Backup Complete" "All files backed up"

EOF
}

# 主逻辑
if [[ $# -lt 3 ]]; then
  log_error "Not enough arguments"
  show_help
  exit 1
fi

if [[ "$1" == "--help" || "$1" == "-h" ]]; then
  show_help
  exit 0
fi

TOPIC="${1:-$NTFY_TOPIC}"
TITLE="$2"
MESSAGE="$3"
PRIORITY="${4:-3}"

# 发送到所有配置的通知服务
send_ntfy "$TOPIC" "$TITLE" "$MESSAGE" "$PRIORITY"
send_gotify "$TITLE" "$MESSAGE" "$PRIORITY"

log_info "Notification sent: [$TOPIC] $TITLE"
