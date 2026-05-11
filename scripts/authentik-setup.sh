#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Authentik Setup Script
# Creates OIDC providers + applications for all services.
#
# Idempotent — safe to run multiple times.
# Usage:
#   ./scripts/authentik-setup.sh           # Interactive setup
#   ./scripts/authentik-setup.sh --dry-run # Preview without changes
#   ./scripts/authentik-setup.sh --force   # Skip confirmations
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SSO_DIR="$REPO_ROOT/stacks/sso"
SSO_ENV="$SSO_DIR/.env"
LOG_FILE="$REPO_ROOT/logs/authentik-setup-$(date +%Y%m%d-%H%M%S).log"

DRY_RUN=false
FORCE=false
VERBOSE=false

# -----------------------------------------------------------------------------
# Parse arguments
# -----------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true; shift ;;
        --force)   FORCE=true; shift ;;
        --verbose) VERBOSE=true; shift ;;
        -h|--help)
            echo "Usage: $0 [--dry-run] [--force] [--verbose]"
            echo ""
            echo "Options:"
            echo "  --dry-run   Preview changes without applying them"
            echo "  --force     Skip all confirmation prompts"
            echo "  --verbose   Show detailed API responses"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# -----------------------------------------------------------------------------
# Setup logging
# -----------------------------------------------------------------------------
mkdir -p "$(dirname "$LOG_FILE")"
exec 2> >(tee -a "$LOG_FILE" >&2)
[ "$VERBOSE" = true ] && exec 1> >(tee -a "$LOG_FILE")

log()  { echo "[$(date '+%H:%M:%S')] $*"; }
warn() { echo "[$(date '+%H:%M:%S')] ⚠️  $*" >&2; }
err()  { echo "[$(date '+%H:%M:%S')] ❌ $*" >&2; exit 1; }
ok()   { echo "[$(date '+%H:%M:%S')] ✅ $*"; }

# -----------------------------------------------------------------------------
# Prerequisite checks
# -----------------------------------------------------------------------------
check_prereqs() {
    log "Checking prerequisites..."

    # Check .env exists
    if [ ! -f "$SSO_ENV" ]; then
        err "SSO .env not found at $SSO_ENV. Run: cp $SSO_DIR/.env.example $SSO_ENV && nano $SSO_ENV"
    fi

    # Load environment
    set -a; source "$SSO_ENV"; set +a

    # Validate required vars
    local required_vars=(
        AUTHENTIK_SECRET_KEY
        AUTHENTIK_POSTGRES_PASSWORD
        AUTHENTIK_REDIS_PASSWORD
        AUTHENTIK_BOOTSTRAP_EMAIL
        AUTHENTIK_BOOTSTRAP_PASSWORD
        AUTHENTIK_DOMAIN
    )
    for var in "${required_vars[@]}"; do
        if [ -z "${!var:-}" ]; then
            err "$var is empty. Set it in $SSO_ENV"
        fi
    done

    # Check Authentik is running
    local health_url="https://${AUTHENTIK_DOMAIN}/-/health/ready/"
    if ! curl -sf --max-time 10 "$health_url" > /dev/null 2>&1; then
        err "Authentik not reachable at $health_url. Is the SSO stack running? Run: cd $SSO_DIR && docker compose up -d"
    fi

    ok "Prerequisites met"
}

# -----------------------------------------------------------------------------
# Get Authentik API token
# -----------------------------------------------------------------------------
get_api_token() {
    log "Obtaining Authentik API token..."

    AUTHENTIK_URL="https://${AUTHENTIK_DOMAIN}"
    AUTHENTIK_API="${AUTHENTIK_URL}/api/v3"

    # Try to use BOOTSTRAP_TOKEN if set, otherwise use password flow
    if [ -n "${AUTHENTIK_BOOTSTRAP_TOKEN:-}" ]; then
        API_TOKEN="$AUTHENTIK_BOOTSTRAP_TOKEN"
        ok "Using bootstrap token"
        return
    fi

    # Password flow to get token
    local token_resp
    token_resp=$(curl -sf --max-time 10 \
        -X POST "${AUTHENTIK_URL}/api/v3/core/tokens/" \
        -H "Content-Type: application/json" \
        -d "{
            \"identifier\": \"${AUTHENTIK_BOOTSTRAP_EMAIL}\",
            \"intent\": \"api\",
            \"managed\": \"goauthentik.io/core/token\"
        }" 2>&1) || true

    if [ -z "$token_resp" ]; then
        err "Failed to get API token. Is Authentik running? Check: docker compose -f $SSO_DIR/docker-compose.yml ps"
    fi

    API_TOKEN=$(echo "$token_resp" | jq -r '.key // empty')
    if [ -z "$API_TOKEN" ]; then
        err "Could not parse API token from response: $token_resp"
    fi

    ok "API token obtained"
}

# -----------------------------------------------------------------------------
# Create OIDC provider
# -----------------------------------------------------------------------------
create_oidc_provider() {
    local name="$1"
    local client_id_var="$2"
    local redirect_uris="$3"

    log "Setting up OIDC provider: $name"

    # Check if provider already exists (idempotent)
    local existing
    existing=$(curl -sf --max-time 10 \
        -H "Authorization: Bearer $API_TOKEN" \
        "${AUTHENTIK_API}/core/providers/?search=${name}" 2>/dev/null | \
        jq -r '.results[] | select(.name=="'"$name"'") | .pk // empty')

    if [ -n "$existing" ]; then
        warn "Provider '$name' already exists (pk=$existing). Skipping creation."
        local client_id
        client_id=$(curl -sf --max-time 10 \
            -H "Authorization: Bearer $API_TOKEN" \
            "${AUTHENTIK_API}/core/providers/$existing/" | \
            jq -r '.client_id')
        echo "$client_id"
        return
    fi

    if [ "$DRY_RUN" = true ]; then
        log "[DRY-RUN] Would create OIDC provider: $name"
        echo "DRY_RUN_CLIENT_ID"
        return
    fi

    # Create provider
    local resp
    resp=$(curl -sf --max-time 10 \
        -X POST "${AUTHENTIK_API}/core/providers/" \
        -H "Authorization: Bearer $API_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"name\": \"$name\",
            \"authorization_flow\": \"default-provider-authorization-implicit-consent\",
            \"client_type\": \"confidential\",
            \"client_id\": \"$(openssl rand -hex 20)\",
            \"client_secret\": \"$(openssl rand -hex 32)\",
            \"redirect_uris\": \"$redirect_uris\",
            \"signing_key\": null,
            \"sub_mode\": \"hashed_user_id\",
            \"issuer_mode\": \"per_provider\",
            \"token_validity\": \"hours=24\"
        }")

    local client_id
    client_id=$(echo "$resp" | jq -r '.client_id // empty')
    local pk
    pk=$(echo "$resp" | jq -r '.pk // empty')

    if [ -z "$client_id" ] || [ -z "$pk" ]; then
        err "Failed to create provider '$name': $resp"
    fi

    # Write credentials back to .env
    local env_line="${client_id_var}=${client_id}"
    local secret_line="${client_id_var}_SECRET=$(echo "$resp" | jq -r '.client_secret')"

    if grep -q "^${client_id_var}=" "$SSO_ENV" 2>/dev/null; then
        sed -i "s|^${client_id_var}=.*|${env_line}|" "$SSO_ENV"
    else
        echo "$env_line" >> "$SSO_ENV"
        echo "$secret_line" >> "$SSO_ENV"
    fi

    ok "$name: client_id=$client_id (pk=$pk)"
    echo "$client_id"
}

# -----------------------------------------------------------------------------
# Create application
# -----------------------------------------------------------------------------
create_application() {
    local name="$1"
    local slug="$2"
    local provider_pk="$3"
    local launch_url="$4"

    log "Setting up application: $name"

    # Check if application already exists (idempotent)
    local existing
    existing=$(curl -sf --max-time 10 \
        -H "Authorization: Bearer $API_TOKEN" \
        "${AUTHENTIK_API}/core/applications/?search=${name}" 2>/dev/null | \
        jq -r '.results[] | select(.name=="'"$name"'") | .pk // empty')

    if [ -n "$existing" ]; then
        warn "Application '$name' already exists (pk=$existing). Skipping."
        return 0
    fi

    if [ "$DRY_RUN" = true ]; then
        log "[DRY-RUN] Would create application: $name"
        return 0
    fi

    curl -sf --max-time 10 \
        -X POST "${AUTHENTIK_API}/core/applications/" \
        -H "Authorization: Bearer $API_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"name\": \"$name\",
            \"slug\": \"$slug\",
            \"provider\": $provider_pk,
            \"launch_url\": \"$launch_url\",
            \"meta_icon\": null,
            \"meta_description\": \"$name — HomeLab Stack\"
        }" > /dev/null

    ok "Application: $name"
}

# -----------------------------------------------------------------------------
# Main setup
# -----------------------------------------------------------------------------
main() {
    echo ""
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║     HomeLab Stack — Authentik OIDC Setup             ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo ""

    if [ "$DRY_RUN" = true ]; then
        warn "DRY RUN MODE — No changes will be made"
    fi

    check_prereqs
    get_api_token

    # Define services to configure
    # Format: name | env_var_prefix | redirect_uris | launch_url
    declare -A SERVICES
    SERVICES=(
        ["Grafana"]="grafana.${DOMAIN}|GRAFANA_OAUTH|https://grafana.${DOMAIN}/login/generic_oauth"
        ["Gitea"]="git.${DOMAIN}|GITEA_OAUTH|https://git.${DOMAIN}/user/oauth2/authentik/callback"
        ["Nextcloud"]="nextcloud.${DOMAIN}|NEXTCLOUD_OAUTH|https://nextcloud.${DOMAIN}/apps/sociallogin/custom_oidc/authentik"
        ["Outline"]="docs.${DOMAIN}|OUTLINE_OAUTH|https://docs.${DOMAIN}/auth/oidc.callback"
        ["Open WebUI"]="ai.${DOMAIN}|OPENWEBUI_OAUTH|https://ai.${DOMAIN}/oauth/oidc/callback"
        ["Portainer"]="portainer.${DOMAIN}|PORTAINER_OAUTH|https://portainer.${DOMAIN}/"
    )

    echo ""
    echo "Services to configure:"
    for name in "${!SERVICES[@]}"; do
        echo "  • $name"
    done
    echo ""

    if [ "$FORCE" != true ] && [ "$DRY_RUN" != true ]; then
        read -rp "Proceed with setup? [Y/n] " confirm
        [[ "$confirm" =~ ^[Nn] ]] && { log "Aborted by user."; exit 0; }
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    for name in "${!SERVICES[@]}"; do
        IFS='|' read -r domain env_prefix redirect_uri <<< "${SERVICES[$name]}"

        CLIENT_ID=$(create_oidc_provider "$name" "${env_prefix}_CLIENT_ID" "$redirect_uri")

        # Update .env with client_id
        if [ "$DRY_RUN" != true ] && [ -n "$CLIENT_ID" ] && [ "$CLIENT_ID" != "DRY_RUN_CLIENT_ID" ]; then
            if grep -q "^${env_prefix}_CLIENT_ID=" "$SSO_ENV" 2>/dev/null; then
                sed -i "s|^${env_prefix}_CLIENT_ID=.*|${env_prefix}_CLIENT_ID=${CLIENT_ID}|" "$SSO_ENV"
            else
                echo "${env_prefix}_CLIENT_ID=${CLIENT_ID}" >> "$SSO_ENV"
            fi
        fi
    done

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    ok "All OIDC providers configured!"
    echo ""
    echo "Next steps:"
    echo "  1. Restart services to pick up new OAuth configs:"
    echo "     docker compose -f stacks/sso/docker-compose.yml restart"
    echo "  2. Verify each service's login page shows 'Login with Authentik'"
    echo "  3. Check credentials in $SSO_ENV"
    echo ""
    echo "Log: $LOG_FILE"
}

main "$@"
