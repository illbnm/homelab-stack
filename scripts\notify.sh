#!/usr/bin/env bash
# =============================================================================
# notify.sh — 统一通知发送脚本
# =============================================================================
#
# 用法:
#   scripts/notify.sh <topic> <title> <message> [priority] [tags] [backend]
#
# 参数:
#   topic     ntfy 主题名称 (例: homelab-alerts, homelab-test)
#   title     通知标题
#   message   通知正文
#   priority  优先级: min|low|default|high|urgent (默认: default)
#   tags      标签，逗号分隔 (默认: white_check_mark)
#   backend   通知后端: ntfy|gotify|all (默认: ntfy)
#
# 示例:
#   scripts/notify.sh homelab-test "Test" "Hello World"
#   scripts/notify.sh homelab-alerts "CPU High" "CPU usage > 90%" urgent warning
#   scripts/notify.sh homelab-test "Deploy Done" "v1.2.0 deployed" default rocket all
#
# 环境变量 (可在 .env 中配置):
#   NTFY_URL          ntfy 服务地址 (默认: http://localhost:2586)
#   NTFY_TOKEN        ntfy 认证 token
#   NTFY_USER         ntfy 用户名 (token 优先)
#   NTFY_PASS         ntfy 密码
#   GOTIFY_URL        Gotify 服务地址 (默认: http://localhost:8070)
#   GOTIFY_TOKEN      Gotify 应用 token
#   NOTIFY_BACKEND    默认后端: ntfy|gotify|all (默认: ntfy)
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# 颜色输出
# -----------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# -----------------------------------------------------------------------------
# 加载 .env 文件（脚本相对路径向上查找项目根目录）
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ -f "${PROJECT_ROOT}/.env" ]]; then
  # 只导出非注释、非空行的变量
  set -a
  # shellcheck disable=SC1091
  source <(grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "${PROJECT_ROOT}/.env" | grep -v '^#')
  set +a
fi

# -----------------------------------------------------------------------------
# 参数解析
# -----------------------------------------------------------------------------
usage() {
  cat <<EOF
用法: $(basename "$0") <topic> <title> <message> [priority] [tags] [backend]

参数:
  topic     ntfy 主题名称 (例: homelab-alerts, homelab-test)
  title     通知标题
  message   通知正文
  priority  优先级: min|low|default|high|urgent  (默认: default)
  tags      标签，逗号分隔                        (默认: white_check_mark)
  backend   通知后端: ntfy|gotify|all             (默认: ntfy)

示例:
  $(basename "$0") homelab-test "Test" "Hello World"
  $(basename "$0") homelab-alerts "CPU High" "CPU > 90%" urgent warning
  $(basename "$0") homelab-test "Deploy" "Done" default rocket all

环境变量:
  NTFY_URL       ntfy 地址    (默认: http://localhost:2586)
  NTFY_TOKEN     ntfy token   (优先于用户名密码)
  NTFY_USER      ntfy 用户名
  NTFY_PASS      ntfy 密码
  GOTIFY_URL     Gotify 地址  (默认: http://localhost:8070)
  GOTIFY_TOKEN   Gotify token
  NOTIFY_BACKEND 默认后端     (默认: ntfy)
EOF
  exit 1
}

if [[ $# -lt 3 ]]; then
  log_error "参数不足"
  usage
fi

TOPIC="${1}"
TITLE="${2}"
MESSAGE="${3}"
PRIORITY="${4:-default}"
TAGS="${5:-white_check_mark}"
BACKEND="${6:-${NOTIFY_BACKEND:-ntfy}}"

# -----------------------------------------------------------------------------
# 配置默认值
# -----------------------------------------------------------------------------
NTFY_URL="${NTFY_URL:-http://localhost:2586}"
NTFY_TOKEN="${NTFY_TOKEN:-}"
NTFY_USER="${NTFY_USER:-}"
NTFY_PASS="${NTFY_PASS:-}"

GOTIFY_URL="${GOTIFY_URL:-http://localhost:8070}"
GOTIFY_TOKEN="${GOTIFY_TOKEN:-}"

# -----------------------------------------------------------------------------
# 校验优先级
# -----------------------------------------------------------------------------
validate_priority() {
  local p="$1"
  case "${p}" in
    min|low|default|high|urgent) return 0 ;;
    1|2|3|4|5) return 0 ;;
    *) log_warn "未知优先级 '${p}'，使用 default"; PRIORITY="default" ;;
  esac
}
validate_priority "${PRIORITY}"

# -----------------------------------------------------------------------------
# 将 ntfy 优先级映射到 Gotify 优先级 (1-10)
# -----------------------------------------------------------------------------
ntfy_priority_to_gotify() {
  case "$1" in
    min)     echo 1 ;;
    low)     echo 3 ;;
    default) echo 5 ;;
    high)    echo 7 ;;
    urgent)  echo 10 ;;
    *)       echo 5 ;;
  esac
}

# -----------------------------------------------------------------------------
# 发送到 ntfy
# -----------------------------------------------------------------------------
send_ntfy() {
  local url="${NTFY_URL}/${TOPIC}"
  local curl_auth_args=()

  # 认证方式：token 优先，其次用户名密码
  if [[ -n "${NTFY_TOKEN}" ]]; then
    curl_auth_args+=(-H "Authorization: Bearer ${NTFY_TOKEN}")
  elif [[ -n "${NTFY_USER}" && -n "${NTFY_PASS}" ]]; then
    curl_auth_args+=(-u "${NTFY_USER}:${NTFY_PASS}")
  fi

  log_info "发送 ntfy 通知 → ${url}"

  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" \
    --max-time 15 \
    --retry 2 \
    --retry-delay 2 \
    -X POST "${url}" \
    "${curl_auth_args[@]}" \
    -H "Title: ${TITLE}" \
    -H "Priority: ${PRIORITY}" \
    -H "Tags: ${TAGS}" \
    -d "${MESSAGE}" \
    2>/dev/null) || {
      log_error "ntfy 请求失败（网络错误）"
      return 1
    }

  if [[ "${http_code}" =~ ^2 ]]; then
    log_success "ntfy 发送成功 (HTTP ${http_code})"
    return 0
  else
    log_error "ntfy 发送失败 (HTTP ${http_code})"
    return 1
  fi
}

# -----------------------------------------------------------------------------
# 发送到 Gotify
# -----------------------------------------------------------------------------
send_gotify() {
  if [[ -z "${GOTIFY_TOKEN}" ]]; then
    log_warn "GOTIFY_TOKEN 未配置，跳过 Gotify 通知"
    return 1
  fi

  local gotify_priority
  gotify_priority=$(ntfy_priority_to_gotify "${PRIORITY}")
  local url="${GOTIFY_URL}/message"

  log_info "发送 Gotify 通知 → ${url}"

  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" \
    --max-time 15 \
    --retry 2 \
    --retry-delay 2 \
    -X POST "${url}" \
    -H "X-Gotify-Key: ${GOTIFY_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
      \"title\": \"${TITLE}\",
      \"message\": \"${MESSAGE}\",
      \"priority\": ${gotify_priority},
      \"extras\": {
        \"client::display\": {
          \"contentType\": \"text/plain\"
        }
      }
    }" \
    2>/dev/null) || {
      log_error "Gotify 请求失败（网络错误）"
      return 1
    }

  if [[ "${http_code}" =~ ^2 ]]; then
    log_success "Gotify 发送成功 (HTTP ${http_code})"
    return 0
  else
    log_error "Gotify 发送失败 (HTTP ${http_code})"
    return 1
  fi
}

# -----------------------------------------------------------------------------
# 主逻辑 — 根据 backend 参数发送
# -----------------------------------------------------------------------------
EXIT_CODE=0

case "${BACKEND}" in
  ntfy)
    send_ntfy || EXIT_CODE=1
    ;;
  gotify)
    send_gotify || EXIT_CODE=1
    ;;
  all)
    # 两个后端都尝试，任一成功则认为成功
    NTFY_RESULT=0
    GOTIFY_RESULT=0
    send_ntfy   || NTFY_RESULT=1
    send_gotify || GOTIFY_RESULT=1
    # 只要有一个成功就算成功
    if [[ ${NTFY_RESULT} -eq 1 && ${GOTIFY_RESULT} -eq 1 ]]; then
      EXIT_CODE=1
    fi
    ;;
  *)
    log_error "未知 backend: '${BACKEND}'，支持: ntfy|gotify|all"
    EXIT_CODE=1
    ;;
esac

# -----------------------------------------------------------------------------
# 输出摘要
# -----------------------------------------------------------------------------
if [[ ${EXIT_CODE} -eq 0 ]]; then
  log_success "通知已发送: [${BACKEND}] ${TOPIC} — ${TITLE}"
else
  log_error "通知发送失败: [${BACKEND}] ${TOPIC} — ${TITLE}"
fi

exit ${EXIT_CODE}
