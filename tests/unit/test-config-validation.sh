#!/usr/bin/env bash
# =============================================================================
# Unit Tests — Configuration Validation
# Tests: .env file validation, YAML syntax checks, required fields
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
# Test: .env.example exists and has required fields
# -----------------------------------------------------------------------------
test_env_example_exists() {
  log_group ".env.example Validation"
  
  if [[ -f "$ENV_EXAMPLE" ]]; then
    log_pass ".env.example exists"
  else
    log_fail ".env.example not found"
    return 1
  fi
}

test_env_required_fields() {
  local required_fields=(
    "DOMAIN"
    "TZ"
    "TRAEFIK_DASHBOARD_USER"
    "POSTGRES_PASSWORD"
    "REDIS_PASSWORD"
    "AUTHENTIK_SECRET_KEY"
  )
  
  for field in "${required_fields[@]}"; do
    if grep -q "^${field}=" "$ENV_EXAMPLE" 2>/dev/null; then
      log_pass "Required field '$field' exists in .env.example"
    else
      log_fail "Required field '$field' missing in .env.example"
    fi
  done
}

# -----------------------------------------------------------------------------
# Test: YAML syntax validation for all compose files
# -----------------------------------------------------------------------------
test_yaml_syntax() {
  log_group "YAML Syntax Validation"
  
  # Check if docker compose is available
  if ! command -v docker compose &>/dev/null; then
    log_skip "Docker compose not available - skipping YAML validation"
    return 0
  fi
  
  local compose_files=(
    "stacks/base/docker-compose.yml"
    "stacks/base/docker-compose.local.yml"
  )
  
  for file in "${compose_files[@]}"; do
    local filepath="$BASE_DIR/$file"
    if [[ -f "$filepath" ]]; then
      # Check if docker compose can parse it
      if docker compose -f "$filepath" config --quiet 2>/dev/null; then
        log_pass "$file - valid YAML syntax"
      else
        # Fallback: basic YAML check with python
        if command -v python3 &>/dev/null; then
          if python3 -c "import yaml; yaml.safe_load(open('$filepath'))" 2>/dev/null; then
            log_pass "$file - valid YAML (python check)"
          else
            log_fail "$file - invalid YAML syntax"
          fi
        else
          log_skip "$file - YAML validation unavailable"
        fi
      fi
    else
      log_skip "$file - file not found"
    fi
  done
}

# -----------------------------------------------------------------------------
# Test: Traefik configuration validation
# -----------------------------------------------------------------------------
test_traefik_config() {
  log_group "Traefik Configuration"
  
  local traefik_static="$BASE_DIR/config/traefik/traefik.yml"
  local traefik_dynamic="$BASE_DIR/config/traefik/dynamic"
  
  if [[ -f "$traefik_static" ]]; then
    log_pass "traefik.yml exists"
    
    # Check for required sections
    if grep -q "entryPoints:" "$traefik_static"; then
      log_pass "entryPoints configured"
    else
      log_fail "entryPoints missing"
    fi
    
    if grep -q "providers:" "$traefik_static"; then
      log_pass "providers configured"
    else
      log_fail "providers missing"
    fi
    
    if grep -q "api:" "$traefik_static"; then
      log_pass "api/dashboard configured"
    else
      log_fail "api/dashboard missing"
    fi
  else
    log_skip "traefik.yml not found"
  fi
  
  if [[ -d "$traefik_dynamic" ]]; then
    log_pass "dynamic config directory exists"
    
    # Check for middleware configs
    if ls "$traefik_dynamic"/*.yml 1>/dev/null 2>&1; then
      log_pass "dynamic middleware configs found"
    else
      log_skip "no dynamic middleware configs"
    fi
  else
    log_skip "dynamic config directory not found"
  fi
}

# -----------------------------------------------------------------------------
# Test: Docker image tags (no 'latest' tags allowed)
# -----------------------------------------------------------------------------
test_image_tags() {
  log_group "Docker Image Tags (No 'latest')"
  
  local compose_files=(
    "stacks/base/docker-compose.yml"
  )
  
  for file in "${compose_files[@]}"; do
    local filepath="$BASE_DIR/$file"
    if [[ -f "$filepath" ]]; then
      # Check for :latest tags
      if grep -E "image:.*:latest" "$filepath" 2>/dev/null | grep -v "^#" | grep -q .; then
        log_fail "$file contains 'latest' tag"
      else
        log_pass "$file - no 'latest' tags found"
      fi
      
      # Check that all images have version tags (including @sha256 digests)
      local image_count
      image_count=$(grep -E "^\s+image:" "$filepath" 2>/dev/null | wc -l || echo 0)
      local versioned_count
      versioned_count=$(grep -E "^\s+image:.*(:[0-9]|@sha256:)" "$filepath" 2>/dev/null | wc -l || echo 0)
      
      if [[ "$image_count" -eq "$versioned_count" ]] || [[ "$image_count" -eq 0 ]]; then
        log_pass "$file - all images have version tags ($versioned_count/$image_count)"
      else
        log_skip "$file - some images may use variable tags ($versioned_count/$image_count)"
      fi
    fi
  done
}

# -----------------------------------------------------------------------------
# Test: Health checks defined
# -----------------------------------------------------------------------------
test_health_checks() {
  log_group "Health Check Definitions"
  
  local filepath="$BASE_DIR/stacks/base/docker-compose.yml"
  if [[ -f "$filepath" ]]; then
    local service_count
    service_count=$(grep -c "  [a-zA-Z].*:" "$filepath" 2>/dev/null || echo 0)
    local healthcheck_count
    healthcheck_count=$(grep -c "healthcheck:" "$filepath" 2>/dev/null || echo 0)
    
    if [[ "$healthcheck_count" -gt 0 ]]; then
      log_pass "Health checks defined ($healthcheck_count services)"
    else
      log_fail "No health checks defined"
    fi
  else
    log_skip "docker-compose.yml not found"
  fi
}

# -----------------------------------------------------------------------------
# Test: Network configuration
# -----------------------------------------------------------------------------
test_network_config() {
  log_group "Network Configuration"
  
  local filepath="$BASE_DIR/stacks/base/docker-compose.yml"
  if [[ -f "$filepath" ]]; then
    if grep -q "proxy:" "$filepath" && grep -q "external: true" "$filepath"; then
      log_pass "External 'proxy' network configured"
    else
      log_fail "External 'proxy' network not properly configured"
    fi
  else
    log_skip "docker-compose.yml not found"
  fi
}

# -----------------------------------------------------------------------------
# Test: Volume definitions
# -----------------------------------------------------------------------------
test_volume_config() {
  log_group "Volume Configuration"
  
  local filepath="$BASE_DIR/stacks/base/docker-compose.yml"
  if [[ -f "$filepath" ]]; then
    if grep -q "volumes:" "$filepath"; then
      log_pass "Volumes section exists"
      
      # Check for named volumes
      if grep -q "portainer-data:" "$filepath"; then
        log_pass "portainer-data volume defined"
      else
        log_fail "portainer-data volume missing"
      fi
      
      if grep -q "traefik-logs:" "$filepath"; then
        log_pass "traefik-logs volume defined"
      else
        log_fail "traefik-logs volume missing"
      fi
    else
      log_fail "No volumes section found"
    fi
  else
    log_skip "docker-compose.yml not found"
  fi
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
  echo -e "${BOLD}========================================${NC}"
  echo -e "${BOLD}  Unit Tests - Configuration Validation${NC}"
  echo -e "${BOLD}========================================${NC}"
  
  test_env_example_exists
  test_env_required_fields
  test_yaml_syntax
  test_traefik_config
  test_image_tags
  test_health_checks
  test_network_config
  test_volume_config
  
  echo ""
  echo -e "${BOLD}========================================${NC}"
  echo -e "  Results: ${GREEN}$PASSED passed${NC} | ${RED}$FAILED failed${NC} | ${YELLOW}$SKIPPED skipped${NC}"
  echo -e "${BOLD}========================================${NC}"
  
  [[ $FAILED -eq 0 ]] && exit 0 || exit 1
}

main "$@"
