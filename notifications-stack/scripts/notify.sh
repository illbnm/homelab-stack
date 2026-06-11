#!/bin/bash
TOPIC="$1"
TITLE="$2"
MESSAGE="$3"
PRIORITY="${4:-default}"
curl -s -H "Title: $TITLE" -H "Priority: $PRIORITY" -d "$MESSAGE" "https://ntfy.localhost/$TOPIC" > /dev/null 2>&1
