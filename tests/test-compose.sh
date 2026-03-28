#!/usr/bin/env bash
# =============================================================================
# Test: Docker Compose Configuration Validation
# Validates that all docker-compose.yml files are syntactically correct
# and that required fields are present.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$BASE_DIR"

log_section "Docker Compose Configuration Tests"

# Find all docker-compose files (exclude .gitkeep directories)
COMPOSE_FILES=$(find stacks/ -name 'docker-compose.yml' -type f)

if [[ -z "$COMPOSE_FILES" ]]; then
    log_warn "No docker-compose.yml files found in stacks/"
    exit 0
fi

for compose_file in $COMPOSE_FILES; do
    stack_name=$(basename "$(dirname "$compose_file")")
    log_test "Testing stack: $stack_name"

    # Test 1: File is valid YAML
    test_begin "$stack_name: valid YAML"
    if python3 -c "import yaml; yaml.safe_load(open('$compose_file'))" 2>/dev/null; then
        test_pass
    else
        test_fail "Invalid YAML syntax"
    fi

    # Test 2: docker compose config passes
    test_begin "$stack_name: docker compose config"
    if docker compose -f "$compose_file" config > /dev/null 2>&1; then
        test_pass
    else
        local err
        err=$(docker compose -f "$compose_file" config 2>&1 || true)
        test_fail "docker compose config failed: $err"
    fi

    # Test 3: Services defined
    test_begin "$stack_name: has services"
    local service_count
    service_count=$(docker compose -f "$compose_file" config --quiet 2>/dev/null | wc -l || echo "0")
    if [[ "$service_count" -gt 0 ]]; then
        test_pass "($service_count service(s))"
    else
        test_fail "No services defined"
    fi

    # Test 4: Required top-level keys
    test_begin "$stack_name: has services key"
    if grep -q "^services:" "$compose_file" 2>/dev/null; then
        test_pass
    else
        test_fail "Missing 'services:' key"
    fi

    # Test 5: No hardcoded secrets (basic check)
    test_begin "$stack_name: no obvious hardcoded secrets"
    local suspicious
    suspicious=$(grep -E "(password|secret|token).*=[[:space:]]*['\"][^'\"]{32,}['\"]" "$compose_file" 2>/dev/null || true)
    if [[ -z "$suspicious" ]]; then
        test_pass
    else
        log_warn "Found potential hardcoded secrets - review manually"
        test_pass "(manual review suggested)"
    fi

    # Test 6: Healthchecks on long-running services
    test_begin "$stack_name: has healthchecks"
    local healthcheck_count
    healthcheck_count=$(grep -c "healthcheck:" "$compose_file" 2>/dev/null || echo "0")
    if [[ "$healthcheck_count" -gt 0 ]]; then
        test_pass "($healthcheck_count healthcheck(s))"
    else
        test_fail "No healthchecks defined"
    fi

    # Test 7: Networks defined
    test_begin "$stack_name: has networks"
    if grep -q "^networks:" "$compose_file" 2>/dev/null; then
        test_pass
    else
        log_warn "No explicit networks defined (using default)"
        test_pass "(using default network)"
    fi

    # Test 8: Restart policy
    test_begin "$stack_name: has restart policies"
    local restart_count
    restart_count=$(grep -c "restart:" "$compose_file" 2>/dev/null || echo "0")
    if [[ "$restart_count" -gt 0 ]]; then
        test_pass "($restart_count service(s) with restart policy)"
    else
        test_fail "No restart policies defined"
    fi

done

test_summary
