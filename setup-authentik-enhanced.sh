#!/bin/bash
# Enhanced Authentik Setup Script for Homelab SSO Integration
# Compliant with: claude-opus-4-6 + GPT-5.3 Codex requirements
# Version: 1.0.0

set -euo pipefail

# --------------------------
# Configuration
# --------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_FILE="${PROJECT_ROOT}/logs/authentik-setup-$(date +%Y%m%d-%H%M%S).log"
CONFIG_FILE="${PROJECT_ROOT}/.env"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --------------------------
# Logging Functions
# --------------------------
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# --------------------------
# Utility Functions
# --------------------------
check_dependencies() {
    log_info "Checking dependencies..."
    
    local missing_deps=()
    
    for cmd in curl jq docker docker-compose; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        return 1
    fi
    
    log_success "All dependencies are available"
}

wait_for_service() {
    local service_name="$1"
    local service_url="$2"
    local max_attempts="${3:-30}"
    
    log_info "Waiting for $service_name to be ready..."
    
    for ((i=1; i<=max_attempts; i++)); do
        if curl -s -f "$service_url" > /dev/null 2>&1; then
            log_success "$service_name is ready after $i seconds"
            return 0
        fi
        log_info "Attempt $i/$max_attempts: $service_name not ready yet..."
        sleep 1
    done
    
    log_error "$service_name failed to start within $max_attempts seconds"
    return 1
}

# --------------------------
# Authentik API Functions
# --------------------------
get_authentik_token() {
    local authentik_url="${AUTHENTIK_URL:-http://authentik:9000}"
    local bootstrap_token="${AUTHENTIK_BOOTSTRAP_TOKEN:-}"
    
    if [ -z "$bootstrap_token" ]; then
        log_error "AUTHENTIK_BOOTSTRAP_TOKEN is not set"
        return 1
    fi
    
    echo "$bootstrap_token"
}

authentik_api_request() {
    local method="$1"
    local endpoint="$2"
    local data="${3:-}"
    local token
    
    token=$(get_authentik_token) || return 1
    
    local curl_cmd=("curl" "-s" "-f" "-X" "$method" "-H" "Authorization: Bearer $token")
    
    if [ -n "$data" ]; then
        curl_cmd+=("-H" "Content-Type: application/json" "-d" "$data")
    fi
    
    curl_cmd+=("${AUTHENTIK_URL:-http://authentik:9000}${endpoint}")
    
    log_info "Making Authentik API request: $method $endpoint"
    
    if ! response=$("${curl_cmd[@]}"); then
        log_error "Authentik API request failed: $method $endpoint"
        return 1
    fi
    
    echo "$response"
}

# --------------------------
# OIDC Provider Setup
# --------------------------
get_default_flow() {
    log_info "Getting default authorization flow..."
    
    local response
    response=$(authentik_api_request "GET" "/api/v3/flows/instances/?slug=default-provider-authorization-implicit-consent") || return 1
    
    local flow_id
    flow_id=$(echo "$response" | jq -r '.results[0].pk // empty')
    
    if [ -z "$flow_id" ]; then
        log_error "Failed to get default flow"
        return 1
    fi
    
    log_success "Got default flow ID: $flow_id"
    echo "/api/v3/flows/instances/$flow_id/"
}

get_signing_key() {
    log_info "Getting signing key..."
    
    local response
    response=$(authentik_api_request "GET" "/api/v3/crypto/certificatekeypairs/") || return 1
    
    local key_id
    key_id=$(echo "$response" | jq -r '.results[0].pk // empty')
    
    if [ -z "$key_id" ]; then
        log_error "Failed to get signing key"
        return 1
    fi
    
    log_success "Got signing key ID: $key_id"
    echo "/api/v3/crypto/certificatekeypairs/$key_id/"
}

create_oidc_provider() {
    local provider_name="$1"
    local client_id="$2"
    local redirect_uris="$3"
    
    log_info "Creating OIDC provider: $provider_name"
    
    local flow_url
    flow_url=$(get_default_flow) || return 1
    
    local signing_key_url
    signing_key_url=$(get_signing_key) || return 1
    
    local request_data=$(cat <<EOF
{
    "name": "$provider_name",
    "authorization_flow": "$flow_url",
    "client_id": "$client_id",
    "client_secret": "",
    "redirect_uris": "$redirect_uris",
    "property_mappings": [],
    "signing_key": "$signing_key_url",
    "verification_keys": []
}
EOF
)
    
    local response
    response=$(authentik_api_request "POST" "/api/v3/providers/oauth2/" "$request_data") || return 1
    
    local provider_id
    provider_id=$(echo "$response" | jq -r '.pk // empty')
    
    if [ -z "$provider_id" ]; then
        log_error "Failed to create OIDC provider"
        return 1
    fi
    
    log_success "Created OIDC provider: $provider_name (ID: $provider_id)"
    echo "$provider_id"
}

# --------------------------
# User Group Management
# --------------------------
create_user_groups() {
    log_info "Creating user groups..."
    
    local groups=("homelab-admins" "homelab-users" "media-users")
    
    for group in "${groups[@]}"; do
        log_info "Creating group: $group"
        
        local request_data=$(cat <<EOF
{
    "name": "$group",
    "parent": null,
    "users": [],
    "attributes": {}
}
EOF
)
        
        if response=$(authentik_api_request "POST" "/api/v3/groups/" "$request_data"); then
            local group_id=$(echo "$response" | jq -r '.pk // empty')
            log_success "Created group: $group (ID: $group_id)"
        else
            log_warning "Failed to create group: $group (might already exist)"
        fi
    done
}

# --------------------------
# Service Configuration
# --------------------------
configure_grafana() {
    log_info "Configuring Grafana OIDC..."
    
    local client_id="$1"
    local client_secret="$2"
    
    # Update .env file
    sed -i "s|GRAFANA_OIDC_CLIENT_ID=.*|GRAFANA_OIDC_CLIENT_ID=$client_id|" "$CONFIG_FILE"
    sed -i "s|GRAFANA_OIDC_CLIENT_SECRET=.*|GRAFANA_OIDC_CLIENT_SECRET=$client_secret|" "$CONFIG_FILE"
    
    log_success "Grafana OIDC configured"
}

configure_gitea() {
    log_info "Configuring Gitea OIDC..."
    
    local client_id="$1"
    local client_secret="$2"
    
    sed -i "s|GITEA_OIDC_CLIENT_ID=.*|GITEA_OIDC_CLIENT_ID=$client_id|" "$CONFIG_FILE"
    sed -i "s|GITEA_OIDC_CLIENT_SECRET=.*|GITEA_OIDC_CLIENT_SECRET=$client_secret|" "$CONFIG_FILE"
    
    log_success "Gitea OIDC configured"
}

configure_nextcloud() {
    log_info "Configuring Nextcloud OIDC..."
    
    local client_id="$1"
    local client_secret="$2"
    
    sed -i "s|NEXTCLOUD_OIDC_CLIENT_ID=.*|NEXTCLOUD_OIDC_CLIENT_ID=$client_id|" "$CONFIG_FILE"
    sed -i "s|NEXTCLOUD_OIDC_CLIENT_SECRET=.*|NEXTCLOUD_OIDC_CLIENT_SECRET=$client_secret|" "$CONFIG_FILE"
    
    log_success "Nextcloud OIDC configured"
}

configure_outline() {
    log_info "Configuring Outline OIDC..."
    
    local client_id="$1"
    local client_secret="$2"
    
    sed -i "s|OUTLINE_OIDC_CLIENT_ID=.*|OUTLINE_OIDC_CLIENT_ID=$client_id|" "$CONFIG_FILE"
    sed -i "s|OUTLINE_OIDC_CLIENT_SECRET=.*|OUTLINE_OIDC_CLIENT_SECRET=$client_secret|" "$CONFIG_FILE"
    
    log_success "Outline OIDC configured"
}

configure_openwebui() {
    log_info "Configuring Open WebUI OIDC..."
    
    local client_id="$1"
    local client_secret="$2"
    
    sed -i "s|OPENWEBUI_OIDC_CLIENT_ID=.*|OPENWEBUI_OIDC_CLIENT_ID=$client_id|" "$CONFIG_FILE"
    sed -i "s|OPENWEBUI_OIDC_CLIENT_SECRET=.*|OPENWEBUI_OIDC_CLIENT_SECRET=$client_secret|" "$CONFIG_FILE"
    
    log_success "Open WebUI OIDC configured"
}

configure_portainer() {
    log_info "Configuring Portainer OAuth2..."
    
    local client_id="$1"
    local client_secret="$2"
    
    sed -i "s|PORTAINER_OAUTH2_CLIENT_ID=.*|PORTAINER_OAUTH2_CLIENT_ID=$client_id|" "$CONFIG_FILE"
    sed -i "s|PORTAINER_OAUTH2_CLIENT_SECRET=.*|PORTAINER_OAUTH2_CLIENT_SECRET=$client_secret|" "$CONFIG_FILE"
    
    log_success "Portainer OAuth2 configured"
}# Add more service configuration functions as needed

# --------------------------
# Main Setup Function
# --------------------------
main_setup() {
    log_info "Starting Enhanced Authentik Setup"
    log_info "Script version: 1.0.0"
    log_info "Log file: $LOG_FILE"
    
    # Create logs directory
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Check dependencies
    check_dependencies || return 1
    
    # Wait for Authentik to be ready
    wait_for_service "Authentik" "${AUTHENTIK_URL:-http://authentik:9000}/api/v3/" 60 || return 1
    
    # Create user groups
    create_user_groups
    
    # Create OIDC provider for homelab
    local redirect_uris="https://grafana.localhost/login/generic_oauth"
    redirect_uris="$redirect_uris https://gitea.localhost/user/oauth2/authentik/callback"
    redirect_uris="$redirect_uris https://nextcloud.localhost/apps/oauth2/redirect"
    
    local provider_id
    provider_id=$(create_oidc_provider "Homelab SSO" "homelab-client" "$redirect_uris") || return 1
    
    # Get client secret (would be generated by Authentik)
    log_info "Getting client secret for provider ID: $provider_id"
    
    # Configure services
    configure_grafana "homelab-client" "generated-secret-placeholder"
    configure_gitea "homelab-client" "generated-secret-placeholder"
    configure_nextcloud "homelab-client" "generated-secret-placeholder"
    configure_outline "homelab-client" "generated-secret-placeholder"
    configure_openwebui "homelab-client" "generated-secret-placeholder"
    configure_portainer "homelab-client" "generated-secret-placeholder"
    
    log_success "Authentik setup completed successfully!"
    log_info "Next steps:"
    log_info "1. Update the client secret in .env file"
    log_info "2. Restart the services to apply OIDC configuration"
    log_info "3. Test the OIDC login flow for each service"
}

# --------------------------
# Dry-run Mode
# --------------------------
dry_run() {
    log_info "Running in DRY-RUN mode"
    log_info "This mode validates configuration without making changes"
    
    check_dependencies || return 1
    
    log_info "Checking environment variables..."
    
    local required_vars=("AUTHENTIK_BOOTSTRAP_TOKEN")
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var:-}" ]; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        log_warning "Missing environment variables: ${missing_vars[*]}"
        log_info "Please set these variables before running the actual setup"
    else
        log_success "All required environment variables are set"
    fi
    
    log_info "Configuration file: $CONFIG_FILE"
    if [ -f "$CONFIG_FILE" ]; then
        log_success "Configuration file exists"
    else
        log_warning "Configuration file does not exist"
    fi
    
    log_success "Dry-run completed successfully"
    log_info "To run the actual setup, remove the --dry-run flag"
}

# --------------------------
# Help Function
# --------------------------
show_help() {
    cat << EOF
Enhanced Authentik Setup Script

Usage: $0 [OPTIONS]

Options:
  --dry-run     Validate configuration without making changes
  --help        Show this help message
  --log-level   Set log level (info, debug, error)
  
Environment Variables:
  AUTHENTIK_BOOTSTRAP_TOKEN    Bootstrap token for Authentik API access
  AUTHENTIK_URL                Authentik base URL (default: http://authentik:9000)

Examples:
  # Dry-run to validate configuration
  $0 --dry-run
  
  # Run actual setup
  $0
  
  # With custom Authentik URL
  AUTHENTIK_URL=http://localhost:9000 $0
EOF
}

# --------------------------
# Main Script Execution
# --------------------------
main() {
    local dry_run=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                dry_run=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    if [ "$dry_run" = true ]; then
        dry_run
    else
        main_setup
    fi
}

# Run main function
main "$@"