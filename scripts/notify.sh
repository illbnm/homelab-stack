#!/bin/bash
#
# notify.sh - 统一通知脚本
# 用法: notify.sh <topic> <title> <message> [priority]
#
# 优先级: default, low, high, urgent
#

set -e

# 配置
NTFY_URL="${NTFY_URL:-https://ntfy.${DOMAIN:-localhost}}"
APPRISE_URL="${APPRISE_URL:-https://apprise.${DOMAIN:-localhost}}"
LOG_FILE="${LOG_FILE:-/var/log/homelab/notify.log}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "[$timestamp] $*" | tee -a "$LOG_FILE" 2>/dev/null || echo -e "[$timestamp] $*"
}

# 显示用法
usage() {
    cat << EOF
用法: $0 <topic> <title> <message> [priority]

参数:
  topic     通知主题 (如: homelab-alerts)
  title     通知标题
  message   通知内容
  priority  优先级 (可选): default, low, high, urgent (默认: default)

示例:
  $0 homelab-alerts "测试通知" "Hello World"
  $0 homelab-alerts "Watchtower 更新" "容器已更新" "high"
  $0 homelab-alerts "告警" "磁盘空间不足" "urgent"

环境变量:
  NTFY_URL    ntfy 服务器 URL (默认: https://ntfy.\${DOMAIN})
  APPRISE_URL Apprise API URL (默认: https://apprise.\${DOMAIN})
  DOMAIN      域名 (用于构建 URL)
  LOG_FILE    日志文件路径 (默认: /var/log/homelab/notify.log)

EOF
    exit 1
}

# 参数检查
if [ $# -lt 3 ]; then
    echo -e "${RED}错误：参数不足${NC}"
    usage
fi

TOPIC="$1"
TITLE="$2"
MESSAGE="$3"
PRIORITY="${4:-default}"

# 验证优先级
case "$PRIORITY" in
    default|low|high|urgent)
        ;;
    *)
        echo -e "${RED}错误：无效的优先级 '$PRIORITY'${NC}"
        echo "有效值：default, low, high, urgent"
        exit 1
        ;;
esac

# 发送通知到 ntfy
send_ntfy() {
    local topic="$1"
    local title="$2"
    local message="$3"
    local priority="$4"
    
    local response
    response=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST \
        -H "Title: $title" \
        -H "Priority: $priority" \
        -d "$message" \
        "$NTFY_URL/$topic" 2>/dev/null) || {
        log "${RED}[FAIL] ntfy 请求失败${NC}"
        return 1
    }
    
    if [ "$response" = "200" ] || [ "$response" = "201" ]; then
        log "${GREEN}[OK] ntfy 推送成功${NC} -> $topic"
        return 0
    else
        log "${RED}[FAIL] ntfy 返回 HTTP $response${NC}"
        return 1
    fi
}

# 发送通知到 Apprise (备用)
send_apprise() {
    local title="$1"
    local message="$2"
    
    local response
    response=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d "{\"title\": \"$title\", \"body\": \"$message\", \"urls\": \"ntfy://$NTFY_URL/$TOPIC\"}" \
        "$APPRISE_URL/notify" 2>/dev/null) || {
        log "${YELLOW}[WARN] Apprise 请求失败 (可能未配置)${NC}"
        return 1
    }
    
    if [ "$response" = "200" ]; then
        log "${GREEN}[OK] Apprise 推送成功${NC}"
        return 0
    else
        log "${YELLOW}[WARN] Apprise 返回 HTTP $response${NC}"
        return 1
    fi
}

# 主逻辑
log "发送通知: [$PRIORITY] $TITLE - $MESSAGE"

# 尝试 ntfy
if send_ntfy "$TOPIC" "$TITLE" "$MESSAGE" "$PRIORITY"; then
    exit 0
fi

# ntfy 失败时尝试 Apprise
log "尝试通过 Apprise 发送..."
if send_apprise "$TITLE" "$MESSAGE"; then
    exit 0
fi

# 都失败
log "${RED}[FAIL] 所有通知渠道失败${NC}"
exit 1
