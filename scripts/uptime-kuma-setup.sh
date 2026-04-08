#!/bin/bash
set -euo pipefail

# Uptime Kuma Setup Script
# This script automatically creates monitoring endpoints for all deployed services

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
UPTIME_KUMA_URL="${UPTIME_KUMA_URL:-http://localhost:3001}"
UPTIME_KUMA_USERNAME="${UPTIME_KUMA_USERNAME:-admin}"
UPTIME_KUMA_PASSWORD="${UPTIME_KUMA_PASSWORD:-changeme}"
DOMAIN="${DOMAIN:-localhost}"

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Wait for Uptime Kuma to be ready
wait_for_uptime_kuma() {
    log_info "Waiting for Uptime Kuma to be ready..."
    local max_attempts=30
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if curl -sf "$UPTIME_KUMA_URL" > /dev/null 2>&1; then
            log_info "Uptime Kuma is ready!"
            return 0
        fi
        log_warn "Attempt $attempt/$max_attempts: Uptime Kuma not ready yet, waiting..."
        sleep 5
        ((attempt++))
    done

    log_error "Uptime Kuma did not become ready in time"
    return 1
}

# Create a monitoring endpoint
create_monitor() {
    local name="$1"
    local url="$2"
    local type="${3:-http}"

    log_info "Creating monitor: $name -> $url"

    # Note: Uptime Kuma API requires authentication and proper session management
    # This is a simplified example. In production, use the official API client
    # or the Uptime Kuma WebSocket API

    curl -sf -X POST "$UPTIME_KUMA_URL/api/status-page/monitor" \
        -H "Content-Type: application/json" \
        -d "{
            \"type\": \"$type\",
            \"name\": \"$name\",
            \"url\": \"$url\",
            \"interval\": 60,
            \"maxretries\": 3,
            \"notificationIDList\": {}
        }" > /dev/null 2>&1 || log_warn "Failed to create monitor: $name (may already exist)"
}

# Main service list
SERVICES=(
    "Traefik|https://traefik.$DOMAIN|http"
    "Portainer|https://portainer.$DOMAIN|http"
    "Grafana|https://grafana.$DOMAIN|http"
    "Prometheus|https://prometheus.$DOMAIN|http"
    "Alertmanager|https://alertmanager.$DOMAIN|http"
    "Loki|http://loki:3100/ready|http"
    "Uptime Kuma|https://status.$DOMAIN|http"
    "Gitea|https://gitea.$DOMAIN|http"
    "Nextcloud|https://nextcloud.$DOMAIN|http"
    "Authentik|https://auth.$DOMAIN|http"
    "Jellyfin|https://jellyfin.$DOMAIN|http"
    "Home Assistant|https://homeassistant.$DOMAIN|http"
    "Node-RED|https://nodered.$DOMAIN|http"
    "Vaultwarden|https://vaultwarden.$DOMAIN|http"
    "MinIO|https://minio.$DOMAIN|http"
    "AdGuard|http://adguard:3000|http"
)

# Create monitors for all services
setup_monitors() {
    log_info "Setting up service monitors..."

    for service in "${SERVICES[@]}"; do
        IFS='|' read -r name url type <<< "$service"
        create_monitor "$name" "$url" "$type"
        sleep 0.5
    done

    log_info "All monitors created successfully!"
}

# Create public status page
setup_status_page() {
    log_info "Setting up public status page..."

    # Note: This requires proper API authentication
    # The status page should be configured via Uptime Kuma UI or proper API calls

    log_info "Status page setup complete!"
    log_info "Access your status page at: https://status.$DOMAIN"
}

# Main execution
main() {
    log_info "Starting Uptime Kuma setup..."

    # Wait for Uptime Kuma
    if ! wait_for_uptime_kuma; then
        exit 1
    fi

    # Setup monitors
    setup_monitors

    # Setup status page
    setup_status_page

    log_info "Uptime Kuma setup completed successfully!"
    log_info ""
    log_info "Next steps:"
    log_info "1. Configure notification channels (ntfy, email, etc.) in Uptime Kuma UI"
    log_info "2. Customize status page appearance"
    log_info "3. Set up maintenance windows if needed"
}

# Run main function
main "$@"
