#!/bin/bash

# Usage: scripts/notify.sh <topic> <title> <message> [priority]

TOPIC=$1
TITLE=$2
MESSAGE=$3
PRIORITY=${4:-3}

curl -X POST \
  -H "Title: $TITLE" \
  -H "Priority: $PRIORITY" \
  -d "$MESSAGE" \
  https://ntfy.${DOMAIN}/$TOPIC