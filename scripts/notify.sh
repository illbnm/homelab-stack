#!/bin/bash
# 统一通知脚本，调用此接口而不是直接调用 ntfy/Gotify API
# 用法: notify.sh <topic> <title> <message> [priority]

set -e

if [ $# -lt 3 ]; then
    echo "用法: $0 <topic> <title> <message> [priority]"
    exit 1
fi

TOPIC=$1
TITLE=$2
MESSAGE=$3
PRIORITY=${4:-default}

NTFY_URL=${NTFY_URL:-"http://ntfy:80"}

curl -X POST \
    -H "Title: $TITLE" \
    -H "Priority: $PRIORITY" \
    -d "$MESSAGE" \
    "${NTFY_URL}/${TOPIC}"
