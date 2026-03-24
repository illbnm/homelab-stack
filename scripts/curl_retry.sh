#!/usr/bin/env bash
# curl_retry.sh — Retry wrapper for curl with exponential backoff
# Usage: source this file, then call curl_retry [curl args...]
# Example: source scripts/curl_retry.sh && curl_retry -o file.tar.gz https://example.com/file.tar.gz

curl_retry() {
  local max_attempts="${CURL_RETRY_MAX:-3}"
  local delay="${CURL_RETRY_DELAY:-5}"

  for i in $(seq 1 "$max_attempts"); do
    if curl --connect-timeout 10 --max-time 60 "$@"; then
      return 0
    fi

    if [[ $i -lt $max_attempts ]]; then
      echo "Attempt $i failed, retrying in ${delay}s..." >&2
      sleep "$delay"
      delay=$((delay * 2))
    fi
  done

  echo "All $max_attempts attempts failed." >&2
  return 1
}
