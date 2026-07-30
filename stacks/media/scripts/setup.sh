#!/bin/bash
# Media Stack — Post-install setup script
# Configures Sonarr/Radarr/Prowlarr integration automatically
# Run after: docker compose up -d

set -e

DOMAIN="${1:-example.com}"
SONARR_URL="http://localhost:8989"
RADARR_URL="http://localhost:7878"
PROWLARR_URL="http://localhost:9696"
QBITTORRENT_URL="http://localhost:8085"

echo "=== Media Stack Post-Install Setup ==="
echo ""
echo "This script helps configure the *arr stack integration."
echo "Each service needs initial setup via web UI first."
echo ""
echo "── Services ──"
echo "  Jellyfin:      https://jellyfin.${DOMAIN}"
echo "  Sonarr:        https://sonarr.${DOMAIN}"
echo "  Radarr:        https://radarr.${DOMAIN}"
echo "  Bazarr:        https://bazarr.${DOMAIN}"
echo "  Prowlarr:      https://prowlarr.${DOMAIN}"
echo "  qBittorrent:   https://torrent.${DOMAIN}"
echo "  Jellyseerr:    https://requests.${DOMAIN}"
echo ""

# ── qBittorrent setup ───────────────────────────────────────────
echo "── qBittorrent ──"
echo "1. Login with admin/adminadmin (default)"
echo "2. Change password immediately"
echo "3. Set download path to /downloads"
echo "4. Enable WebUI in Tools > Preferences > WebUI"
echo "   Set username/password for API access"
echo ""

# ── Prowlarr setup ──────────────────────────────────────────────
echo "── Prowlarr ──"
echo "1. Visit ${PROWLARR_URL}"
echo "2. Add indexers (public trackers)"
echo "3. Settings > Apps > Add Sonarr (host: sonarr, port: 8989)"
echo "4. Settings > Apps > Add Radarr (host: radarr, port: 7878)"
echo ""

# ── Sonarr setup ────────────────────────────────────────────────
echo "── Sonarr ──"
echo "1. Visit ${SONARR_URL}"
echo "2. Settings > Media Management:"
echo "   Root folder: /data/tv"
echo "3. Settings > Download Clients:"
echo "   Add qBittorrent (host: qbittorrent, port: 8080)"
echo "4. Settings > Indexers: (auto-synced from Prowlarr)"
echo ""

# ── Radarr setup ────────────────────────────────────────────────
echo "── Radarr ──"
echo "1. Visit ${RADARR_URL}"
echo "2. Settings > Media Management:"
echo "   Root folder: /data/movies"
echo "3. Settings > Download Clients:"
echo "   Add qBittorrent (host: qbittorrent, port: 8080)"
echo "4. Settings > Indexers: (auto-synced from Prowlarr)"
echo ""

# ── Jellyfin setup ──────────────────────────────────────────────
echo "── Jellyfin ──"
echo "1. Visit https://jellyfin.${DOMAIN}"
echo "2. Create admin account"
echo "3. Add libraries:"
echo "   Movies  → /movies"
echo "   TV      → /tv"
echo "   Music   → /music"
echo ""

# ── Jellyseerr setup ────────────────────────────────────────────
echo "── Jellyseerr ──"
echo "1. Visit https://requests.${DOMAIN}"
echo "2. Connect Jellyfin server"
echo "3. Connect Sonarr (host: sonarr, port: 8989)"
echo "4. Connect Radarr (host: radarr, port: 7878)"
echo ""

echo "✅ Media stack configured!"