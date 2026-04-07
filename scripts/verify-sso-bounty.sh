#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — SSO Bounty Verification Script
# Comprehensive end-to-end verification for Bounty Task #9
# Generates all required evidence for bounty submission
#
# Usage: ./scripts/verify-sso-bounty.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")
SSO_DIR="$ROOT_DIR/stacks/sso"
REPORT_DIR="$ROOT_DIR/bounty-evidence"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_step()  { echo -e "${BOLD}${CYAN}==> $*${RESET}"; }

# Source Docker Compose wrapper
source "$SCRIPT_DIR/docker-compose-wrapper.sh" || {
    log_error "Failed to load Docker Compose wrapper"
    exit 1
}

# Create report directory
mkdir -p "$REPORT_DIR"

REPORT_FILE="$REPORT_DIR/verification_report_${TIMESTAMP}.txt"
LOG_FILE="$REPORT_DIR/verification_${TIMESTAMP}.log"

# Initialize report
cat > "$REPORT_FILE" << EOF
================================================================================
Authentik SSO Integration — Bounty Verification Report
================================================================================
Date: $(date)
Bounty: Task #9 — [BOUNTY \$300] SSO — Authentik 统一身份认证
Repository: $(git -C "$ROOT_DIR" remote get-url origin 2>/dev/null || echo "local")
Commit: $(git -C "$ROOT_DIR" rev-parse HEAD 2>/dev/null || echo "N/A")

================================================================================
SECTION 1: ENVIRONMENT VALIDATION
================================================================================

EOF

# Function to append to report
append_report() {
    echo -e "$1" >> "$REPORT_FILE"
}

# Function to run command and log output
run_and_log() {
    local description="$1"
    local command="$2"
    
    log_step "$description"
    append_report "\n[$description]"
    append_report "Command: $command"
    append_report "Output:"
    
    if output=$(eval "$command" 2>&1); then
        append_report "$output"
        append_report "Status: ✓ SUCCESS"
        log_info "✓ $description completed"
        return 0
    else
        append_report "$output"
        append_report "Status: ✗ FAILED"
        log_error "✗ $description failed"
        return 1
    fi
}

# Start verification
log_step "Starting SSO Bounty Verification"
log_info "Report will be saved to: $REPORT_FILE"

# =============================================================================
# SECTION 1: Environment Validation
# =============================================================================

log_step "Section 1: Environment Validation"

# Check required commands
append_report "Required Commands:"
for cmd in docker curl jq openssl; do
    if command -v "$cmd" >/dev/null 2>&1; then
        version=$("$cmd" --version 2>/dev/null | head -1 || echo "installed")
        append_report "  ✓ $cmd: $version"
        log_info "✓ $cmd installed"
    else
        append_report "  ✗ $cmd: NOT FOUND"
        log_error "✗ $cmd not found"
    fi
done

# Check Docker Compose
append_report "\nDocker Compose:"
if detect_docker_compose 2>/dev/null; then
    version=$($DOCKER_COMPOSE version 2>/dev/null || echo "unknown")
    append_report "  ✓ Docker Compose: $version"
    log_info "✓ Docker Compose: $DOCKER_COMPOSE"
else
    append_report "  ✗ Docker Compose: NOT FOUND"
    log_error "✗ Docker Compose not found"
fi

# Load environment variables
if [ -f "$ROOT_DIR/.env" ]; then
    append_report "\nEnvironment Variables Loaded: YES"
    set -a; source "$ROOT_DIR/.env"; set +a
    
    # Check required variables (masking secrets)
    append_report "\nRequired Environment Variables:"
    for var in DOMAIN AUTHENTIK_DOMAIN AUTHENTIK_BOOTSTRAP_EMAIL; do
        if [ -n "${!var:-}" ]; then
            append_report "  ✓ $var: ${!var}"
        else
            append_report "  ✗ $var: NOT SET"
        fi
    done
    
    # Check secrets (show only length)
    append_report "\nSecret Keys (length only):"
    for var in AUTHENTIK_SECRET_KEY AUTHENTIK_POSTGRES_PASSWORD AUTHENTIK_REDIS_PASSWORD AUTHENTIK_BOOTSTRAP_TOKEN; do
        if [ -n "${!var:-}" ]; then
            append_report "  ✓ $var: ${#var} chars"
        else
            append_report "  ✗ $var: NOT SET"
        fi
    done
else
    append_report "\nEnvironment Variables: ✗ .env file not found"
    log_error ".env file not found"
fi

# =============================================================================
# SECTION 2: Infrastructure Verification
# =============================================================================

append_report "\n\n================================================================================
SECTION 2: INFRASTRUCTURE VERIFICATION
================================================================================
"

log_step "Section 2: Infrastructure Verification"

# Check Docker networks
append_report "Docker Networks:"
if dcc network ls 2>/dev/null | grep -q "proxy"; then
    append_report "  ✓ proxy network exists"
    log_info "✓ proxy network exists"
else
    append_report "  ✗ proxy network not found"
    log_warn "⚠ proxy network not found (base stack may not be running)"
fi

# Check SSO stack containers
append_report "\nSSO Stack Containers:"
cd "$SSO_DIR"

if dcc ps 2>/dev/null; then
    append_report "$(dcc ps 2>/dev/null)"
    
    # Check each required container
    for container in postgresql redis authentik-server authentik-worker; do
        if dcc ps 2>/dev/null | grep -q "$container"; then
            status=$(dcc ps 2>/dev/null | grep "$container" | awk '{print $4}')
            append_report "\n  $container: $status"
            if [[ "$status" == *"healthy"* ]]; then
                log_info "✓ $container healthy"
            else
                log_warn "⚠ $container not healthy"
            fi
        else
            append_report "\n  ✗ $container: NOT RUNNING"
            log_error "✗ $container not running"
        fi
    done
else
    append_report "  ✗ SSO stack not running"
    log_error "✗ SSO stack not running"
fi

# Check Traefik configuration
append_report "\nTraefik Configuration:"
if [ -f "$ROOT_DIR/config/traefik/dynamic/authentik.yml" ]; then
    append_report "  ✓ authentik.yml exists"
    append_report "\n$(cat "$ROOT_DIR/config/traefik/dynamic/authentik.yml")"
else
    append_report "  ✗ authentik.yml not found"
fi

# =============================================================================
# SECTION 3: Authentik Health Checks
# =============================================================================

append_report "\n\n================================================================================
SECTION 3: AUTHENTIK HEALTH CHECKS
================================================================================
"

log_step "Section 3: Authentik Health Checks"

# Check Authentik API health
if [ -n "${AUTHENTIK_DOMAIN:-}" ]; then
    authentik_url="https://${AUTHENTIK_DOMAIN}"
    
    append_report "Authentik URL: $authentik_url\n"
    
    # Health check
    append_report "Health Check:"
    if curl -sfk "$authentik_url/-/health/ready/" -o /dev/null 2>&1; then
        append_report "  ✓ Authentik API healthy"
        log_info "✓ Authentik API healthy"
    else
        append_report "  ✗ Authentik API unhealthy"
        log_error "✗ Authentik API unhealthy"
    fi
    
    # Admin UI check
    append_report "\nAdmin UI Check:"
    if curl -sfk "$authentik_url/if/admin/" -o /dev/null 2>&1; then
        append_report "  ✓ Admin UI accessible"
        log_info "✓ Admin UI accessible"
    else
        append_report "  ✗ Admin UI not accessible"
        log_warn "⚠ Admin UI not accessible"
    fi
    
    # OIDC discovery
    append_report "\nOIDC Discovery:"
    if curl -sfk "$authentik_url/application/o/.well-known/oauth-issuer" 2>&1; then
        append_report "\n  ✓ OIDC issuer endpoint accessible"
        log_info "✓ OIDC issuer accessible"
    else
        append_report "\n  ✗ OIDC issuer endpoint not accessible"
        log_warn "⚠ OIDC issuer not accessible"
    fi
else
    append_report "  ✗ AUTHENTIK_DOMAIN not configured"
    log_error "✗ AUTHENTIK_DOMAIN not configured"
fi

# Check database connectivity
append_report "\nDatabase Connectivity:"
if docker exec authentik-postgres pg_isready -U authentik -d authentik >/dev/null 2>&1; then
    append_report "  ✓ PostgreSQL accepting connections"
    log_info "✓ PostgreSQL healthy"
else
    append_report "  ✗ PostgreSQL not accepting connections"
    log_error "✗ PostgreSQL unhealthy"
fi

if docker exec authentik-redis redis-cli -a "${AUTHENTIK_REDIS_PASSWORD:-}" ping >/dev/null 2>&1; then
    append_report "  ✓ Redis responding"
    log_info "✓ Redis healthy"
else
    append_report "  ✗ Redis not responding"
    log_error "✗ Redis unhealthy"
fi

# =============================================================================
# SECTION 4: OIDC Provider Verification
# =============================================================================

append_report "\n\n================================================================================
SECTION 4: OIDC PROVIDER VERIFICATION
================================================================================
"

log_step "Section 4: OIDC Provider Verification"

if [ -n "${AUTHENTIK_BOOTSTRAP_TOKEN:-}" ] && [ -n "${AUTHENTIK_DOMAIN:-}" ]; then
    api_url="https://${AUTHENTIK_DOMAIN}/api/v3"
    auth_header="Authorization: Bearer ${AUTHENTIK_BOOTSTRAP_TOKEN}"
    
    # Get all OAuth2 providers
    append_report "OAuth2 Providers:\n"
    providers=$(curl -sfk -H "$auth_header" "$api_url/providers/oauth2/" 2>&1)
    
    if [ $? -eq 0 ]; then
        append_report "$providers" | jq -r '.results[] | "  - \(.name) (ID: \(.client_id))"' 2>/dev/null || append_report "$providers"
        
        # Check for each expected provider
        for service in Grafana Gitea Outline Portainer Nextcloud; do
            if echo "$providers" | grep -q "$service"; then
                append_report "\n  ✓ $service provider configured"
                log_info "✓ $service provider found"
            else
                append_report "\n  ✗ $service provider not found"
                log_warn "⚠ $service provider not found"
            fi
        done
    else
        append_report "  ✗ Failed to fetch providers: $providers"
        log_error "✗ Failed to fetch providers"
    fi
    
    # Check applications
    append_report "\n\nApplications:\n"
    applications=$(curl -sfk -H "$auth_header" "$api_url/core/applications/" 2>&1)
    
    if [ $? -eq 0 ]; then
        append_report "$applications" | jq -r '.results[] | "  - \(.name) (Slug: \(.slug))"' 2>/dev/null || append_report "$applications"
    else
        append_report "  ✗ Failed to fetch applications"
    fi
else
    append_report "  ✗ Cannot verify OIDC providers (missing token or domain)"
    log_error "✗ Cannot verify OIDC providers"
fi

# =============================================================================
# SECTION 5: Service Integration Status
# =============================================================================

append_report "\n\n================================================================================
SECTION 5: SERVICE INTEGRATION STATUS
================================================================================
"

log_step "Section 5: Service Integration Status"

# Check OAuth credentials in .env
append_report "OAuth Credentials in .env:\n"
for service in GRAFANA GITEA OUTLINE PORTAINER NEXTCLOUD; do
    client_id_var="${service}_OAUTH_CLIENT_ID"
    client_secret_var="${service}_OAUTH_CLIENT_SECRET"
    
    if [ -n "${!client_id_var:-}" ] && [ -n "${!client_secret_var:-}" ]; then
        append_report "  ✓ $service: Client ID (${#client_id_var} chars), Secret (${#client_secret_var} chars)"
        log_info "✓ $service OAuth credentials configured"
    else
        append_report "  ✗ $service: Credentials not configured"
        log_warn "⚠ $service OAuth credentials not configured"
    fi
done

# Check service docker-compose files for OIDC configuration
append_report "\n\nService OIDC Configuration:\n"

# Grafana
if [ -f "$ROOT_DIR/stacks/monitoring/docker-compose.yml" ]; then
    if grep -q "GF_AUTH_GENERIC_OAUTH" "$ROOT_DIR/stacks/monitoring/docker-compose.yml" 2>/dev/null; then
        append_report "  ✓ Grafana: OIDC configuration found"
    else
        append_report "  ✗ Grafana: OIDC configuration not found"
    fi
fi

# Gitea
if [ -f "$ROOT_DIR/stacks/productivity/docker-compose.yml" ]; then
    if grep -q "GITEA.*oauth" "$ROOT_DIR/stacks/productivity/docker-compose.yml" 2>/dev/null; then
        append_report "  ✓ Gitea: OAuth configuration found"
    else
        append_report "  ✗ Gitea: OAuth configuration not found"
    fi
fi

# Outline
if [ -f "$ROOT_DIR/stacks/productivity/docker-compose.yml" ]; then
    if grep -q "OIDC_" "$ROOT_DIR/stacks/productivity/docker-compose.yml" 2>/dev/null; then
        append_report "  ✓ Outline: OIDC configuration found"
    else
        append_report "  ✗ Outline: OIDC configuration not found"
    fi
fi

# =============================================================================
# SECTION 6: Test Suite Execution
# =============================================================================

append_report "\n\n================================================================================
SECTION 6: TEST SUITE EXECUTION
================================================================================
"

log_step "Section 6: Test Suite Execution"

# Run test suite
append_report "Running SSO test suite...\n"
if "$SCRIPT_DIR/test-sso.sh" all >> "$LOG_FILE" 2>&1; then
    append_report "✓ All tests passed"
    append_report "\nTest output saved to: $LOG_FILE"
    log_info "✓ All tests passed"
else
    append_report "✗ Some tests failed"
    append_report "\nTest output saved to: $LOG_FILE"
    log_error "✗ Some tests failed"
fi

# =============================================================================
# SECTION 7: Verification Summary
# =============================================================================

append_report "\n\n================================================================================
SECTION 7: VERIFICATION SUMMARY
================================================================================
"

log_step "Section 7: Verification Summary"

append_report "Infrastructure Status:"
append_report "  - Docker: $(command -v docker >/dev/null 2>&1 && echo '✓ Installed' || echo '✗ Not installed')"
append_report "  - Docker Compose: $(detect_docker_compose >/dev/null 2>&1 && echo '✓ Available' || echo '✗ Not available')"
append_report "  - SSO Stack: $(dcc ps 2>/dev/null | grep -q authentik && echo '✓ Running' || echo '✗ Not running')"
append_report "  - Authentik API: $(curl -sfk "https://${AUTHENTIK_DOMAIN:-}/-/health/ready/" -o /dev/null 2>&1 && echo '✓ Healthy' || echo '✗ Unhealthy')"

append_report "\nRequired Evidence Files:"
append_report "  - Verification Report: $REPORT_FILE"
append_report "  - Test Log: $LOG_FILE"
append_report "  - Screenshot directory: $REPORT_DIR/screenshots/"

append_report "\nNext Steps:"
append_report "  1. Capture screenshots of OIDC login flows"
append_report "  2. Test each service integration manually"
append_report "  3. Document configuration files"
append_report "  4. Submit bounty with all evidence"

append_report "\n================================================================================
END OF VERIFICATION REPORT
================================================================================
"

# Display report location
log_step "Verification Complete"
log_info "Report saved to: $REPORT_FILE"
log_info "Test log saved to: $LOG_FILE"
cat "$REPORT_FILE"

# Create screenshots directory
mkdir -p "$REPORT_DIR/screenshots"
log_info "Screenshot directory created: $REPORT_DIR/screenshots"
log_info "Please capture required screenshots and save them to this directory"

# Return appropriate exit code
if grep -q "✗" "$REPORT_FILE"; then
    log_warn "Some verification steps failed. Please review the report."
    exit 1
else
    log_info "All verification steps passed!"
    exit 0
fi
