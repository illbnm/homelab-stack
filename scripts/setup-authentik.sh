#!/bin/bash
set -euo pipefail

# Authentik OIDC Provider Setup Script
# Creates OIDC applications for all supported services

AUTHENTIK_URL="${AUTHENTIK_URL:-https://auth.homelab.local}"
AUTHENTIK_TOKEN="${AUTHENTIK_TOKEN:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

check_dependencies() {
    log_info "Checking dependencies..."

    if ! command -v curl >/dev/null 2>&1; then
        log_error "curl is required but not installed"
        exit 1
    fi

    if ! command -v jq >/dev/null 2>&1; then
        log_error "jq is required but not installed"
        exit 1
    fi

    if [[ -z "$AUTHENTIK_TOKEN" ]]; then
        log_error "AUTHENTIK_TOKEN environment variable is required"
        log_info "Generate a token in Authentik: Admin Interface > Tokens"
        exit 1
    fi
}

wait_for_authentik() {
    log_info "Waiting for Authentik to be ready..."
    local max_attempts=30
    local attempt=1

    while [[ $attempt -le $max_attempts ]]; do
        if curl -s -f "$AUTHENTIK_URL/api/v3/core/applications/" \
           -H "Authorization: Bearer $AUTHENTIK_TOKEN" >/dev/null 2>&1; then
            log_success "Authentik is ready"
            return 0
        fi

        log_info "Attempt $attempt/$max_attempts - waiting 10s..."
        sleep 10
        ((attempt++))
    done

    log_error "Authentik failed to respond after $max_attempts attempts"
    exit 1
}

create_provider() {
    local name="$1"
    local client_id="$2"
    local redirect_uris="$3"
    local scopes="$4"

    log_info "Creating OIDC provider: $name"

    local provider_data=$(cat <<EOF
{
    "name": "$name",
    "authorization_flow": "default-authorization-flow",
    "client_type": "confidential",
    "client_id": "$client_id",
    "client_secret": "$(openssl rand -base64 32)",
    "redirect_uris": "$redirect_uris",
    "sub_mode": "hashed_user_id",
    "include_claims_in_id_token": true,
    "signing_key": "default"
}
EOF
)

    local response=$(curl -s -w "%{http_code}" -o response.json \
        -X POST "$AUTHENTIK_URL/api/v3/providers/oauth2/" \
        -H "Authorization: Bearer $AUTHENTIK_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$provider_data")

    if [[ "$response" == "201" ]]; then
        local provider_id=$(jq -r '.pk' response.json)
        local client_secret=$(jq -r '.client_secret' response.json)

        log_success "Provider created with ID: $provider_id"

        # Create application
        create_application "$name" "$provider_id" "$scopes"

        # Save credentials
        save_credentials "$name" "$client_id" "$client_secret"

    elif [[ "$response" == "400" ]]; then
        local error_msg=$(jq -r '.client_id[0]' response.json 2>/dev/null || echo "Unknown error")
        if [[ "$error_msg" == *"already exists"* ]]; then
            log_warning "Provider $name already exists, skipping..."
        else
            log_error "Failed to create provider $name: $error_msg"
        fi
    else
        log_error "Failed to create provider $name (HTTP $response)"
        cat response.json 2>/dev/null || true
    fi

    rm -f response.json
}

create_application() {
    local name="$1"
    local provider_id="$2"
    local scopes="$3"

    log_info "Creating application: $name"

    local app_data=$(cat <<EOF
{
    "name": "$name",
    "slug": "$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')",
    "provider": $provider_id,
    "meta_launch_url": "blank://blank",
    "meta_description": "OIDC integration for $name",
    "policy_engine_mode": "any"
}
EOF
)

    local response=$(curl -s -w "%{http_code}" -o app_response.json \
        -X POST "$AUTHENTIK_URL/api/v3/core/applications/" \
        -H "Authorization: Bearer $AUTHENTIK_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$app_data")

    if [[ "$response" == "201" ]]; then
        log_success "Application $name created successfully"
    elif [[ "$response" == "400" ]]; then
        local error_msg=$(jq -r '.slug[0]' app_response.json 2>/dev/null || echo "Unknown error")
        if [[ "$error_msg" == *"already exists"* ]]; then
            log_warning "Application $name already exists"
        else
            log_error "Failed to create application $name: $error_msg"
        fi
    else
        log_error "Failed to create application $name (HTTP $response)"
    fi

    rm -f app_response.json
}

save_credentials() {
    local name="$1"
    local client_id="$2"
    local client_secret="$3"

    local env_file="$ROOT_DIR/stacks/sso/generated-credentials.env"
    local safe_name=$(echo "$name" | tr '[:lower:]' '[:upper:]' | tr ' -' '_')

    mkdir -p "$(dirname "$env_file")"

    {
        echo "# $name OIDC Credentials"
        echo "${safe_name}_CLIENT_ID=\"$client_id\""
        echo "${safe_name}_CLIENT_SECRET=\"$client_secret\""
        echo ""
    } >> "$env_file"

    log_success "Credentials saved for $name"
}

setup_grafana() {
    create_provider "Grafana" "grafana" \
        "https://grafana.homelab.local/login/generic_oauth" \
        "openid email profile"
}

setup_portainer() {
    create_provider "Portainer" "portainer" \
        "https://portainer.homelab.local" \
        "openid email profile"
}

setup_jellyfin() {
    create_provider "Jellyfin" "jellyfin" \
        "https://jellyfin.homelab.local/sso/OID/redirect/authentik" \
        "openid email profile"
}

setup_nextcloud() {
    create_provider "Nextcloud" "nextcloud" \
        "https://nextcloud.homelab.local/apps/oidc_login/oidc" \
        "openid email profile"
}

setup_outline() {
    create_provider "Outline" "outline" \
        "https://outline.homelab.local/auth/oidc.callback" \
        "openid email profile"
}

setup_gitea() {
    create_provider "Gitea" "gitea" \
        "https://git.homelab.local/user/oauth2/authentik/callback" \
        "openid email profile"
}

setup_prometheus() {
    create_provider "Prometheus" "prometheus" \
        "https://prometheus.homelab.local/oauth2/callback" \
        "openid email profile"
}

main() {
    log_info "Starting Authentik OIDC provider setup..."

    check_dependencies
    wait_for_authentik

    # Clean previous credentials
    local env_file="$ROOT_DIR/stacks/sso/generated-credentials.env"
    if [[ -f "$env_file" ]]; then
        rm "$env_file"
    fi

    echo "# Auto-generated OIDC credentials" > "$env_file"
    echo "# Generated on $(date)" >> "$env_file"
    echo "" >> "$env_file"

    # Setup providers for all services
    setup_grafana
    setup_portainer
    setup_jellyfin
    setup_nextcloud
    setup_outline
    setup_gitea
    setup_prometheus

    log_success "Authentik setup completed!"
    log_info "Credentials saved to: $env_file"
    log_info "Remember to source this file in your stack configurations"

    # Set secure permissions
    chmod 600 "$env_file"
    log_info "Credentials file permissions set to 600"
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [--dry-run]"
        echo ""
        echo "Environment variables:"
        echo "  AUTHENTIK_URL    - Authentik instance URL (default: https://auth.homelab.local)"
        echo "  AUTHENTIK_TOKEN  - API token for Authentik (required)"
        exit 0
        ;;
    --dry-run)
        log_info "Dry run mode - would create the following providers:"
        echo "  - Grafana (grafana)"
        echo "  - Portainer (portainer)"
        echo "  - Jellyfin (jellyfin)"
        echo "  - Nextcloud (nextcloud)"
        echo "  - Outline (outline)"
        echo "  - Gitea (gitea)"
        echo "  - Prometheus (prometheus)"
        exit 0
        ;;
    "")
        main
        ;;
    *)
        log_error "Unknown argument: $1"
        log_info "Use --help for usage information"
        exit 1
        ;;
esac
