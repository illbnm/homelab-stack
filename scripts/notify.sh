#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 3 ] || [ "$#" -gt 4 ]; then
  echo "Usage: $0 <topic> <title> <message> [priority]" >&2
  exit 64
fi

topic="$1"
title="$2"
message="$3"
priority="${4:-default}"

if [[ ! "$topic" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "ERROR: Topic may contain only letters, numbers, dot, underscore, and hyphen." >&2
  exit 1
fi

if [[ "$title" == *$'\n'* || "$title" == *$'\r'* || "$priority" == *$'\n'* || "$priority" == *$'\r'* ]]; then
  echo "ERROR: Title and priority must not contain newlines." >&2
  exit 1
fi

if [ -n "${NTFY_URL:-}" ]; then
  base_url="${NTFY_URL%/}"
elif [ -n "${DOMAIN:-}" ]; then
  base_url="https://ntfy.${DOMAIN}"
else
  echo "ERROR: Set NTFY_URL or DOMAIN." >&2
  exit 1
fi

curl_args=(
  --fail
  --silent
  --show-error
  --request POST
  "${base_url}/${topic}"
  --header "Title: ${title}"
  --header "Priority: ${priority}"
  --data-binary "${message}"
)

if [ -n "${NTFY_TOKEN:-}" ]; then
  curl_args+=(--header "Authorization: Bearer ${NTFY_TOKEN}")
elif [ -n "${NTFY_USER:-}" ] && [ -n "${NTFY_PASSWORD:-}" ]; then
  curl_args+=(--user "${NTFY_USER}:${NTFY_PASSWORD}")
fi

curl "${curl_args[@]}"
echo
