#!/usr/bin/env bash
# notify.sh — unified notification interface for Homelab Stack.
#   scripts/notify.sh <topic> <title> <message> [priority]
# Other scripts call this instead of hitting ntfy/Apprise APIs directly.
#
# Env (from config/.env, all optional with sane defaults):
#   NTFY_URL         default http://localhost:2586 (ntfy container port)
#   NTFY_USER / NTFY_PASSWORD   for authenticated servers (auth-default-access: deny-all)
#   APPRISE_URL      optional fallback, e.g. http://localhost:8000/notify/apprise
set -uo pipefail

usage() { echo "dùng: $0 <topic> <title> <message> [priority: min|low|default|high|urgent]" >&2; exit 1; }
[[ $# -lt 3 ]] && usage

TOPIC="$1"; TITLE="$2"; MESSAGE="$3"; PRIORITY="${4:-default}"
NTFY_URL="${NTFY_URL:-http://localhost:2586}"
CURL_OPTS=(-sf --connect-timeout 5 --max-time 15)
if [[ -n "${NTFY_USER:-}" ]]; then CURL_OPTS=("${CURL_OPTS[@]}" -u "${NTFY_USER}:${NTFY_PASSWORD:-}"); fi

if curl "${CURL_OPTS[@]}" -H "Title: $TITLE" -H "Priority: $PRIORITY" \
    -d "$MESSAGE" "$NTFY_URL/$TOPIC" >/dev/null; then
  echo "notify OK via ntfy [$TOPIC/$PRIORITY]"
  exit 0
fi

# Fallback: Apprise sidecar (caronc/apprise) if configured
if [[ -n "${APPRISE_URL:-}" ]]; then
  if curl "${CURL_OPTS[@]}" -H 'Content-Type: application/json' \
      -d "{\"body\":\"$MESSAGE\",\"title\":\"$TITLE\"}" "$APPRISE_URL" >/dev/null; then
    echo "notify OK via apprise fallback"
    exit 0
  fi
fi

echo "notify FAILED (ntfy $NTFY_URL + apprise fallback đều lỗi)" >&2
exit 1
