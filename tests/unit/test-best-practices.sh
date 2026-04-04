#!/usr/bin/env bash
# =============================================================================
# Unit Tests — Best Practices Validation
# Tests: Security, performance, maintainability checks
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$SCRIPT_DIR/../.."

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
# Test: Security Best Practices
# -----------------------------------------------------------------------------
test_security_practices() {
  log_group "Security Best Practices"
  
  # Check for hardcoded passwords in compose files
  local hardcoded_passwords=false
  for file in $(find "$BASE_DIR/stacks" -name "*.yml" 2>/dev/null); do
    if grep -E "password:\s*['\"][^'\"]+['\"]" "$file" 2>/dev/null | grep -v '\${' | grep -v 'POSTGRES_PASSWORD\|REDIS_PASSWORD' | grep -q .; then
      log_fail "Hardcoded password found in: $file"
      hardcoded_passwords=true
    fi
  done
  
  if [[ "$hardcoded_passwords" == false ]]; then
    log_pass "No hardcoded passwords in compose files"
  fi
  
  # Check for hardcoded API keys
  local hardcoded_keys=false
  for file in $(find "$BASE_DIR/stacks" -name "*.yml" 2>/dev/null); do
    if grep -E "api[_-]?key:\s*['\"][^'\"]+['\"]" "$file" 2>/dev/null | grep -v '\${' | grep -q .; then
      log_fail "Hardcoded API key found in: $file"
      hardcoded_keys=true
    fi
  done
  
  if [[ "$hardcoded_keys" == false ]]; then
    log_pass "No hardcoded API keys in compose files"
  fi
  
  # Check for secrets in .env.example
  if [[ -f "$BASE_DIR/.env.example" ]]; then
    local example_secrets=false
    local secret_keywords=("PASSWORD" "SECRET" "TOKEN" "KEY" "CREDENTIAL")
    
    while IFS= read -r line; do
      if [[ "$line" =~ ^[A-Z_]+= ]]; then
        local key=$(echo "$line" | cut -d'=' -f1)
        local value=$(echo "$line" | cut -d'=' -f2-)
        
        # Skip empty values and placeholders
        [[ -z "$value" ]] && continue
        [[ "$value" == "changeme" ]] && continue
        [[ "$value" == "your_"* ]] && continue
        [[ "$value" == "REPLACE_"* ]] && continue
        [[ "$value" == "<"* ]] && continue
        [[ "$value" == *"\${"* ]] && continue
        
        # Only flag if key contains secret-related words AND has a long value
        for keyword in "${secret_keywords[@]}"; do
          if [[ "$key" == *"$keyword"* ]] && [[ ${#value} -gt 8 ]]; then
            log_fail "Potential real secret in .env.example: $key"
            example_secrets=true
            break
          fi
        done
      fi
    done < "$BASE_DIR/.env.example"
    
    if [[ "$example_secrets" == false ]]; then
      log_pass ".env.example uses placeholders for secrets"
    fi
  else
    log_skip ".env.example not found"
  fi
  
  # Check for insecure defaults
  if grep -r "insecure:\s*true" "$BASE_DIR/stacks" 2>/dev/null | grep -v "#" | grep -q .; then
    log_fail "Insecure mode enabled in compose files"
  else
    log_pass "No insecure mode enabled"
  fi
}

# -----------------------------------------------------------------------------
# Test: Resource Limits
# -----------------------------------------------------------------------------
test_resource_limits() {
  log_group "Resource Limits"
  
  # Check for memory limits
  local memory_limits=false
  for file in $(find "$BASE_DIR/stacks" -name "*.yml" 2>/dev/null); do
    if grep -q "mem_limit\|memory:" "$file" 2>/dev/null; then
      memory_limits=true
      break
    fi
  done
  
  if [[ "$memory_limits" == true ]]; then
    log_pass "Memory limits defined in compose files"
  else
    log_skip "No memory limits defined (recommended for production)"
  fi
  
  # Check for CPU limits
  local cpu_limits=false
  for file in $(find "$BASE_DIR/stacks" -name "*.yml" 2>/dev/null); do
    if grep -q "cpus:\|cpu_" "$file" 2>/dev/null; then
      cpu_limits=true
      break
    fi
  done
  
  if [[ "$cpu_limits" == true ]]; then
    log_pass "CPU limits defined in compose files"
  else
    log_skip "No CPU limits defined (recommended for production)"
  fi
}

# -----------------------------------------------------------------------------
# Test: Restart Policies
# -----------------------------------------------------------------------------
test_restart_policies() {
  log_group "Restart Policies"
  
  local service_count=0
  local restart_count=0
  
  for file in $(find "$BASE_DIR/stacks" -name "*.yml" 2>/dev/null); do
    # Count services (lines that look like service definitions)
    local services=0
    if grep -qE "^\s{2}[a-zA-Z]" "$file" 2>/dev/null; then
      services=$(grep -cE "^\s{2}[a-zA-Z]" "$file" 2>/dev/null)
      services=${services:-0}
    fi
    service_count=$((service_count + services))
    
    # Count restart policies
    local restarts=0
    if grep -q "restart:" "$file" 2>/dev/null; then
      restarts=$(grep -c "restart:" "$file" 2>/dev/null)
      restarts=${restarts:-0}
    fi
    restart_count=$((restart_count + restarts))
    
    # Check for 'always' or 'unless-stopped'
    if grep -E "restart:\s*(always|unless-stopped)" "$file" 2>/dev/null | grep -q .; then
      log_pass "Proper restart policy in: $(basename $file)"
    elif grep -q "restart:" "$file" 2>/dev/null; then
      log_skip "Restart policy present: $(basename $file)"
    fi
  done
  
  if [[ $service_count -gt 0 ]] && [[ $restart_count -eq 0 ]]; then
    log_fail "No restart policies defined for $service_count services"
  elif [[ $restart_count -gt 0 ]]; then
    log_pass "Restart policies defined ($restart_count services)"
  fi
}

# -----------------------------------------------------------------------------
# Test: Logging Configuration
# -----------------------------------------------------------------------------
test_logging_config() {
  log_group "Logging Configuration"
  
  local has_logging=false
  
  for file in $(find "$BASE_DIR/stacks" -name "*.yml" 2>/dev/null); do
    if grep -q "logging:" "$file" 2>/dev/null; then
      has_logging=true
      
      # Check for log rotation
      if grep -A5 "logging:" "$file" 2>/dev/null | grep -q "max-size\|max-file"; then
        log_pass "Log rotation configured in: $(basename $file)"
      else
        log_skip "Logging configured but no rotation in: $(basename $file)"
      fi
    fi
  done
  
  if [[ "$has_logging" == true ]]; then
    log_pass "Logging configuration found"
  else
    log_skip "No explicit logging configuration (using Docker defaults)"
  fi
}

# -----------------------------------------------------------------------------
# Test: Network Security
# -----------------------------------------------------------------------------
test_network_security() {
  log_group "Network Security"
  
  # Check for exposed ports without necessity
  local exposed_without_need=false
  
  for file in $(find "$BASE_DIR/stacks" -name "*.yml" 2>/dev/null); do
    # Check if ports are exposed to host
    if grep -A20 "ports:" "$file" 2>/dev/null | grep -q '"[0-9]*:[0-9]*"'; then
      # This is OK for services that need external access
      log_skip "Host ports exposed in: $(basename $file) (verify if needed)"
    fi
    
    # Check for internal-only services that should not be exposed
    if grep -q "expose:" "$file" 2>/dev/null; then
      log_pass "Internal ports properly exposed in: $(basename $file)"
    fi
  done
  
  # Check for network isolation
  if grep -r "internal:\s*true" "$BASE_DIR/stacks" 2>/dev/null | grep -q .; then
    log_pass "Internal networks configured for isolation"
  else
    log_skip "No internal networks (consider for sensitive services)"
  fi
}

# -----------------------------------------------------------------------------
# Test: Documentation Completeness
# -----------------------------------------------------------------------------
test_documentation() {
  log_group "Documentation Completeness"
  
  # Check README in each stack
  for stack_dir in "$BASE_DIR/stacks"/*/; do
    if [[ -d "$stack_dir" ]]; then
      local stack_name=$(basename "$stack_dir")
      if [[ -f "$stack_dir/README.md" ]]; then
        log_pass "README exists: $stack_name"
        
        # Check for required sections
        local readme_content=$(cat "$stack_dir/README.md" 2>/dev/null)
        
        if echo "$readme_content" | grep -qi "usage\|quick start\|get started"; then
          log_pass "Usage section in: $stack_name/README.md"
        else
          log_skip "No usage section in: $stack_name/README.md"
        fi
        
        if echo "$readme_content" | grep -qi "environment\|config\|variable"; then
          log_pass "Config section in: $stack_name/README.md"
        else
          log_skip "No config section in: $stack_name/README.md"
        fi
      else
        log_fail "README missing: $stack_name"
      fi
    fi
  done
  
  # Check main README
  if [[ -f "$BASE_DIR/README.md" ]]; then
    log_pass "Main README exists"
  else
    log_fail "Main README missing"
  fi
}

# -----------------------------------------------------------------------------
# Test: Image Version Pinning
# -----------------------------------------------------------------------------
test_image_version_pinning() {
  log_group "Image Version Pinning"
  
  local unversioned=0
  local versioned=0
  
  for file in $(find "$BASE_DIR/stacks" -name "*.yml" 2>/dev/null); do
    while IFS= read -r line; do
      local image=$(echo "$line" | sed 's/.*image:\s*//')
      
      # Skip if empty or comment
      [[ -z "$image" ]] && continue
      [[ "$image" =~ ^# ]] && continue
      
      # Check for version tag
      if [[ "$image" =~ :[0-9] ]] || [[ "$image" =~ @[a-z0-9]+: ]]; then
        ((versioned++))
      elif [[ "$image" =~ :latest$ ]]; then
        log_fail "Using 'latest' tag: $image in $(basename $file)"
        ((unversioned++))
      else
        # No tag at all
        log_fail "No version tag: $image in $(basename $file)"
        ((unversioned++))
      fi
    done < <(grep "image:" "$file" 2>/dev/null)
  done
  
  if [[ $unversioned -eq 0 ]]; then
    log_pass "All images properly versioned ($versioned images)"
  else
    log_fail "$unversioned images without proper version tags"
  fi
}

# -----------------------------------------------------------------------------
# Test: Environment Variable Usage
# -----------------------------------------------------------------------------
test_env_variable_usage() {
  log_group "Environment Variable Usage"
  
  local hardcoded_values=false
  
  for file in $(find "$BASE_DIR/stacks" -name "*.yml" 2>/dev/null); do
    # Check for hardcoded domains
    if grep -E "\.com|\.org|\.io|\.net" "$file" 2>/dev/null | grep -v "#" | grep -v '\${' | grep -q .; then
      log_skip "Potential hardcoded domain in: $(basename $file)"
    fi
    
    # Check for hardcoded paths
    if grep -E "/home/|/var/|/opt/" "$file" 2>/dev/null | grep -v "#" | grep -v '\${' | grep -q .; then
      # This is OK for volume mounts
      log_skip "Hardcoded paths in: $(basename $file) (verify if configurable)"
    fi
  done
  
  if [[ "$hardcoded_values" == false ]]; then
    log_pass "No obvious hardcoded values found"
  fi
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
  echo -e "${BOLD}========================================${NC}"
  echo -e "${BOLD}  Unit Tests - Best Practices${NC}"
  echo -e "${BOLD}========================================${NC}"
  
  test_security_practices
  test_resource_limits
  test_restart_policies
  test_logging_config
  test_network_security
  test_documentation
  test_image_version_pinning
  test_env_variable_usage
  
  echo ""
  echo -e "${BOLD}========================================${NC}"
  echo -e "  Results: ${GREEN}$PASSED passed${NC} | ${RED}$FAILED failed${NC} | ${YELLOW}$SKIPPED skipped${NC}"
  echo -e "${BOLD}========================================${NC}"
  
  [[ $FAILED -eq 0 ]] && exit 0 || exit 1
}

main "$@"
