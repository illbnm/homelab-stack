#!/bin/bash

set -euo pipefail

# Configuration
AUTHENTIK_URL="${AUTHENTIK_URL:-https://auth.homelab.local}"
AUTHENTIK_TOKEN="${AUTHENTIK_TOKEN:-}"
AUTHENTIK_API="${AUTHENTIK_URL}/api/v3"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_dependencies() {
    local deps=("curl" "jq")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log_error "$dep is required but not installed"
            exit 1
        fi
    done
}

check_authentik_token() {
    if [[ -z "$AUTHENTIK_TOKEN" ]]; then
        log_error "AUTHENTIK_TOKEN environment variable is required"
        log_info "Get your token from: ${AUTHENTIK_URL}/if/admin/#/core/tokens"
        exit 1
    fi
}

api_call() {
    local method="$1"
    local endpoint="$2"
    local data="${3:-}"

    local curl_opts=(-s -H "Authorization: Bearer ${AUTHENTIK_TOKEN}" -H "Content-Type: application/json")

    if [[ -n "$data" ]]; then
        curl_opts+=(-X "$method" -d "$data")
    else
        curl_opts+=(-X "$method")
    fi

    curl "${curl_opts[@]}" "${AUTHENTIK_API}${endpoint}"
}

wait_for_authentik() {
    log_info "Waiting for Authentik to be ready..."
    local max_attempts=30
    local attempt=1

    while [[ $attempt -le $max_attempts ]]; do
        if curl -s -f "${AUTHENTIK_URL}/api/v3/admin/version/" > /dev/null 2>&1; then
            log_success "Authentik is ready"
            return 0
        fi
        log_info "Attempt $attempt/$max_attempts - waiting 10s..."
        sleep 10
        ((attempt++))
    done

    log_error "Authentik is not responding after $max_attempts attempts"
    exit 1
}

create_property_mapping() {
    local name="$1"
    local expression="$2"
    local scope_name="${3:-openid}"

    log_info "Creating property mapping: $name"

    local existing
    existing=$(api_call GET "/propertymappings/scope/?name=${name}" | jq -r '.results[0].pk // empty')

    if [[ -n "$existing" ]]; then
        log_warning "Property mapping '$name' already exists (pk: $existing)"
        echo "$existing"
        return 0
    fi

    local payload
    payload=$(jq -n \
        --arg name "$name" \
        --arg expression "$expression" \
        --arg scope_name "$scope_name" \
        '{
            name: $name,
            expression: $expression,
            scope_name: $scope_name
        }')

    local result
    result=$(api_call POST "/propertymappings/scope/" "$payload")

    if echo "$result" | jq -e '.pk' > /dev/null; then
        local pk
        pk=$(echo "$result" | jq -r '.pk')
        log_success "Created property mapping: $name (pk: $pk)"
        echo "$pk"
    else
        log_error "Failed to create property mapping: $name"
        echo "$result" | jq .
        exit 1
    fi
}

create_oauth_provider() {
    local name="$1"
    local client_id="$2"
    local client_secret="$3"
    local redirect_uris="$4"
    local scopes="${5:-openid profile email}"

    log_info "Creating OAuth2/OIDC Provider: $name"

    # Check if provider already exists
    local existing
    existing=$(api_call GET "/providers/oauth2/?name=${name}" | jq -r '.results[0].pk // empty')

    if [[ -n "$existing" ]]; then
        log_warning "OAuth2 Provider '$name' already exists (pk: $existing)"
        return 0
    fi

    # Get default property mappings
    local openid_mapping email_mapping profile_mapping groups_mapping
    openid_mapping=$(api_call GET "/propertymappings/scope/?scope_name=openid" | jq -r '.results[0].pk // empty')
    email_mapping=$(api_call GET "/propertymappings/scope/?scope_name=email" | jq -r '.results[0].pk // empty')
    profile_mapping=$(api_call GET "/propertymappings/scope/?scope_name=profile" | jq -r '.results[0].pk // empty')
    groups_mapping=$(api_call GET "/propertymappings/scope/?scope_name=groups" | jq -r '.results[0].pk // empty')

    local property_mappings="[]"
    if [[ -n "$openid_mapping" ]]; then
        property_mappings=$(echo "$property_mappings" | jq --arg id "$openid_mapping" '. + [$id]')
    fi
    if [[ -n "$email_mapping" ]]; then
        property_mappings=$(echo "$property_mappings" | jq --arg id "$email_mapping" '. + [$id]')
    fi
    if [[ -n "$profile_mapping" ]]; then
        property_mappings=$(echo "$property_mappings" | jq --arg id "$profile_mapping" '. + [$id]')
    fi
    if [[ -n "$groups_mapping" ]]; then
        property_mappings=$(echo "$property_mappings" | jq --arg id "$groups_mapping" '. + [$id]')
    fi

    local payload
    payload=$(jq -n \
        --arg name "$name" \
        --arg client_id "$client_id" \
        --arg client_secret "$client_secret" \
        --arg redirect_uris "$redirect_uris" \
        --argjson property_mappings "$property_mappings" \
        '{
            name: $name,
            client_type: "confidential",
            client_id: $client_id,
            client_secret: $client_secret,
            authorization_grant_type: "authorization-code",
            redirect_uris: $redirect_uris,
            property_mappings: $property_mappings,
            sub_mode: "hashed_user_id",
            include_claims_in_id_token: true,
            issuer_mode: "per_provider"
        }')

    local result
    result=$(api_call POST "/providers/oauth2/" "$payload")

    if echo "$result" | jq -e '.pk' > /dev/null; then
        local pk
        pk=$(echo "$result" | jq -r '.pk')
        log_success "Created OAuth2 Provider: $name (pk: $pk)"
    else
        log_error "Failed to create OAuth2 Provider: $name"
        echo "$result" | jq .
        exit 1
    fi
}

create_application() {
    local name="$1"
    local slug="$2"
    local provider_name="$3"
    local launch_url="${4:-}"

    log_info "Creating Application: $name"

    # Check if application already exists
    local existing
    existing=$(api_call GET "/core/applications/?name=${name}" | jq -r '.results[0].pk // empty')

    if [[ -n "$existing" ]]; then
        log_warning "Application '$name' already exists (pk: $existing)"
        return 0
    fi

    # Get provider pk
    local provider_pk
    provider_pk=$(api_call GET "/providers/oauth2/?name=${provider_name}" | jq -r '.results[0].pk // empty')

    if [[ -z "$provider_pk" ]]; then
        log_error "Provider '$provider_name' not found"
        exit 1
    fi

    local payload
    payload=$(jq -n \
        --arg name "$name" \
        --arg slug "$slug" \
        --arg provider "$provider_pk" \
        --arg meta_launch_url "$launch_url" \
        '{
            name: $name,
            slug: $slug,
            provider: $provider,
            meta_launch_url: $meta_launch_url,
            policy_engine_mode: "any",
            open_in_new_tab: true
        }')

    local result
    result=$(api_call POST "/core/applications/" "$payload")

    if echo "$result" | jq -e '.pk' > /dev/null; then
        local pk
        pk=$(echo "$result" | jq -r '.pk')
        log_success "Created Application: $name (pk: $pk)"
    else
        log_error "Failed to create Application: $name"
        echo "$result" | jq .
        exit 1
    fi
}

setup_grafana() {
    log_info "Setting up Grafana OIDC integration"

    create_oauth_provider \
        "Grafana" \
        "grafana" \
        "$(openssl rand -hex 32)" \
        "https://grafana.homelab.local/login/generic_oauth"

    create_application \
        "Grafana" \
        "grafana" \
        "Grafana" \
        "https://grafana.homelab.local"
}

setup_gitea() {
    log_info "Setting up Gitea OIDC integration"

    create_oauth_provider \
        "Gitea" \
        "gitea" \
        "$(openssl rand -hex 32)" \
        "https://git.homelab.local/user/oauth2/authentik/callback"

    create_application \
        "Gitea" \
        "gitea" \
        "Gitea" \
        "https://git.homelab.local"
}

setup_outline() {
    log_info "Setting up Outline OIDC integration"

    create_oauth_provider \
        "Outline" \
        "outline" \
        "$(openssl rand -hex 32)" \
        "https://docs.homelab.local/auth/oidc.callback"

    create_application \
        "Outline" \
        "outline" \
        "Outline" \
        "https://docs.homelab.local"
}

setup_open_webui() {
    log_info "Setting up Open WebUI OIDC integration"

    create_oauth_provider \
        "Open WebUI" \
        "open-webui" \
        "$(openssl rand -hex 32)" \
        "https://ai.homelab.local/oauth/oidc/callback"

    create_application \
        "Open WebUI" \
        "open-webui" \
        "Open WebUI" \
        "https://ai.homelab.local"
}

setup_nextcloud() {
    log_info "Setting up Nextcloud OIDC integration"

    create_oauth_provider \
        "Nextcloud" \
        "nextcloud" \
        "$(openssl rand -hex 32)" \
        "https://cloud.homelab.local/apps/oidc_login/oidc"

    create_application \
        "Nextcloud" \
        "nextcloud" \
        "Nextcloud" \
        "https://cloud.homelab.local"
}

setup_bookstack() {
    log_info "Setting up BookStack OIDC integration"

    create_oauth_provider \
        "BookStack" \
        "bookstack" \
        "$(openssl rand -hex 32)" \
        "https://wiki.homelab.local/oidc/callback"

    create_application \
        "BookStack" \
        "bookstack" \
        "BookStack" \
        "https://wiki.homelab.local"
}

setup_portainer() {
    log_info "Setting up Portainer OAuth integration"

    create_oauth_provider \
        "Portainer" \
        "portainer" \
        "$(openssl rand -hex 32)" \
        "https://portainer.homelab.local"

    create_application \
        "Portainer" \
        "portainer" \
        "Portainer" \
        "https://portainer.homelab.local"
}

show_configuration_summary() {
    log_info "Configuration Summary"
    echo "=========================="
    echo
    echo "🔐 Authentik Admin Interface: ${AUTHENTIK_URL}/if/admin/"
    echo "👤 User Interface: ${AUTHENTIK_URL}/if/user/"
    echo
    echo "📝 OAuth2/OIDC Providers created:"
    echo "  • Grafana (Client ID: grafana)"
    echo "  • Gitea (Client ID: gitea)"
    echo "  • Outline (Client ID: outline)"
    echo "  • Open WebUI (Client ID: open-webui)"
    echo "  • Nextcloud (Client ID: nextcloud)"
    echo "  • BookStack (Client ID: bookstack)"
    echo "  • Portainer (Client ID: portainer)"
    echo
    echo "⚠️  Next Steps:"
    echo "  1. Update service configurations with generated client secrets"
    echo "  2. Restart services to apply OIDC settings"
    echo "  3. Test SSO login flows for each service"
    echo "  4. Configure user groups and permissions in Authentik"
}

main() {
    log_info "Starting Authentik OIDC setup..."

    check_dependencies
    check_authentik_token
    wait_for_authentik

    # Setup all services
    setup_grafana
    setup_gitea
    setup_outline
    setup_open_webui
    setup_nextcloud
    setup_bookstack
    setup_portainer

    show_configuration_summary

    log_success "Authentik OIDC setup completed successfully!"
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [OPTIONS]"
        echo
        echo "Setup Authentik OIDC providers for all Homelab services"
        echo
        echo "Environment Variables:"
        echo "  AUTHENTIK_URL    Authentik base URL (default: https://auth.homelab.local)"
        echo "  AUTHENTIK_TOKEN  Authentik API token (required)"
        echo
        echo "Examples:"
        echo "  export AUTHENTIK_TOKEN='ak_...' && $0"
        echo "  AUTHENTIK_URL='https://auth.example.com' $0"
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac
