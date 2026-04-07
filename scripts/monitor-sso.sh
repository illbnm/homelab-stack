#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — SSO Health Monitoring Script
# Monitors Authentik and related services, alerts on issues
# Usage: ./monitor-sso.sh [check|status|alert]
# =============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")
SSO_DIR="$ROOT_DIR/stacks/sso"

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
    # Source Docker Compose wrapper first
    source "$SCRIPT_DIR/docker-compose-wrapper.sh" || exit 1
    
    if [ -f "$ROOT_DIR/.env" ]; then
        set -a; source "$ROOT_DIR/.env"; set +a
    fi
    if [ -f "$SSO_DIR/.env" ]; then
        set -a; source "$SSO_DIR/.env"; set +a
    fi
}

# Check service health
check_service_health() {
    local service_name="$1"
    local service_url="$2"
    local expected_status="${3:-200}"
    
    if curl -sf -o /dev/null -w "%{http_code}" "$service_url" | grep -q "$expected_status"; then
        return 0
    else
        return 1
    fi
}

# Check container health
check_container_health() {
    local service_name="$1"
    
    if ! docker compose -f "$SSO_DIR/docker-compose.yml" ps -a | grep -q "$service_name"; then
        return 1
    fi
    
    local health_status
    health_status=$(docker compose -f "$SSO_DIR/docker-compose.yml" ps -a --format "table {{.Service}}\t{{.Status}}" | grep "$service_name" | awk '{print $2}')
    
    if [[ "$health_status" == *"healthy"* ]]; then
        return 0
    else
        return 1
    fi
}

# Main health check
health_check() {
    log_step "Performing SSO Health Check"
    
    local overall_status=0
    
    # Load environment
    load_env
    
    # Check base stack first
    if ! dcc network ls 2>/dev/null | grep -q "proxy"; then
        log_error "Base stack network not available"
        overall_status=1
    fi
    
    # Check Authentik API health
    if [ -n "${AUTHENTIK_DOMAIN:-}" ]; then
        local authentik_url="https://${AUTHENTIK_DOMAIN}"
        
        if check_service_health "authentik-api" "$authentik_url/-/health/ready/"; then
            log_info "✓ Authentik API healthy"
        else
            log_error "✗ Authentik API unhealthy"
            overall_status=1
        fi
        
        # Check admin UI
        if check_service_health "authentik-ui" "$authentik_url/if/admin/"; then
            log_info "✓ Authentik UI accessible"
        else
            log_warn "⚠ Authentik UI not accessible"
        fi
    else
        log_error "AUTHENTIK_DOMAIN not configured"
        overall_status=1
    fi
    
    # Check container health
    cd "$SSO_DIR"
    
    local containers=("postgresql" "redis" "authentik-server" "authentik-worker")
    
    for container in "${containers[@]}"; do
        if check_container_health "$container"; then
            log_info "✓ $container container healthy"
        else
            log_error "✗ $container container unhealthy"
            overall_status=1
        fi
    done
    
    # Check database connections
    if check_container_health "postgresql"; then
        if docker exec authentik-postgres pg_isready -U authentik -d authentik >/dev/null 2>&1; then
            log_info "✓ PostgreSQL database connection healthy"
        else
            log_error "✗ PostgreSQL database connection failed"
            overall_status=1
        fi
    fi
    
    if check_container_health "redis"; then
        if docker exec authentik-redis redis-cli -a "${AUTHENTIK_REDIS_PASSWORD:-}" ping >/dev/null 2>&1; then
            log_info "✓ Redis connection healthy"
        else
            log_error "✗ Redis connection failed"
            overall_status=1
        fi
    fi
    
    cd "$ROOT_DIR"
    
    if [ $overall_status -eq 0 ]; then
        log_step "🎉 All SSO services healthy!"
    else
        log_step "❌ Some SSO services have issues"
    fi
    
    return $overall_status
}

# Get detailed status
status_report() {
    log_step "SSO Status Report"
    
    load_env
    
    cd "$SSO_DIR"
    
    echo "Container Status:"
    docker compose ps
    
    echo
    echo "Resource Usage:"
    docker stats authentik-server authentik-postgres authentik-redis --no-stream
    
    cd "$ROOT_DIR"
}

# Send alert (placeholder for integration with notification systems)
send_alert() {
    local message="$1"
    
    # This could be integrated with:
    # - Gotify notifications
    # - Email alerts
    # - Slack/webhook alerts
    # - File-based alerts for monitoring systems
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') SSO ALERT: $message" >> "$SSO_DIR/alerts.log"
    
    log_error "ALERT: $message"
}

# Main execution
case "${1:-check}" in
    "check")
        health_check
        ;;
    "status")
        status_report
        ;;
    "alert")
        send_alert "${2:-Unknown alert}"
        ;;
    *)
        echo "Usage: $0 [check|status|alert]"
        exit 1
        ;;
esac