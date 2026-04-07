#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Enhanced Authentik SSO Setup Script
# Creates OIDC providers, validates setup, and provides testing procedures
# Supports both manual and automated testing
# Usage: ./setup-authentik-enhanced.sh [auto|manual]
# =============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")
SSO_DIR="$ROOT_DIR/stacks/sso"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# Logging functions
log_info()  { echo -e "${GREEN}[INFO]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_step()  { echo; echo -e "${BOLD}${CYAN}==> $*${RESET}"; }

# Test mode flag
TEST_MODE=false

# Parse arguments
case "${1:-}" in
    "auto")
        log_info "Running in automated mode..."
        TEST_MODE=true
        ;;
    "manual")
        log_info "Running in manual mode..."
        TEST_MODE=false
        ;;
    "")
        log_info "Running in interactive mode..."
        TEST_MODE=false
        ;;
    *)
        log_error "Usage: $0 [auto|manual]"
        exit 1
        ;;
esac

# Load environment
load_env() {
    log_step "Loading environment configuration"
    
    if [ ! -f "$ROOT_DIR/.env" ]; then
        log_error "Root .env file not found: $ROOT_DIR/.env"
        log_info "Please copy .env.example to .env and configure your settings"
        exit 1
    fi
    
    # Load root .env
    set -a; source "$ROOT_DIR/.env"; set +a
    
    # Load SSO .env (if exists)
    if [ -f "$SSO_DIR/.env" ]; then
        set -a; source "$SSO_DIR/.env"; set +a
    fi
    
    # Validate required variables
    local required_vars=(
        "DOMAIN"
        "AUTHENTIK_DOMAIN"
        "AUTHENTIK_BOOTSTRAP_EMAIL"
        "AUTHENTIK_BOOTSTRAP_PASSWORD"
        "AUTHENTIK_BOOTSTRAP_TOKEN"
        "AUTHENTIK_SECRET_KEY"
        "AUTHENTIK_POSTGRES_PASSWORD"
        "AUTHENTIK_REDIS_PASSWORD"
    )
    
    local missing_vars=()
    for var in "${required_vars[@]}"; do
        if [ -z "${!var:-}" ]; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        log_error "Missing required environment variables:"
        for var in "${missing_vars[@]}"; do
            echo "  - $var"
        done
        log_info "Please fill these values in $SSO_DIR/.env"
        exit 1
    fi
    
    log_info "Environment configuration loaded successfully"
}

# Check prerequisites
check_prerequisites() {
    log_step "Checking prerequisites"
    
    local required_commands=("curl" "jq" "docker" "docker-compose")
    local missing_commands=()
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [ ${#missing_commands[@]} -gt 0 ]; then
        log_error "Missing required commands:"
        for cmd in "${missing_commands[@]}"; do
            echo "  - $cmd"
        done
        log_error "Please install missing dependencies"
        exit 1
    fi
    
    log_info "All prerequisites satisfied"
}

# Check base stack
check_base_stack() {
    log_step "Checking base stack status"
    
    # Check if proxy network exists
    if ! docker network ls | grep -q "proxy"; then
        log_warn "Proxy network not found"
        log_info "Base stack may not be running. Please start base stack first:"
        log_info "  docker compose -f docker-compose.base.yml up -d"
        return 1
    fi
    
    log_info "Base stack is running"
}

# Check SSO stack status
check_sso_stack() {
    log_step "Checking SSO stack status"
    
    cd "$SSO_DIR"
    
    # Check if containers are running
    if ! docker compose ps >/dev/null 2>&1; then
        log_error "SSO stack is not running"
        log_info "Please start the SSO stack first:"
        log_info "  docker compose up -d"
        exit 1
    fi
    
    # Wait for Authentik to be ready
    log_info "Waiting for Authentik API to be ready..."
    local authentik_url="https://${AUTHENTIK_DOMAIN}"
    
    for i in {1..30}; do
        if curl -sf "$authentik_url/-/health/ready/" -o /dev/null; then
            log_info "Authentik is ready"
            break
        fi
        
        if [ $i -eq 30 ]; then
            log_error "Authentik did not become ready in 150s"
            exit 1
        fi
        
        echo -n "."
        sleep 5
    done
    
    cd "$ROOT_DIR"
}

# OIDC Provider creation with validation
create_oidc_provider() {
    local name="$1"
    local redirect_uri="$2"
    local client_id_var="$3"
    local client_secret_var="$4"
    
    log_step "Creating OIDC provider: $name"
    
    local authentik_url="https://${AUTHENTIK_DOMAIN}"
    local api_url="$authentik_url/api/v3"
    local auth_header="Authorization: Bearer ${AUTHENTIK_BOOTSTRAP_TOKEN}"
    
    # Get default authorization flow
    local flow_pk
    flow_pk=$(curl -sf "$api_url/flows/instances/?designation=authorization&ordering=slug" \
        -H "$auth_header" | jq -r '.results[0].pk')
    
    if [ "$flow_pk" = "null" ] || [ -z "$flow_pk" ]; then
        log_error "Could not find authorization flow for $name"
        return 1
    fi
    
    # Get signing key
    local signing_key
    signing_key=$(curl -sf "$api_url/crypto/certificatekeypairs/?has_key=true&ordering=name" \
        -H "$auth_header" | jq -r '.results[0].pk')
    
    if [ "$signing_key" = "null" ] || [ -z "$signing_key" ]; then
        log_error "Could not find signing key for $name"
        return 1
    fi
    
    # Create provider
    local slug
    slug=$(echo "$name" | tr '[:upper:]' '[:lower:]')
    
    local payload
    payload=$(jq -n \
        --arg name "${name} Provider" \
        --arg flow "$flow_pk" \
        --arg uri "$redirect_uri" \
        --arg key "$signing_key" \
        '{
          name: $name,
          authorization_flow: $flow,
          client_type: "confidential",
          redirect_uris: [$uri],
          sub_mode: "hashed_user_id",
          include_claims_in_id_token: true,
          signing_key: $key
        }')
    
    local response
    response=$(curl -sf -X POST "$api_url/providers/oauth2/" \
        -H "$auth_header" \
        -H "Content-Type: application/json" \
        -d "$payload")
    
    if [ $? -ne 0 ]; then
        log_error "Failed to create OIDC provider for $name"
        return 1
    fi
    
    local provider_pk client_id client_secret
    provider_pk=$(echo "$response" | jq -r '.pk')
    client_id=$(echo "$response" | jq -r '.client_id')
    client_secret=$(echo "$response" | jq -r '.client_secret')
    
    log_info "  Provider created: $provider_pk"
    log_info "  Client ID: $client_id"
    
    # Update .env file
    sed -i "s|^${client_id_var}=.*|${client_id_var}=${client_id}|" "$ROOT_DIR/.env"
    sed -i "s|^${client_secret_var}=.*|${client_secret_var}=${client_secret}|" "$ROOT_DIR/.env"
    
    # Create application
    local app_payload
    app_payload=$(jq -n \
        --arg name "$name" \
        --arg slug "$slug" \
        --argjson pk "$provider_pk" \
        '{name: $name, slug: $slug, provider: $pk}')
    
    curl -sf -X POST "$api_url/core/applications/" \
        -H "$auth_header" \
        -H "Content-Type: application/json" \
        -d "$app_payload" > /dev/null
    
    log_info "  Application created: $name"
}

# Create all OIDC providers
create_providers() {
    log_step "Creating OIDC providers for all services"
    
    # Grafana
    create_oidc_provider \
        "Grafana" \
        "https://grafana.${DOMAIN}/login/generic_oauth" \
        "GRAFANA_OAUTH_CLIENT_ID" \
        "GRAFANA_OAUTH_CLIENT_SECRET"
    
    # Gitea
    create_oidc_provider \
        "Gitea" \
        "https://git.${DOMAIN}/user/oauth2/Authentik/callback" \
        "GITEA_OAUTH_CLIENT_ID" \
        "GITEA_OAUTH_CLIENT_SECRET"
    
    # Outline
    create_oidc_provider \
        "Outline" \
        "https://outline.${DOMAIN}/auth/oidc.callback" \
        "OUTLINE_OAUTH_CLIENT_ID" \
        "OUTLINE_OAUTH_CLIENT_SECRET"
    
    # Portainer
    create_oidc_provider \
        "Portainer" \
        "https://portainer.${DOMAIN}/" \
        "PORTAINER_OAUTH_CLIENT_ID" \
        "PORTAINER_OAUTH_CLIENT_SECRET"
}

# Test SSO functionality
test_sso_functionality() {
    log_step "Testing SSO functionality"
    
    if [ "$TEST_MODE" = "false" ]; then
        log_info "Skipping automated tests (manual mode)"
        return 0
    fi
    
    local authentik_url="https://${AUTHENTIK_DOMAIN}"
    
    # Test Authentik health
    if curl -sf "$authentik_url/-/health/ready/" -o /dev/null; then
        log_info "✓ Authentik health check passed"
    else
        log_error "✗ Authentik health check failed"
        return 1
    fi
    
    # Test admin UI access
    if curl -sf "$authentik_url/if/admin/" -o /dev/null; then
        log_info "✓ Authentik admin UI accessible"
    else
        log_warn "⚠ Authentik admin UI not accessible (may be normal during setup)"
    fi
    
    # Test OIDC endpoints
    local issuer_url="$authentik_url/application/o/.well-known/oauth-issuer"
    if curl -sf "$issuer_url" -o /dev/null; then
        log_info "✓ OIDC issuer endpoint accessible"
    else
        log_warn "⚠ OIDC issuer endpoint not ready (may take time to propagate)"
    fi
}

# Generate deployment documentation
generate_documentation() {
    log_step "Generating deployment documentation"
    
    local doc_file="$SSO_DIR/DEPLOYMENT_GUIDE.md"
    
    cat > "$doc_file" << 'EOF'
# Authentik SSO Deployment Guide

## Quick Start

```bash
# 1. Configure environment
cp .env.example .env
# Fill in all required values in .env

# 2. Generate secrets
export AUTHENTIK_SECRET_KEY=$(openssl rand -base64 32)
export AUTHENTIK_POSTGRES_PASSWORD=$(openssl rand -hex 16)
export AUTHENTIK_REDIS_PASSWORD=$(openssl rand -hex 16)
export AUTHENTIK_BOOTSTRAP_TOKEN=$(openssl rand -hex 32)

# Update .env with generated values
sed -i "s|^AUTHENTIK_SECRET_KEY=.*|AUTHENTIK_SECRET_KEY=$AUTHENTIK_SECRET_KEY|" .env
sed -i "s|^AUTHENTIK_POSTGRES_PASSWORD=.*|AUTHENTIK_POSTGRES_PASSWORD=$AUTHENTIK_POSTGRES_PASSWORD|" .env
sed -i "s|^AUTHENTIK_REDIS_PASSWORD=.*|AUTHENTIK_REDIS_PASSWORD=$AUTHENTIK_REDIS_PASSWORD|" .env
sed -i "s|^AUTHENTIK_BOOTSTRAP_TOKEN=.*|AUTHENTIK_BOOTSTRAP_TOKEN=$AUTHENTIK_BOOTSTRAP_TOKEN|" .env

# 3. Start services
docker compose up -d

# 4. Setup OIDC providers
../../scripts/setup-authentik-enhanced.sh auto

# 5. Verify setup
curl -sf https://auth.DOMAIN/-/health/ready/
```

## Configuration

### Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `AUTHENTIK_SECRET_KEY` | YES | Random secret — `openssl rand -base64 32` |
| `AUTHENTIK_POSTGRES_PASSWORD` | YES | PostgreSQL password |
| `AUTHENTIK_REDIS_PASSWORD` | YES | Redis password |
| `AUTHENTIK_BOOTSTRAP_EMAIL` | YES | Initial admin email |
| `AUTHENTIK_BOOTSTRAP_PASSWORD` | YES | Initial admin password |
| `AUTHENTIK_BOOTSTRAP_TOKEN` | YES | API token for setup script |
| `AUTHENTIK_DOMAIN` | YES | e.g. `auth.yourdomain.com` |

### Service Integration

#### Services with OIDC Support

- **Grafana**: Uses OIDC with client ID/secret from .env
- **Gitea**: Uses OIDC with `https://git.DOMAIN/user/oauth2/Authentik/callback`
- **Outline**: Uses OIDC with `https://outline.DOMAIN/auth/oidc.callback`
- **Portainer**: Uses OIDC with embedded outpost

#### Services with ForwardAuth

Add to any service's Traefik labels:

```yaml
traefik.http.routers.<name>.middlewares: authentik@file
```

### Health Monitoring

```bash
# Check container health
docker compose ps

# Check Authentik API
curl -sf https://auth.DOMAIN/-/health/ready/

# Check PostgreSQL
docker exec authentik-postgres pg_isready -U authentik

# Check Redis
docker exec authentik-redis redis-cli -a ${AUTHENTIK_REDIS_PASSWORD} ping
```

## Backup & Recovery

### Backup Authentik Data

```bash
# Create backup directory
mkdir -p /backup/authentik

# Backup volumes
docker run --rm -v authentik_media:/data -v authentik_templates:/templates \
  -v authentik-backup:/backup alpine tar czf /backup/authentik-data.tar.gz -C /data . -C /templates .
```

### Restore from Backup

```bash
# Stop services
docker compose down

# Restore volumes
docker run --rm -v authentik_media:/data -v authentik_templates:/templates \
  -v authentik-backup:/backup alpine tar xzf /backup/authentik-data.tar.gz -C /data -C /templates .

# Start services
docker compose up -d
```

## Troubleshooting

### Common Issues

1. **Container exits immediately**
   - Check `AUTHENTIK_SECRET_KEY` is set and non-empty
   - Verify PostgreSQL is running before starting Authentik

2. **DB connection refused**
   - Wait 30s for PostgreSQL to initialize
   - Check `AUTHENTIK_POSTGRES_PASSWORD` matches

3. **OIDC redirect mismatch**
   - Ensure `redirect_uris` in Authentik provider matches exact callback URL
   - Check domain configuration in .env

4. **ForwardAuth loop**
   - Ensure authentik outpost URL uses internal hostname
   - Verify Traefik configuration

### CN Mirror Configuration

If `ghcr.io` is inaccessible, ensure the CN mirror is enabled in `docker-compose.yml`:

```yaml
image: swr.cn-north-4.myhuawei
```

EOF
    
    log_info "Documentation generated: $doc_file"
}

# Main execution
main() {
    log_info "Starting enhanced Authentik SSO setup"
    
    load_env
    check_prerequisites
    check_base_stack
    check_sso_stack
    create_providers
    test_sso_functionality
    generate_documentation
    
    log_step "Setup completed successfully!"
    
    log_info "Next steps:"
    log_info "1. Access Authentik admin UI: https://${AUTHENTIK_DOMAIN}"
    log_info "2. Login with: ${AUTHENTIK_BOOTSTRAP_EMAIL}"
    log_info "3. Configure users, groups, and policies as needed"
    log_info "4. Test login to integrated services"
    log_info "5. See DEPLOYMENT_GUIDE.md for detailed documentation"
}

# Run main function
main "$@"