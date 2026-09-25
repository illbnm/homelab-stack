#!/usr/bin/env bash
set -euo pipefail

TOPIC="${1:?topic required}"
TITLE="${2:?title required}"
MESSAGE="${3:?message required}"
PRIORITY="${4:-default}"

curl -fsS \
  -H "Title: ${TITLE}" \
  -H "Priority: ${PRIORITY}" \
  -d "${MESSAGE}" \
  "https://ntfy.${DOMAIN}/${TOPIC}"
