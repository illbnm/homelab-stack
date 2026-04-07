#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — SSO Integration Test Suite
# Validates all SSO functionality including OIDC, ForwardAuth, and integrations
# Usage: ./test-sso.sh [setup|integration|security|all]
# =============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")
SSO_DIR="$ROOT_DIR/stacks/sso"

# Source Docker Compose wrapper for compatibility
source "$SCRIPT_DIR/docker-compose-wrapper.sh"

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

# Load environment
load_env() {
    if [ -f "$ROOT_DIR/.env" ]; then
        set -a; source "$ROOT_DIR/.env"; set +a
    fi
    if [ -f "$SSO_DIR/.env" ]; then
        set -a; source "$SSO_DIR/.env"; set +a
    fi
}

# Test setup validation
test_setup() {
    log_step "Testing SSO Setup Configuration"
    
    local errors=0
    
    # Check required environment variables
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
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var:-}" ]; then
            log_error "Missing required variable: $var"
            errors=$((errors + 1))
        fi
    done
    
    # Check Docker and Docker Compose
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker not installed"
        errors=$((errors + 1))
    fi
    
    # Check for docker compose (v2 plugin) or docker-compose (v1 standalone)
    if ! detect_docker_compose >/dev/null 2>&1; then
        log_error "Docker Compose not installed"
        errors=$((errors + 1))
    fi
    
    # Check running containers
    cd "$SSO_DIR"
    if ! dcc ps >/dev/null 2>&1; then
        log_error "SSO stack not running"
        errors=$((errors + 1))
    fi
    
    cd "$ROOT_DIR"
    
    if [ $errors -eq 0 ]; then
        log_info "✓ Setup validation passed"
    else
        log_error "✗ Setup validation failed with $errors errors"
        return 1
    fi
}

# Test OIDC providers
test_oidc_providers() {
    log_step "Testing OIDC Provider Configuration"
    
    load_env
    
    local authentik_url="https://${AUTHENTIK_DOMAIN}"
    local api_url="$authentik_url/api/v3"
    local auth_header="Authorization: Bearer ${AUTHENTIK_BOOTSTRAP_TOKEN}"
    
    # Test API connectivity
    if ! curl -sf "$api_url/providers/oauth2/" -H "$auth_header" >/dev/null; then
        log_error "Cannot access Authentik API"
        return 1
    fi
    
    # Check each provider
    local providers=(
        "GRAFANA:GRAFANA_OAUTH_CLIENT_ID"
        "GITEA:GITEA_OAUTH_CLIENT_ID"
        "OUTLINE:OUTLINE_OAUTH_CLIENT_ID"
        "PORTAINER:PORTAINER_OAUTH_CLIENT_ID"
    )
    
    local errors=0
    
    for provider_pair in "${providers[@]}"; do
        local name="${provider_pair%%:*}"
        local id_var="${provider_pair##*:}"
        local client_id="${!id_var}"
        
        if [ -z "$client_id" ]; then
            log_warn "⚠ $name OIDC client ID not configured"
            errors=$((errors + 1))
            continue
        fi
        
        # Check if provider exists
        local providers_response
        providers_response=$(curl -sf "$api_url/providers/oauth2/" \
            -H "$auth_header" | jq --arg id "$client_id" '.results[] | select(.client_id == $id)')
        
        if [ -n "$providers_response" ]; then
            log_info "✓ $name OIDC provider configured"
        else
            log_error "✗ $name OIDC provider not found"
            errors=$((errors + 1))
        fi
    done
    
    if [ $errors -eq 0 ]; then
        log_info "✓ All OIDC providers configured correctly"
    else
        log_error "✗ OIDC provider validation failed with $errors errors"
        return 1
    fi
}

# Test ForwardAuth middleware
test_forwardauth() {
    log_step "Testing ForwardAuth Middleware Configuration"
    
    load_env
    
    # Check if authentik middleware file exists
    local middleware_file="$ROOT_DIR/config/traefik/dynamic/authentik.yml"
    if [ ! -f "$middleware_file" ]; then
        log_error "Authentik middleware configuration not found"
        return 1
    fi
    
    # Validate middleware configuration
    if ! grep -q "forwardAuth" "$middleware_file"; then
        log_error "ForwardAuth not configured in middleware file"
        return 1
    fi
    
    if ! grep -q "authentik-server:9000" "$middleware_file"; then
        log_error "Authentik server address not configured correctly"
        return 1
    fi
    
    # Test Traefik configuration reload
    if docker compose -f "$ROOT_DIR/docker-compose.base.yml" exec traefik traefik reload >/dev/null 2>&1; then
        log_info "✓ Traefik configuration reloaded successfully"
    else
        log_warn "⚠ Could not reload Traefik configuration"
    fi
    
    log_info "✓ ForwardAuth middleware configuration validated"
}

# Test service integrations
test_service_integrations() {
    log_step "Testing Service Integrations"
    
    load_env
    
    local authentik_url="https://${AUTHENTIK_DOMAIN}"
    
    # Test service health checks
    local services=(
        "authentik-server:9000"
        "traefik:80"
        "traefik:443"
    )
    
    local errors=0
    
    for service in "${services[@]}"; do
        local host="${service%%:*}"
        local port="${service##*:}"
        
        if check_container_health "$host"; then
            if curl -sf "http://$host:$port" -o /dev/null 2>/dev/null || \
               curl -sf "https://$host:$port" -o /dev/null 2>/dev/null; then
                log_info "✓ $host service accessible"
            else
                log_warn "⚠ $host service running but not responding"
            fi
        else
            log_error "✗ $host container not healthy"
            errors=$((errors + 1))
        fi
    done
    
    # Test Authentik endpoints
    local endpoints=(
        "$authentik_url/-/health/ready/"
        "$authentik_url/if/admin/"
        "$authentik_url/application/o/.well-known/oauth-issuer"
    )
    
    for endpoint in "${endpoints[@]}"; do
        if curl -sf "$endpoint" -o /dev/null; then
            log_info "✓ $endpoint accessible"
        else
            log_warn "⚠ $endpoint not accessible"
        fi
    done
    
    if [ $errors -eq 0 ]; then
        log_info "✓ All service integrations working"
    else
        log_error "✗ Service integration tests failed with $errors errors"
        return 1
    fi
}

# Test security configuration
test_security() {
    log_step "Testing Security Configuration"
    
    load_env
    
    local errors=0
    
    # Check Authentik security headers
    local authentik_url="https://${AUTHENTIK_DOMAIN}"
    
    local response_headers
    response_headers=$(curl -sf -I "$authentik_url" 2>/dev/null)
    
    # Check for security headers
    if echo "$response_headers" | grep -qi "strict-transport-security"; then
        log_info "✓ HSTS header present"
    else
        log_warn "⚠ HSTS header missing"
    fi
    
    if echo "$response_headers" | grep -qi "x-content-type-options"; then
        log_info "✓ X-Content-Type-Options header present"
    else
        log_warn "⚠ X-Content-Type-Options header missing"
    fi
    
    if echo "$response_headers" | grep -qi "x-frame-options"; then
        log_info "✓ X-Frame-Options header present"
    else
        log_warn "⚠ X-Frame-Options header missing"
    fi
    
    # Check environment variable security
    if [[ "$AUTHENTIK_SECRET_KEY" =~ ^[A-Za-z0-9+/]{43}={1,2}$ ]]; then
        log_info "✓ AUTHENTIK_SECRET_KEY properly formatted"
    else
        log_error "✗ AUTHENTIK_SECRET_KEY improperly formatted"
        errors=$((errors + 1))
    fi
    
    if [[ ${#AUTHENTIK_POSTGRES_PASSWORD} -ge 16 ]]; then
        log_info "✓ AUTHENTIK_POSTGRES_PASSWORD sufficiently long"
    else
        log_error "✗ AUTHENTIK_POSTGRES_PASSWORD too short"
        errors=$((errors + 1))
    fi
    
    # Check if passwords are in git history (basic check)
    cd "$ROOT_DIR"
    if git log --oneline --all --grep -i "password\|secret\|auth" | head -5; then
        log_warn "⚠ Potential sensitive information in git history"
    fi
    
    if [ $errors -eq 0 ]; then
        log_info "✓ Security validation passed"
    else
        log_error "✗ Security validation failed with $errors errors"
        return 1
    fi
}

# Check container health function
check_container_health() {
    local service_name="$1"
    
    cd "$SSO_DIR"
    if ! dcc ps -a 2>/dev/null | grep -q "$service_name"; then
        cd "$ROOT_DIR"
        return 1
    fi
    
    local health_status
    health_status=$(dcc ps -a --format "table {{.Service}}\t{{.Status}}" 2>/dev/null | grep "$service_name" | awk '{print $2}' || dcc ps -a 2>/dev/null | grep "$service_name" | awk '{print $2}')
    
    cd "$ROOT_DIR"
    
    if [[ "$health_status" == *"healthy"* ]]; then
        return 0
    else
        return 1
    fi
}

# Run comprehensive test suite
comprehensive_test() {
    log_step "Running Comprehensive SSO Test Suite"
    
    local tests=(
        "test_setup"
        "test_oidc_providers"
        "test_forwardauth"
        "test_service_integrations"
        "test_security"
    )
    
    local passed_tests=0
    local failed_tests=0
    
    for test in "${tests[@]}"; do
        echo
        if $test; then
            passed_tests=$((passed_tests + 1))
            log_info "✓ $test passed"
        else
            failed_tests=$((failed_tests + 1))
            log_error "✗ $test failed"
        fi
    done
    
    echo
    log_step "Test Summary"
    log_info "Passed: $passed_tests"
    log_info "Failed: $failed_tests"
    log_info "Total: $((passed_tests + failed_tests))"
    
    if [ $failed_tests -eq 0 ]; then
        log_step "🎉 All tests passed! SSO implementation is ready."
        return 0
    else
        log_step "❌ $failed_tests tests failed. Please review the issues above."
        return 1
    fi
}

# Main execution
case "${1:-all}" in
    "setup")
        test_setup
        ;;
    "integration")
        test_oidc_providers
        test_forwardauth
        test_service_integrations
        ;;
    "security")
        test_security
        ;;
    "all")
        comprehensive_test
        ;;
    *)
        echo "Usage: $0 [setup|integration|security|all]"
        exit 1
        ;;
esac