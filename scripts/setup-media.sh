#!/usr/bin/env bash
# =============================================================================
# Media Stack Service Integration Setup
# Connects: Prowlarr -> Sonarr/Radarr, qBittorrent -> Sonarr/Radarr
# Run AFTER all media stack services are healthy (5-10 min after startup)
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RESET='\033[0m'
log_ok()   { echo -e "${GREEN}[OK]${RESET} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_err()  { echo -e "${RED}[ERR]${RESET} $*" >&2; }

SONARR_URL="http://localhost:8989"
RADARR_URL="http://localhost:7878"
PROWLARR_URL="http://localhost:9696"
QBIT_URL="http://localhost:8080"

wait_for_api() {
  local name=$1 url=$2 key=$3
  local tries=0
  while [ $tries -lt 30 ]; do
    code=$(curl -sf -o /dev/null -w "%{http_code}" -H "X-Api-Key: $key" "$url/api/v3/system/status" 2>/dev/null || echo 000)
    [ "$code" = "200" ] && return 0
    tries=$((tries+1))
    sleep 5
  done
  log_err "$name API not ready after 150s"
  return 1
}

get_api_key() {
  local container=$1
  docker exec $container cat /config/config.xml 2>/dev/null | grep -oP '(?<=<ApiKey>)[^<]+' || echo ""
}

echo "Reading API keys from containers..."
SONARR_KEY=$(get_api_key sonarr)
RADARR_KEY=$(get_api_key radarr)
PROWLARR_KEY=$(get_api_key prowlarr)

[ -z "$SONARR_KEY" ]   && log_err "Sonarr API key not found — is the service initialized?" && exit 1
[ -z "$RADARR_KEY" ]   && log_err "Radarr API key not found" && exit 1
[ -z "$PROWLARR_KEY" ] && log_err "Prowlarr API key not found" && exit 1

log_ok "Got API keys: Sonarr=${SONARR_KEY:0:8}... Radarr=${RADARR_KEY:0:8}... Prowlarr=${PROWLARR_KEY:0:8}..."

# 1. Add qBittorrent to Sonarr
echo "Adding qBittorrent to Sonarr..."
curl -sf -X POST "$SONARR_URL/api/v3/downloadclient" \
  -H "X-Api-Key: $SONARR_KEY" -H "Content-Type: application/json" \
  -d "{\"name\":\"qBittorrent\",\"enable\":true,\"protocol\":\"torrent\",\"priority\":1,\"implementation\":\"QBittorrent\",\"configContract\":\"QBittorrentSettings\",\"fields\":[{\"name\":\"host\",\"value\":\"qbittorrent\"},{\"name\":\"port\",\"value\":8080},{\"name\":\"useSsl\",\"value\":false}]}" \
  2>&1 | python3 -c "import json,sys; d=json.load(sys.stdin); print('Sonarr qbit ID:', d.get('id'))" 2>/dev/null && log_ok "qBittorrent added to Sonarr" || log_warn "qBittorrent already exists in Sonarr"

# 2. Add qBittorrent to Radarr  
echo "Adding qBittorrent to Radarr..."
curl -sf -X POST "$RADARR_URL/api/v3/downloadclient" \
  -H "X-Api-Key: $RADARR_KEY" -H "Content-Type: application/json" \
  -d "{\"name\":\"qBittorrent\",\"enable\":true,\"protocol\":\"torrent\",\"priority\":1,\"implementation\":\"QBittorrent\",\"configContract\":\"QBittorrentSettings\",\"fields\":[{\"name\":\"host\",\"value\":\"qbittorrent\"},{\"name\":\"port\",\"value\":8080},{\"name\":\"useSsl\",\"value\":false}]}" \
  2>&1 | python3 -c "import json,sys; d=json.load(sys.stdin); print('Radarr qbit ID:', d.get('id'))" 2>/dev/null && log_ok "qBittorrent added to Radarr" || log_warn "qBittorrent already exists in Radarr"

# 3. Add Sonarr to Prowlarr
echo "Adding Sonarr to Prowlarr..."
curl -sf -X POST "$PROWLARR_URL/api/v1/applications" \
  -H "X-Api-Key: $PROWLARR_KEY" -H "Content-Type: application/json" \
  -d "{\"name\":\"Sonarr\",\"syncLevel\":\"fullSync\",\"implementation\":\"Sonarr\",\"configContract\":\"SonarrSettings\",\"fields\":[{\"name\":\"prowlarrUrl\",\"value\":\"http://prowlarr:9696\"},{\"name\":\"baseUrl\",\"value\":\"http://sonarr:8989\"},{\"name\":\"apiKey\",\"value\":\"$SONARR_KEY\"},{\"name\":\"syncCategories\",\"value\":[5000,5010,5020,5030,5040]}]}" \
  2>/dev/null && log_ok "Sonarr added to Prowlarr" || log_warn "Sonarr already in Prowlarr"

# 4. Add Radarr to Prowlarr
echo "Adding Radarr to Prowlarr..."
curl -sf -X POST "$PROWLARR_URL/api/v1/applications" \
  -H "X-Api-Key: $PROWLARR_KEY" -H "Content-Type: application/json" \
  -d "{\"name\":\"Radarr\",\"syncLevel\":\"fullSync\",\"implementation\":\"Radarr\",\"configContract\":\"RadarrSettings\",\"fields\":[{\"name\":\"prowlarrUrl\",\"value\":\"http://prowlarr:9696\"},{\"name\":\"baseUrl\",\"value\":\"http://radarr:7878\"},{\"name\":\"apiKey\",\"value\":\"$RADARR_KEY\"},{\"name\":\"syncCategories\",\"value\":[2000,2010,2020]}]}" \
  2>/dev/null && log_ok "Radarr added to Prowlarr" || log_warn "Radarr already in Prowlarr"

# 5. Add Jellyfin notification to Sonarr  
echo "Setting up Jellyfin media library refresh in Sonarr..."
curl -sf -X POST "$SONARR_URL/api/v3/notification" \
  -H "X-Api-Key: $SONARR_KEY" -H "Content-Type: application/json" \
  -d "{\"name\":\"Jellyfin\",\"onDownload\":true,\"onUpgrade\":true,\"implementation\":\"MediaBrowser\",\"configContract\":\"MediaBrowserSettings\",\"fields\":[{\"name\":\"host\",\"value\":\"jellyfin\"},{\"name\":\"port\",\"value\":8096},{\"name\":\"useSsl\",\"value\":false},{\"name\":\"updateLibrary\",\"value\":true}]}" \
  2>/dev/null && log_ok "Jellyfin refresh added to Sonarr" || log_warn "Already exists"

echo
log_ok "Media stack integration setup complete!"
echo "Run this script again after adding API keys to services if needed."
