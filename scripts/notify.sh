#!/bin/bash

# Usage: scripts/notify.sh <topic> <title> <message> [priority]

TOPIC=$1
TITLE=$2
MESSAGE=$3
PRIORITY=${4:-3}

curl -X POST -d "topic=${TOPIC}&title=${TITLE}&message=${MESSAGE}&priority=${PRIORITY}" https://ntfy.${DOMAIN}
