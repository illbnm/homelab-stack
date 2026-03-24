#!/bin/bash
# Homelab Unified Notification Script
# 用法：./notify.sh <topic> <title> <message> [priority]
# 优先级：1=min, 2=low, 3=default, 4=high, 5=urgent

set -e

# 配置
NTFY_URL="${NTFY_URL:-http://ntfy:80}"
GOTIFY_URL="${GOTIFY_URL:-http://gotify:80}"
GOTIFY_TOKEN="${GOTIFY_TOKEN:-}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查参数
if [ $# -lt 3 ]; then
    echo -e "${RED}用法：$0 <topic> <title> <message> [priority]${NC}"
    echo "  topic    - 通知主题（如：homelab-alerts）"
    echo "  title    - 通知标题"
    echo "  message  - 通知内容"
    echo "  priority - 优先级 (1-5, 默认：3)"
    exit 1
fi

TOPIC="$1"
TITLE="$2"
MESSAGE="$3"
PRIORITY="${4:-3}"

# 优先级映射
case $PRIORITY in
    1) PRIORITY_NAME="min" ;;
    2) PRIORITY_NAME="low" ;;
    3) PRIORITY_NAME="default" ;;
    4) PRIORITY_NAME="high" ;;
    5) PRIORITY_NAME="urgent" ;;
    *) PRIORITY_NAME="default" ;;
esac

# 发送 ntfy 通知
send_ntfy() {
    echo -e "${GREEN}📤 发送 ntfy 通知...${NC}"
    curl -s -X POST \
        -H "Title: $TITLE" \
        -H "Priority: $PRIORITY" \
        -d "$MESSAGE" \
        "$NTFY_URL/$TOPIC"
    echo -e "${GREEN}✓ ntfy 发送成功${NC}"
}

# 发送 Gotify 通知
send_gotify() {
    if [ -z "$GOTIFY_TOKEN" ]; then
        echo -e "${YELLOW}⚠️  跳过 Gotify（未设置 GOTIFY_TOKEN）${NC}"
        return
    fi
    
    echo -e "${GREEN}📤 发送 Gotify 通知...${NC}"
    curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "{\"title\":\"$TITLE\",\"message\":\"$MESSAGE\",\"priority\":$PRIORITY}" \
        "$GOTIFY_URL/message?token=$GOTIFY_TOKEN" > /dev/null
    echo -e "${GREEN}✓ Gotify 发送成功${NC}"
}

# 主逻辑
echo "========================================"
echo "🔔 Homelab 统一通知"
echo "========================================"
echo "主题：$TOPIC"
echo "标题：$TITLE"
echo "内容：$MESSAGE"
echo "优先级：$PRIORITY ($PRIORITY_NAME)"
echo "========================================"

# 发送到所有服务
send_ntfy
send_gotify

echo "========================================"
echo "✅ 通知发送完成"
echo "========================================"
