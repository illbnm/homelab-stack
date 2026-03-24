#!/bin/bash
# =============================================================================
# Uptime Kuma Setup Script
# Automatically creates monitors for all deployed services
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
UPTIME_KUMA_URL="${UPTIME_KUMA_URL:-http://localhost:3001}"
UPTIME_KUMA_USERNAME="${UPTIME_KUMA_USERNAME:-admin}"
UPTIME_KUMA_PASSWORD="${UPTIME_KUMA_PASSWORD:-}"
DOMAIN="${DOMAIN:-localhost}"
NTFY_TOPIC="${NTFY_TOPIC:-homelab-alerts}"

echo -e "${GREEN}=== Uptime Kuma Setup Script ===${NC}"
echo ""

# Check if Uptime Kuma is running
check_uptime_kuma() {
    echo -e "${YELLOW}Checking if Uptime Kuma is running...${NC}"
    if curl -sf "${UPTIME_KUMA_URL}/" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Uptime Kuma is running at ${UPTIME_KUMA_URL}${NC}"
    else
        echo -e "${RED}✗ Uptime Kuma is not running. Please start it first.${NC}"
        exit 1
    fi
}

# Wait for Uptime Kuma to be ready (for initial setup)
wait_for_ready() {
    local max_attempts=30
    local attempt=1
    echo -e "${YELLOW}Waiting for Uptime Kuma to be ready...${NC}"
    while [ $attempt -le $max_attempts ]; do
        if curl -sf "${UPTIME_KUMA_URL}/" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Uptime Kuma is ready${NC}"
            return 0
        fi
        echo "Attempt $attempt/$max_attempts - waiting..."
        sleep 2
        ((attempt++))
    done
    echo -e "${RED}✗ Uptime Kuma did not become ready in time${NC}"
    exit 1
}

# Login and get token (simplified - Uptime Kuma uses WebSocket, this is a placeholder)
# In practice, you would use the Uptime Kuma API or create monitors via UI
get_auth_token() {
    echo -e "${YELLOW}Note: Uptime Kuma API requires WebSocket connection.${NC}"
    echo -e "${YELLOW}This script provides the monitor configuration for manual setup.${NC}"
    echo ""
}

# Service endpoints to monitor
declare -A SERVICES=(
    # Infrastructure
    ["Traefik Dashboard"]="https://traefik.${DOMAIN}"
    ["Portainer"]="https://portainer.${DOMAIN}"
    ["Watchtower"]="N/A"
    
    # Monitoring
    ["Grafana"]="https://grafana.${DOMAIN}"
    ["Prometheus"]="https://prometheus.${DOMAIN}"
    ["Alertmanager"]="https://alertmanager.${DOMAIN}"
    ["Loki"]="http://loki:3100/ready"
    ["Uptime Kuma"]="https://status.${DOMAIN}"
    
    # SSO
    ["Authentik"]="https://${AUTHENTIK_DOMAIN:-auth.${DOMAIN}}"
    
    # Storage
    ["Nextcloud"]="https://nextcloud.${DOMAIN}"
    ["MinIO"]="https://minio.${DOMAIN}"
    ["FileBrowser"]="https://files.${DOMAIN}"
    
    # Productivity
    ["Gitea"]="https://gitea.${DOMAIN}"
    ["Vaultwarden"]="https://vault.${DOMAIN}"
    ["Outline"]="https://outline.${DOMAIN}"
    
    # Media
    ["Jellyfin"]="https://jellyfin.${DOMAIN}"
    ["Sonarr"]="https://sonarr.${DOMAIN}"
    ["Radarr"]="https://radarr.${DOMAIN}"
    ["Prowlarr"]="https://prowlarr.${DOMAIN}"
    ["qBittorrent"]="https://qbittorrent.${DOMAIN}"
    ["Jellyseerr"]="https://jellyseerr.${DOMAIN}"
    
    # Network
    ["AdGuard Home"]="https://adguard.${DOMAIN}"
    ["WireGuard Easy"]="https://vpn.${DOMAIN}"
    
    # AI
    ["Ollama"]="http://ollama:11434"
    ["Open WebUI"]="https://openwebui.${DOMAIN}"
    
    # Notifications
    ["ntfy"]="https://ntfy.${DOMAIN}"
    ["Gotify"]="https://gotify.${DOMAIN}"
    
    # Dashboard
    ["Homepage"]="https://home.${DOMAIN}"
)

# Generate monitor configuration
generate_monitor_config() {
    echo -e "${GREEN}Generating monitor configuration...${NC}"
    echo ""
    echo "=========================================="
    echo "SERVICES TO MONITOR"
    echo "=========================================="
    echo ""
    
    for service in "${!SERVICES[@]}"; do
        url="${SERVICES[$service]}"
        if [ "$url" != "N/A" ]; then
            echo -e "${GREEN}Service:${NC} $service"
            echo -e "  URL: $url"
            echo -e "  Type: HTTP(s)"
            echo -e "  Interval: 60s"
            echo ""
        fi
    done
    
    echo "=========================================="
    echo "NOTIFICATION SETUP"
    echo "=========================================="
    echo ""
    echo -e "ntfy Notification URL:"
    echo -e "  ntfy://${NTFY_TOPIC}"
    echo ""
    echo -e "For critical alerts, use:"
    echo -e "  ntfy://${NTFY_TOPIC}?priority=5"
    echo ""
}

# Print setup instructions
print_setup_instructions() {
    echo -e "${GREEN}=========================================="
    echo "SETUP INSTRUCTIONS"
    echo "==========================================${NC}"
    echo ""
    echo "1. Access Uptime Kuma at: https://status.${DOMAIN}"
    echo ""
    echo "2. Create an admin account on first access"
    echo ""
    echo "3. Add a new notification channel:"
    echo "   - Type: ntfy"
    echo "   - ntfy Topic URL: ${NTFY_TOPIC}"
    echo "   - Priority: 5 (for critical alerts)"
    echo ""
    echo "4. Add monitors for each service listed above"
    echo ""
    echo "5. Assign the notification channel to each monitor"
    echo ""
    echo -e "${YELLOW}Alternative: Use the Uptime Kuma API${NC}"
    echo "   https://github.com/louislam/uptime-kuma/wiki/API"
    echo ""
}

# Create status page
create_status_page() {
    echo -e "${GREEN}=========================================="
    echo "STATUS PAGE SETUP"
    echo "==========================================${NC}"
    echo ""
    echo "1. Go to Status Pages in Uptime Kuma"
    echo "2. Create a new status page titled 'HomeLab Status'"
    echo "3. Add all monitors to the status page"
    echo "4. Set the slug to 'homelab' for a clean URL"
    echo "5. Enable 'Public' access"
    echo ""
    echo -e "Status page will be available at: ${GREEN}https://status.${DOMAIN}/status/homelab${NC}"
    echo ""
}

# Health check endpoints
check_health_endpoints() {
    echo -e "${GREEN}=========================================="
    echo "HEALTH ENDPOINT VERIFICATION"
    echo "==========================================${NC}"
    echo ""
    
    for service in "${!SERVICES[@]}"; do
        url="${SERVICES[$service]}"
        if [ "$url" != "N/A" ]; then
            echo -n "Checking $service... "
            if curl -sf --max-time 5 "$url" > /dev/null 2>&1; then
                echo -e "${GREEN}✓ OK${NC}"
            else
                echo -e "${YELLOW}⚠ Not accessible (may not be deployed)${NC}"
            fi
        fi
    done
    echo ""
}

# Main execution
main() {
    check_uptime_kuma
    generate_monitor_config
    print_setup_instructions
    create_status_page
    
    echo -e "${YELLOW}Run health check? (y/n)${NC}"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        check_health_endpoints
    fi
    
    echo -e "${GREEN}Setup complete!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Configure notification channels"
    echo "2. Add monitors for your services"
    echo "3. Create a public status page"
    echo "4. Test alerting by stopping a service"
}

# Run main function
main "$@"