#!/usr/bin/env bash

TOPIC=$1
TITLE=$2
MESSAGE=$3
PRIORITY=${4:-3}

if [ -z "$TOPIC" ] || [ -z "$TITLE" ] || [ -z "$MESSAGE" ]; then
  echo "Usage: $0 <topic> <title> <message> [priority]"
  exit 1
fi

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$DIR/../.env" ]; then
  source "$DIR/../.env"
fi

DOMAIN=${DOMAIN:-localhost}

curl -s \
  -H "Title: ${TITLE}" \
  -H "Priority: ${PRIORITY}" \
  -d "${MESSAGE}" \
  "https://ntfy.${DOMAIN}/${TOPIC}"
