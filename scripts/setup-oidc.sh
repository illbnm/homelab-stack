#!/bin/bash
# =============================================================================
# setup-oidc.sh - Configure OIDC applications in Authentik
# Usage: ./setup-oidc.sh <service> [options]
# =============================================================================

set -euo pipefail

# Configuration
AUTHENTIK_URL="${AUTHENTIK_URL:-http://localhost:9000}"
AUTHENTIK_TOKEN="${AUTHENTIK_TOKEN:-}"
DOMAIN="${DOMAIN:-example.com}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# OIDC application templates
declare -A APPS=(
    ["grafana"]="Grafana|https://grafana.${DOMAIN}/login/generic_oauth|openid profile email"
    ["gitea"]="Gitea|https://git.${DOMAIN}/user/oauth2/authentik/callback|openid profile email"
    ["outline"]="Outline|https://outline.${DOMAIN}/auth/oidc.callback|openid profile email"
    ["vaultwarden"]="Vaultwarden|https://vault.${DOMAIN}/admin/oidc/callback|openid profile email"
    ["nextcloud"]="Nextcloud|https://cloud.${DOMAIN}/apps/oidclogin/redirect|openid profile email"
    ["jellyfin"]="Jellyfin|https://media.${DOMAIN}/sso/OIDC/rp|openid profile email"
)

create_oidc_app() {
    local name="$1"
    local friendly_name="$2"
    local redirect_uri="$3"
    local scopes="$4"
    
    echo -e "${GREEN}Creating OIDC application: ${friendly_name}${NC}"
    
    RESPONSE=$(curl -sf -X POST "${AUTHENTIK_URL}/api/v3/core/applications/" \
        -H "Authorization: Bearer ${AUTHENTIK_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{
            \"name\": \"${friendly_name}\",
            \"slug\": \"${name}\",
            \"provider\": {
                \"name\": \"${friendly_name} OIDC\",
                \"authorization_flow\": \"default-provider-authorization-implicit-consent\",
                \"client_type\": \"confidential\",
                \"client_id\": \"${name}\",
                \"client_secret\": \"$(openssl rand -hex 32)\",
                \"redirect_uris\": [\"${redirect_uri}\"],
                \"sub_mode\": \"user_email\",
                \"access_token_validity\": \"hours=24\",
                \"refresh_token_validity\": \"days=30\",
                \"signing_key\": \"default-signing-key\"
            }
        }" 2>/dev/null) || {
        echo -e "${RED}Failed to create ${friendly_name}${NC}"
        return 1
    }
    
    local client_id=$(echo "$RESPONSE" | jq -r '.provider.client_id // empty')
    local client_secret=$(echo "$RESPONSE" | jq -r '.provider.client_secret // empty')
    
    echo "  Client ID: ${client_id}"
    echo "  Client Secret: ${client_secret}"
    echo ""
}

list_apps() {
    echo -e "${GREEN}Configured OIDC Applications:${NC}"
    for app in "${!APPS[@]}"; do
        IFS='|' read -r name redirect scopes <<< "${APPS[$app]}"
        echo "  - ${app}: ${name}"
    done
}

show_help() {
    cat << HELPEOF
Authentik OIDC Application Setup

Usage: $(basename "$0") <command> [options]

Commands:
  create <service>   Create OIDC application for service
  create-all         Create all configured applications
  list               List available services

Environment Variables:
  AUTHENTIK_URL      Authentik URL (default: http://localhost:9000)
  AUTHENTIK_TOKEN    Authentik API token
  DOMAIN             Your domain (default: example.com)

Examples:
  $(basename "$0") create grafana
  $(basename "$0") create-all
  $(basename "$0") list

HELPEOF
}

# Main
case "${1:-help}" in
    create)
        if [[ -z "${2:-}" ]]; then
            echo "Error: Service name required"
            show_help
            exit 1
        fi
        if [[ -z "${APPS[$2]:-}" ]]; then
            echo "Error: Unknown service: $2"
            list_apps
            exit 1
        fi
        IFS='|' read -r name redirect scopes <<< "${APPS[$2]}"
        create_oidc_app "$2" "$name" "$redirect" "$scopes"
        ;;
    create-all)
        for app in "${!APPS[@]}"; do
            IFS='|' read -r name redirect scopes <<< "${APPS[$app]}"
            create_oidc_app "$app" "$name" "$redirect" "$scopes"
        done
        ;;
    list)
        list_apps
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
