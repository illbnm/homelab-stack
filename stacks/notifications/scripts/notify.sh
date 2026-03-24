#!/bin/bash
# Homelab Unified Notification Script
# 用法：./notify.sh <topic> <title> <message> [priority]

set -e

NTFY_URL="${NTFY_URL:-http://ntfy:80}"

if [ $# -lt 3 ]; then
    echo "用法：$0 <topic> <title> <message> [priority]"
    exit 1
fi

TOPIC="$1"
TITLE="$2"
MESSAGE="$3"
PRIORITY="${4:-3}"

echo "🔔 发送通知到：$TOPIC"
curl -s -X POST -H "Title: $TITLE" -H "Priority: $PRIORITY" -d "$MESSAGE" "$NTFY_URL/$TOPIC"
echo "✅ 发送成功"
