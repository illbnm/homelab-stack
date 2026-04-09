#!/bin/bash
set -euo pipefail

# This script sets up monitors and notification channels in Uptime Kuma
#
# Prerequisites:
# - Uptime Kuma is running and accessible.
# - Uptime Kuma API Key is generated and available as UPTIME_KUMA_API_KEY.
# - DOMAIN environment variable is set for constructing service URLs.

echo "🚀 Starting Uptime Kuma setup script..."

# Load environment variables (assuming .env is in the parent directory)
if [ -f .env ]; then
  source .env
elif [ -f ../.env ]; then
  source ../.env
elif [ -f ../../.env ]; then
  source ../../.env
else
  echo "Error: .env file not found. Please ensure it's in the script's directory or a parent."
  exit 1
fi

# Check required environment variables
: "${DOMAIN:?DOMAIN not set. Please set the primary domain (e.g., yourdomain.com)}"
: "${UPTIME_KUMA_API_KEY:?UPTIME_KUMA_API_KEY not set. Generate one in Uptime Kuma settings.}"
: "${UPTIME_KUMA_URL:?UPTIME_KUMA_URL not set. e.g. http://uptime-kuma:3001}"
: "${NTFY_TOPIC:?NTFY_TOPIC not set. e.g. homelab-alerts}"
: "${NTFY_BASE_URL:?NTFY_BASE_URL not set. e.g. https://ntfy.sh}"

UPTIME_KUMA_API="${UPTIME_KUMA_URL}/api/v1"

echo "Uptime Kuma API: ${UPTIME_KUMA_API}"

# --- 1. Get Uptime Kuma Token ---
echo "🔑 Getting Uptime Kuma API token..."
API_RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" -d "{\"jwt\":\"${UPTIME_KUMA_API_KEY}\"}" "${UPTIME_KUMA_API}/user/login" || true)

# Check if API_RESPONSE is empty or an error
if [ -z "$API_RESPONSE" ]; then
    echo "Error: Failed to connect to Uptime Kuma API. Is Uptime Kuma running at ${UPTIME_KUMA_URL}?"
    exit 1
fi

TOKEN=$(echo "$API_RESPONSE" | jq -r '.token')

if [ "$TOKEN" == "null" ] || [ -z "$TOKEN" ]; then
    echo "Error: Failed to obtain Uptime Kuma API token. Check UPTIME_KUMA_API_KEY."
    echo "API Response: $API_RESPONSE"
    exit 1
fi
echo "✅ Token obtained."

HEADERS=(-H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json")

# --- 2. Create Notification Channel (ntfy) ---
echo "🔔 Creating/updating ntfy notification channel..."
NTFY_CHANNEL_NAME="Ntfy Alerts"
NTFY_PAYLOAD=$(cat <<EOF
{
  "name": "${NTFY_CHANNEL_NAME}",
  "type": "ntfy",
  "is_default": true,
  "active": true,
  "config": {
    "ntfyURL": "${NTFY_BASE_URL}",
    "topic": "${NTFY_TOPIC}",
    "autoPush": true
  }
}
EOF
)

# Check if ntfy channel already exists
CHANNEL_ID=$(curl -s "${HEADERS[@]}" "${UPTIME_KUMA_API}/notification" | jq -r ".[] | select(.name == \"${NTFY_CHANNEL_NAME}\") | .id")

if [ -z "$CHANNEL_ID" ]; then
  echo "  Ntfy channel not found, creating..."
  CREATE_RESPONSE=$(curl -s -X POST "${HEADERS[@]}" -d "$NTFY_PAYLOAD" "${UPTIME_KUMA_API}/notification")
  CHANNEL_ID=$(echo "$CREATE_RESPONSE" | jq -r '.id')
  if [ "$CHANNEL_ID" == "null" ] || [ -z "$CHANNEL_ID" ]; then
      echo "  Error creating ntfy channel: $(echo "$CREATE_RESPONSE" | jq -r '.message')"
      exit 1
  fi
  echo "  Ntfy channel created with ID: ${CHANNEL_ID}"
else
  echo "  Ntfy channel '${NTFY_CHANNEL_NAME}' already exists (ID: ${CHANNEL_ID}), updating..."
  UPDATE_RESPONSE=$(curl -s -X PUT "${HEADERS[@]}" -d "$NTFY_PAYLOAD" "${UPTIME_KUMA_API}/notification/${CHANNEL_ID}")
  if echo "$UPDATE_RESPONSE" | grep -q 'error'; then
      echo "  Error updating ntfy channel: $(echo "$UPDATE_RESPONSE" | jq -r '.message')"
      # Continue without exiting, as it might just be a no-change update error
  else
      echo "  Ntfy channel updated."
  fi
fi

# --- 3. Create Monitors ---
echo "🔍 Creating/updating monitors for services..."

# Define services to monitor: Name, URL, Type (http/ping), interval (seconds)
# Add other services here based on your docker-compose setup
# Example health endpoints: /-/ready, /healthz, /health
SERVICES=(
  "Prometheus,http://prometheus:9090/-/ready,http,60"
  "Grafana,https://grafana.${DOMAIN}/api/health,http,60"
  "Loki,http://loki:3100/ready,http,60"
  "Traefik,http://traefik:8080/ping,http,60"
  "Authentik,https://auth.${DOMAIN}/-/health/ready/,http,60"
  "Gitea,https://git.${DOMAIN}/api/healthz,http,60"
  # Add more services here
  # "Nextcloud,https://cloud.${DOMAIN}/status.php,http,60" # Requires specific parsing
)

for SERVICE in "${SERVICES[@]}"; do
  IFS=',' read -r NAME URL TYPE INTERVAL <<< "$SERVICE"
  echo "  Processing monitor: ${NAME} (${URL})"

  MONITOR_PAYLOAD=$(cat <<EOF
{
  "name": "${NAME}",
  "url": "${URL}",
  "type": "${TYPE}",
  "interval": ${INTERVAL},
  "maxretries": 3,
  "notificationIDList": [${CHANNEL_ID}],
  "active": true,
  "tags": ["homelab"],
  "dns_resolve_type": "A",
  "accepted_statuscodes": ["2xx"]
}
EOF
)

  MONITOR_ID=$(curl -s "${HEADERS[@]}" "${UPTIME_KUMA_API}/monitor" | jq -r ".[] | select(.name == \"${NAME}\") | .id")

  if [ -z "$MONITOR_ID" ]; then
    echo "    Monitor '${NAME}' not found, creating..."
    CREATE_RESPONSE=$(curl -s -X POST "${HEADERS[@]}" -d "$MONITOR_PAYLOAD" "${UPTIME_KUMA_API}/monitor")
    if echo "$CREATE_RESPONSE" | grep -q 'error'; then
        echo "    Error creating monitor '${NAME}': $(echo "$CREATE_RESPONSE" | jq -r '.message')"
    else
        echo "    Monitor '${NAME}' created."
    fi
  else
    echo "    Monitor '${NAME}' already exists (ID: ${MONITOR_ID}), updating..."
    UPDATE_RESPONSE=$(curl -s -X PUT "${HEADERS[@]}" -d "$MONITOR_PAYLOAD" "${UPTIME_KUMA_API}/monitor/${MONITOR_ID}")
    if echo "$UPDATE_RESPONSE" | grep -q 'error'; then
        echo "    Error updating monitor '${NAME}': $(echo "$UPDATE_RESPONSE" | jq -r '.message')"
    else
        echo "    Monitor '${NAME}' updated."
    fi
  fi
done

# --- 4. Create Public Status Page ---
echo "🌐 Creating/updating public status page..."
STATUS_PAGE_SLUG="status" # Default slug for status.${DOMAIN}
STATUS_PAGE_TITLE="HomeLab Status"

STATUS_PAGE_PAYLOAD=$(cat <<EOF
{
  "slug": "${STATUS_PAGE_SLUG}",
  "title": "${STATUS_PAGE_TITLE}",
  "domain": "status.${DOMAIN}",
  "public": true,
  "config": {
    "description": "Real-time status of HomeLab services.",
    "footerText": "Powered by Uptime Kuma",
    "theme": "dark",
    "language": "en"
  },
  "pages": [],
  "notificationIDList": [${CHANNEL_ID}]
}
EOF
)

# Check if status page already exists
PAGE_ID=$(curl -s "${HEADERS[@]}" "${UPTIME_KUMA_API}/status-page" | jq -r ".[] | select(.slug == \"${STATUS_PAGE_SLUG}\") | .id")

if [ -z "$PAGE_ID" ]; then
  echo "  Status page '${STATUS_PAGE_TITLE}' not found, creating..."
  CREATE_RESPONSE=$(curl -s -X POST "${HEADERS[@]}" -d "$STATUS_PAGE_PAYLOAD" "${UPTIME_KUMA_API}/status-page")
  if echo "$CREATE_RESPONSE" | grep -q 'error'; then
      echo "  Error creating status page: $(echo "$CREATE_RESPONSE" | jq -r '.message')"
  else
      echo "  Status page created at https://status.${DOMAIN}"
  fi
else
  echo "  Status page '${STATUS_PAGE_TITLE}' already exists (ID: ${PAGE_ID}), updating..."
  UPDATE_RESPONSE=$(curl -s -X PUT "${HEADERS[@]}" -d "$STATUS_PAGE_PAYLOAD" "${UPTIME_KUMA_API}/status-page/${PAGE_ID}")
  if echo "$UPDATE_RESPONSE" | grep -q 'error'; then
      echo "  Error updating status page: $(echo "$UPDATE_RESPONSE" | jq -r '.message')"
  else
      echo "  Status page updated at https://status.${DOMAIN}"
  fi
fi

echo "✅ Uptime Kuma setup complete."
