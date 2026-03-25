#!/bin/bash
# authentik-setup.sh - Auto-configure Authentik OAuth2/OIDC providers
# Usage: ./scripts/authentik-setup.sh [--dry-run]
#
# This script uses the Authentik API to automatically create:
# - OAuth2/OIDC Providers for each service
# - Applications with proper redirect URIs
# - Groups (homelab-admins, homelab-users, media-users)
#
# Required environment variables:
#   AUTHENTIK_DOMAIN
#   AUTHENTIK_BOOTSTRAP_EMAIL
#   AUTHENTIK_BOOTSTRAP_PASSWORD

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"

# Load environment
if [ -f "$ENV_FILE" ]; then
    export $(grep -E '^[A-Z]' "$ENV_FILE" | xargs)
fi

# Default values
AUTHENTIK_DOMAIN="${AUTHENTIK_DOMAIN:-auth.example.com}"
AUTHENTIK_BOOTSTRAP_EMAIL="${AUTHENTIK_BOOTSTRAP_EMAIL:-admin@example.com}"
AUTHENTIK_BOOTSTRAP_PASSWORD="${AUTHENTIK_BOOTSTRAP_PASSWORD:-}"
AUTHENTIK_DOMAIN_PROTOCOL="${AUTHENTIK_DOMAIN_PROTOCOL:-https}"

DRY_RUN=false
VERBOSE=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--dry-run] [--verbose]"
            echo ""
            echo "Options:"
            echo "  --dry-run    Show what would be created without making changes"
            echo "  --verbose    Show detailed output"
            echo ""
            echo "Required env vars:"
            echo "  AUTHENTIK_DOMAIN (default: auth.example.com)"
            echo "  AUTHENTIK_BOOTSTRAP_EMAIL"
            echo "  AUTHENTIK_BOOTSTRAP_PASSWORD"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Get Authentik API token
get_token() {
    local email="$1"
    local password="$2"

    info "Authenticating with Authentik..."

    local response=$(curl -s -X POST \
        "${AUTHENTIK_DOMAIN_PROTOCOL}://${AUTHENTIK_DOMAIN}/api/v3/token/login/" \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"${email}\",\"password\":\"${password}\"}")

    if [ -z "$response" ]; then
        error "Failed to authenticate. Is Authentik running?"
        return 1
    fi

    local token=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('token', ''))" 2>/dev/null || echo "")

    if [ -z "$token" ]; then
        error "Failed to get token from response"
        return 1
    fi

    echo "$token"
}

# Wait for Authentik to be ready
wait_for_authentik() {
    info "Waiting for Authentik to be ready..."

    local max_attempts=30
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        if curl -sf "${AUTHENTIK_DOMAIN_PROTOCOL}://${AUTHENTIK_DOMAIN}/api/v3/ >/dev/null 2>&1; then
            log "Authentik is ready!"
            return 0
        fi

        attempt=$((attempt + 1))
        echo -n "."
        sleep 5
    done

    error "Authentik did not become ready in time"
    return 1
}

# Create OAuth2 provider
create_provider() {
    local name="$1"
    local slug="$2"
    local client_id="$3"
    local client_secret="$4"
    local redirect_uris="$5"
    local prop="$(cat <<PROP
{
    "name": "${name}",
    "slug": "${slug}",
    "client_type": "confidential",
    "client_id": "${client_id}",
    "client_secret": "${client_secret}",
    "redirect_uris": "${redirect_uris}",
    "signing_key": null,
    "redirect_uris_script": "",
    "_include_claims_in_token": true,
    "client_id_issued_at": null,
    "client_secret_issued_at": null,
    "sub": null
}
PROP
)"
    echo "$prop"
}

# Create application
create_application() {
    local name="$1"
    local slug="$2"
    local provider="$3"
    local group="$4"

    cat <<APP
{
    "name": "${name}",
    "slug": "${slug}",
    "provider": "${provider}",
    "policy_engine_mode": "any",
    "create_group": false,
    "group": "${group}"
}
APP
}

# Service configurations
declare -a SERVICES
SERVICES=(
    "Grafana:grafana:https://grafana.\${DOMAIN}/login/generic_oauth:urn:grafana"
    "Gitea:gitea:https://gitea.\${DOMAIN}/user/oauth2/Authentik/callback:"
    "Nextcloud:nextcloud:https://nextcloud.\${DOMAIN}/apps/oidc_login/oidc/callback:"
    "Outline:outline:https://outline.\${DOMAIN}/auth/oidc.Authentik/callback:"
    "Open WebUI:openwebui:https://openwebui.\${DOMAIN}/auth"
    "Portainer:portainer:https://portainer.\${DOMAIN}/oauth2/callback:"
)

# Groups to create
declare -a GROUPS=(
    "homelab-admins:Administrators with full access"
    "homelab-users:Regular users with standard access"
    "media-users:Users with access to media services only"
)

# Main execution
main() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║     Authentik Auto-Setup Script                    ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    echo ""

    if [ "$DRY_RUN" = true ]; then
        warn "DRY RUN MODE - No changes will be made"
        echo ""
    fi

    # Wait for Authentik
    wait_for_authentik || exit 1

    # Get token
    if [ -z "$AUTHENTIK_BOOTSTRAP_PASSWORD" ]; then
        error "AUTHENTIK_BOOTSTRAP_PASSWORD not set"
        exit 1
    fi

    TOKEN=$(get_token "$AUTHENTIK_BOOTSTRAP_EMAIL" "$AUTHENTIK_BOOTSTRAP_PASSWORD") || exit 1

    if [ "$VERBOSE" = true ]; then
        info "Token obtained successfully"
    fi

    # API base URL
    API_BASE="${AUTHENTIK_DOMAIN_PROTOCOL}://${AUTHENTIK_DOMAIN}/api/v3"

    # Create groups
    echo ""
    log "Creating user groups..."

    for group_spec in "${GROUPS[@]}"; do
        IFS=':' read -r group_name group_desc <<< "$group_spec"

        if [ "$DRY_RUN" = true ]; then
            info "[DRY RUN] Would create group: ${group_name}"
            continue
        fi

        info "Creating group: ${group_name}"

        curl -s -X POST \
            "${API_BASE}/core/groups/" \
            -H "Authorization: Token ${TOKEN}" \
            -H "Content-Type: application/json" \
            -d "{\"name\":\"${group_name}\",\"attributes\":{\"description\":\"${group_desc}\"}}" \
            > /dev/null 2>&1 || warn "Failed to create group ${group_name} (may already exist)"
    done

    # Create providers and applications
    echo ""
    log "Creating OAuth2 providers and applications..."

    for service_spec in "${SERVICES[@]}"; do
        IFS=':' read -r service_name service_slug redirect_uri property <<< "$service_spec"

        # Expand variables
        redirect_uri=$(eval echo "$redirect_uri")

        client_id="authentik-${service_slug}-$(openssl rand -hex 8)"
        client_secret=$(openssl rand -base64 32)

        if [ "$DRY_RUN" = true ]; then
            info "[DRY RUN] Would create provider: ${service_name}"
            info "        Client ID: ${client_id}"
            info "        Redirect URI: ${redirect_uri}"
            echo ""
            continue
        fi

        info "Creating provider: ${service_name}"

        # Create provider
        local provider_response=$(curl -s -X POST \
            "${API_BASE}/oauth2/providers/" \
            -H "Authorization: Token ${TOKEN}" \
            -H "Content-Type: application/json" \
            -d "$(create_provider "${service_name}" "${service_slug}" "${client_id}" "${client_secret}" "${redirect_uri}")")

        if [ $? -ne 0 ]; then
            error "Failed to create provider for ${service_name}"
            continue
        fi

        # Extract provider UUID
        provider_uuid=$(echo "$provider_response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('pk', ''))" 2>/dev/null || echo "")

        if [ -z "$provider_uuid" ]; then
            error "Failed to get provider UUID for ${service_name}"
            continue
        fi

        info "  Provider created! UUID: ${provider_uuid}"

        # Create application
        info "Creating application: ${service_name}"

        curl -s -X POST \
            "${API_BASE}/core/applications/" \
            -H "Authorization: Token ${TOKEN}" \
            -H "Content-Type: application/json" \
            -d "$(create_application "${service_name}" "${service_slug}" "${provider_uuid}" "")" \
            > /dev/null 2>&1 || warn "Failed to create application ${service_name}"

        # Output credentials for .env
        echo ""
        echo -e "${GREEN}=== ${service_name} Credentials ===${NC}"
        echo "${service_slug^^}_OAUTH_CLIENT_ID=${client_id}"
        echo "${service_slug^^}_OAUTH_CLIENT_SECRET=${client_secret}"
        echo "Redirect URI: ${redirect_uri}"
        echo ""
    done

    echo ""
    log "Setup complete!"
    echo ""
    echo "Next steps:"
    echo "  1. Update your .env files with the client credentials above"
    echo "  2. Restart services that use OAuth"
    echo ""
}

main "$@"
