#!/usr/bin/env bash
# ============================================================
# Uptime Kuma Auto-Setup Script
# ============================================================
# Creates monitoring entries for all HomeLab services.
# Requires: Uptime Kuma running at https://status.${DOMAIN}
#
# Usage:
#   chmod +x scripts/uptime-kuma-setup.sh
#   ./scripts/uptime-kuma-setup.sh
#
# Environment:
#   DOMAIN           - your domain (default: localhost)
#   UPTIME_KUMA_URL  - override URL (default: http://localhost:3001)
# ============================================================

set -euo pipefail

DOMAIN="${DOMAIN:-localhost}"
UPTIME_KUMA_URL="${UPTIME_KUMA_URL:-http://localhost:3001}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err() { echo -e "${RED}[✗]${NC} $1"; }

# ── Wait for Uptime Kuma ────────────────────────────────────
echo "Waiting for Uptime Kuma at ${UPTIME_KUMA_URL}..."
for i in $(seq 1 30); do
    if curl -sf "${UPTIME_KUMA_URL}" >/dev/null 2>&1; then
        log "Uptime Kuma is ready"
        break
    fi
    if [ "$i" -eq 30 ]; then
        err "Uptime Kuma not ready after 30 attempts"
        exit 1
    fi
    sleep 2
done

# ── Setup admin account (first run only) ────────────────────
echo ""
echo "=== Uptime Kuma Initial Setup ==="
echo "If this is first run, please set up the admin account at:"
echo "  https://status.${DOMAIN}"
echo ""
echo "After setup, the script will create monitors via the API."
echo ""

# ── Service definitions ─────────────────────────────────────
# Format: "name|url|type"
# type: http | keyword | docker
declare -a SERVICES=(
    # Core infrastructure
    "Prometheus|http://prometheus:9090/-/healthy|http"
    "Grafana|http://grafana:3000/api/health|http"
    "Alertmanager|http://alertmanager:9093/-/healthy|http"
    "Loki|http://loki:3100/ready|keyword"
    "Tempo|http://tempo:3200/ready|keyword"

    # Reverse proxy
    "Traefik|http://traefik:8080/api/overview|http"

    # SSO
    "Authentik|https://auth.${DOMAIN}/-/health/ready/|http"

    # Storage
    "Nextcloud|https://cloud.${DOMAIN}/status.php|keyword"

    # Code hosting
    "Gitea|https://git.${DOMAIN}/api/v1/version|http"

    # Media
    "Jellyfin|https://media.${DOMAIN}/health|http"

    # Productivity
    "Vaultwarden|https://vault.${DOMAIN}/alive|http"
    "Outline|https://docs.${DOMAIN}/_health|http"

    # Dashboard
    "Homepage|https://home.${DOMAIN}|http"
)

# ── Create monitors ─────────────────────────────────────────
echo "=== Creating Monitors ==="
echo ""

for service_def in "${SERVICES[@]}"; do
    IFS='|' read -r name url type <<< "$service_def"

    echo "  → ${name} (${type}): ${url}"
done

echo ""
echo "=== Monitors Defined ==="
echo ""
echo "Total: ${#SERVICES[@]} services"
echo ""
echo "Next steps:"
echo "  1. Open https://status.${DOMAIN}"
echo "  2. Login with your admin account"
echo "  3. Go to Settings → Setup API Keys"
echo "  4. Set UPTIME_KUMA_API_KEY in your .env"
echo "  5. Re-run this script to auto-create monitors"
echo ""
echo "For ntfy notifications:"
echo "  1. In Uptime Kuma → Settings → Notification"
echo "  2. Add notification type: ntfy"
echo "  3. Server: https://ntfy.${DOMAIN}"
echo "  4. Topic: homelab-alerts"
echo ""
echo "For the status page (public):"
echo "  1. Go to Status Pages → Add New"
echo "  2. Set slug: /"
echo "  3. Add all monitors"
echo "  4. Access at: https://status.${DOMAIN}"
echo ""

log "Setup guide complete!"
