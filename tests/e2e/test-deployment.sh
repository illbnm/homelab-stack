#!/usr/bin/env bash
# =============================================================================
# End-to-End Tests — Full Deployment Workflow
# Tests: Fresh install, stack deployment, service verification, cleanup
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$SCRIPT_DIR/../.."
ENV_FILE="$BASE_DIR/.env"
ENV_EXAMPLE="$BASE_DIR/.env.example"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

PASSED=0
FAILED=0
SKIPPED=0

log_pass()  { echo -e "  ${GREEN}✓${NC} $*"; ((PASSED++)); }
log_fail()  { echo -e "  ${RED}✗${NC} $*"; ((FAILED++)); }
log_skip()  { echo -e "  ${YELLOW}~${NC} $* (skipped)"; ((SKIPPED++)); }
log_group() { echo -e "\n${BLUE}${BOLD}[$*]${NC}"; }

# -----------------------------------------------------------------------------
# E2E Test: Environment Setup
# -----------------------------------------------------------------------------
test_environment_setup() {
  log_group "E2E: Environment Setup"
  
  # Check .env.example exists
  if [[ -f "$ENV_EXAMPLE" ]]; then
    log_pass ".env.example exists"
  else
    log_fail ".env.example not found"
    return 1
  fi
  
  # Create test .env if not exists
  if [[ ! -f "$ENV_FILE" ]]; then
    cp "$ENV_EXAMPLE" "$ENV_FILE"
    log_pass "Created .env from .env.example"
  else
    log_skip ".env already exists"
  fi
  
  # Validate required environment variables
  local required_vars=("DOMAIN" "TZ" "TRAEFIK_DASHBOARD_USERNAME" "TRAEFIK_DASHBOARD_PASSWORD")
  local missing=0
  
  for var in "${required_vars[@]}"; do
    if ! grep -q "^${var}=" "$ENV_FILE" 2>/dev/null; then
      log_fail "Missing required var: $var"
      ((missing++))
    fi
  done
  
  if [[ $missing -eq 0 ]]; then
    log_pass "All required environment variables present"
  fi
}

# -----------------------------------------------------------------------------
# E2E Test: Pre-flight Checks
# -----------------------------------------------------------------------------
test_preflight_checks() {
  log_group "E2E: Pre-flight Checks"
  
  # Check Docker
  if command -v docker &>/dev/null; then
    log_pass "Docker installed: $(docker --version)"
  else
    log_fail "Docker not installed"
    return 1
  fi
  
  # Check Docker Compose
  if command -v docker compose &>/dev/null; then
    log_pass "Docker Compose installed: $(docker compose version)"
  else
    log_fail "Docker Compose not installed"
    return 1
  fi
  
  # Check Docker daemon
  if docker ps &>/dev/null; then
    log_pass "Docker daemon running"
  else
    log_fail "Docker daemon not running or no permission"
    return 1
  fi
  
  # Check required ports
  local required_ports=(80 443)
  for port in "${required_ports[@]}"; do
    if ! ss -tuln 2>/dev/null | grep -q ":${port} " && ! netstat -tuln 2>/dev/null | grep -q ":${port} "; then
      log_pass "Port $port is available"
    else
      log_skip "Port $port may be in use"
    fi
  done
}

# -----------------------------------------------------------------------------
# E2E Test: Network Creation
# -----------------------------------------------------------------------------
test_network_creation() {
  log_group "E2E: Network Creation"
  
  # Create proxy network if not exists
  if ! docker network ls --format '{{.Name}}' | grep -q "^proxy$"; then
    if docker network create proxy 2>/dev/null; then
      log_pass "Created 'proxy' network"
    else
      log_fail "Failed to create 'proxy' network"
      return 1
    fi
  else
    log_skip "'proxy' network already exists"
  fi
  
  # Verify network
  if docker network inspect proxy &>/dev/null; then
    log_pass "'proxy' network inspectable"
  else
    log_fail "'proxy' network inspection failed"
  fi
}

# -----------------------------------------------------------------------------
# E2E Test: Base Stack Deployment
# -----------------------------------------------------------------------------
test_base_stack_deployment() {
  log_group "E2E: Base Stack Deployment"
  
  local compose_file="$BASE_DIR/stacks/base/docker-compose.yml"
  
  if [[ ! -f "$compose_file" ]]; then
    log_fail "docker-compose.yml not found"
    return 1
  fi
  
  # Validate compose file
  if docker compose -f "$compose_file" config --quiet 2>/dev/null; then
    log_pass "Compose file validation passed"
  else
    log_fail "Compose file validation failed"
    return 1
  fi
  
  # Pull images
  log_group "Pulling images..."
  if docker compose -f "$compose_file" pull 2>/dev/null; then
    log_pass "Images pulled successfully"
  else
    log_skip "Image pull failed (may be offline)"
  fi
  
  # Deploy services
  log_group "Deploying services..."
  if docker compose -f "$compose_file" up -d 2>/dev/null; then
    log_pass "Services deployed successfully"
  else
    log_fail "Service deployment failed"
    return 1
  fi
  
  # Wait for services to start
  log_group "Waiting for services to start (30s)..."
  sleep 30
  
  # Verify services are running
  local services=("traefik" "portainer" "watchtower")
  for service in "${services[@]}"; do
    if docker ps --format '{{.Names}}' | grep -q "^${service}$"; then
      log_pass "Service '$service' is running"
    else
      log_fail "Service '$service' not running"
    fi
  done
}

# -----------------------------------------------------------------------------
# E2E Test: Health Check Verification
# -----------------------------------------------------------------------------
test_health_verification() {
  log_group "E2E: Health Check Verification"
  
  # Wait for health checks
  sleep 10
  
  # Check Traefik health
  local traefik_health
  traefik_health=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' traefik 2>/dev/null || echo "not-found")
  
  if [[ "$traefik_health" == "healthy" ]] || [[ "$traefik_health" == "no-healthcheck" ]]; then
    log_pass "Traefik health: $traefik_health"
  else
    log_fail "Traefik health: $traefik_health"
  fi
  
  # Check Portainer health
  local portainer_health
  portainer_health=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' portainer 2>/dev/null || echo "not-found")
  
  if [[ "$portainer_health" == "healthy" ]] || [[ "$portainer_health" == "no-healthcheck" ]]; then
    log_pass "Portainer health: $portainer_health"
  else
    log_fail "Portainer health: $portainer_health"
  fi
  
  # Check HTTP endpoints
  sleep 5
  
  if curl -sf -o /dev/null -w '%{http_code}' --connect-timeout 5 http://localhost:80 2>/dev/null | grep -qE "^[23]"; then
    log_pass "Traefik HTTP endpoint responding"
  else
    log_skip "Traefik HTTP endpoint not responding"
  fi
}

# -----------------------------------------------------------------------------
# E2E Test: Log Verification
# -----------------------------------------------------------------------------
test_log_verification() {
  log_group "E2E: Log Verification"
  
  # Check Traefik logs
  local traefik_logs
  traefik_logs=$(docker logs traefik --tail 10 2>/dev/null || echo "")
  
  if [[ -n "$traefik_logs" ]]; then
    log_pass "Traefik logs accessible ($(echo "$traefik_logs" | wc -l) lines)"
  else
    log_skip "Traefik logs empty"
  fi
  
  # Check for errors in logs
  if docker logs traefik 2>/dev/null | grep -qi "error\|fatal\|panic"; then
    log_fail "Errors found in Traefik logs"
  else
    log_pass "No critical errors in Traefik logs"
  fi
}

# -----------------------------------------------------------------------------
# E2E Test: Configuration Persistence
# -----------------------------------------------------------------------------
test_config_persistence() {
  log_group "E2E: Configuration Persistence"
  
  # Check volume mounts
  local volumes=("portainer-data" "traefik-logs")
  
  for volume in "${volumes[@]}"; do
    if docker volume ls --format '{{.Name}}' | grep -q "${volume}"; then
      log_pass "Volume '$volume' exists"
    else
      log_skip "Volume '$volume' not found"
    fi
  done
  
  # Check config files
  local config_files=(
    "config/traefik/traefik.yml"
    "config/traefik/acme.json"
  )
  
  for file in "${config_files[@]}"; do
    if [[ -f "$BASE_DIR/$file" ]]; then
      log_pass "Config file exists: $file"
    else
      log_skip "Config file not found: $file"
    fi
  done
}

# -----------------------------------------------------------------------------
# E2E Test: Cleanup
# -----------------------------------------------------------------------------
test_cleanup() {
  log_group "E2E: Cleanup"
  
  # Stop services
  local compose_file="$BASE_DIR/stacks/base/docker-compose.yml"
  
  if docker compose -f "$compose_file" down 2>/dev/null; then
    log_pass "Services stopped successfully"
  else
    log_skip "Service stop failed (may already be stopped)"
  fi
  
  # Note: We don't remove volumes or network to preserve data
  log_skip "Volumes and network preserved for future runs"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
  echo -e "${BOLD}========================================${NC}"
  echo -e "${BOLD}  E2E Tests - Full Deployment Workflow${NC}"
  echo -e "${BOLD}========================================${NC}"
  echo ""
  
  test_environment_setup
  test_preflight_checks
  test_network_creation
  test_base_stack_deployment
  test_health_verification
  test_log_verification
  test_config_persistence
  # test_cleanup  # Uncomment to auto-cleanup after tests
  
  echo ""
  echo -e "${BOLD}========================================${NC}"
  echo -e "  Results: ${GREEN}$PASSED passed${NC} | ${RED}$FAILED failed${NC} | ${YELLOW}$SKIPPED skipped${NC}"
  echo -e "${BOLD}========================================${NC}"
  
  [[ $FAILED -eq 0 ]] && exit 0 || exit 1
}

main "$@"
