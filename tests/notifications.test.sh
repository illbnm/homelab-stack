#!/bin/bash
#
# Test script for Notifications Stack
# Verifies all notification components are working correctly
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_DIR="$(dirname "$SCRIPT_DIR")/stacks/notifications"
NOTIFY_SCRIPT="$(dirname "$SCRIPT_DIR")/scripts/notify.sh"
CONFIG_DIR="$(dirname "$SCRIPT_DIR")/config"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

pass() {
    echo -e "${GREEN}✓ PASS${NC} $1"
    ((TESTS_PASSED++))
}

fail() {
    echo -e "${RED}✗ FAIL${NC} $1"
    ((TESTS_FAILED++))
}

warn() {
    echo -e "${YELLOW}⚠ WARN${NC} $1"
}

echo "========================================"
echo "  Notifications Stack Test Suite"
echo "========================================"
echo ""

# Test 1: Check docker-compose.yml exists
log "Test 1: Checking docker-compose.yml..."
if [ -f "$STACK_DIR/docker-compose.yml" ]; then
    pass "docker-compose.yml exists"
else
    fail "docker-compose.yml not found"
fi

# Test 2: Check README.md exists
log "Test 2: Checking README.md..."
if [ -f "$STACK_DIR/README.md" ]; then
    pass "README.md exists"
else
    fail "README.md not found"
fi

# Test 3: Check .env.example exists
log "Test 3: Checking .env.example..."
if [ -f "$STACK_DIR/.env.example" ]; then
    pass ".env.example exists"
else
    fail ".env.example not found"
fi

# Test 4: Check ntfy config exists
log "Test 4: Checking ntfy server.yml..."
if [ -f "$CONFIG_DIR/ntfy/server.yml" ]; then
    pass "ntfy server.yml exists"
else
    fail "ntfy server.yml not found"
fi

# Test 5: Check notify.sh exists and is executable
log "Test 5: Checking notify.sh..."
if [ -x "$NOTIFY_SCRIPT" ]; then
    pass "notify.sh exists and is executable"
elif [ -f "$NOTIFY_SCRIPT" ]; then
    warn "notify.sh exists but is not executable"
    chmod +x "$NOTIFY_SCRIPT"
    pass "notify.sh made executable"
else
    fail "notify.sh not found"
fi

# Test 6: Validate docker-compose.yml syntax
log "Test 6: Validating docker-compose.yml syntax..."
if command -v docker &> /dev/null; then
    cd "$STACK_DIR"
    if docker compose config > /dev/null 2>&1; then
        pass "docker-compose.yml syntax is valid"
    else
        fail "docker-compose.yml has syntax errors"
    fi
    cd - > /dev/null
else
    warn "Docker not available, skipping syntax check"
fi

# Test 7: Check services are running (if docker available)
log "Test 7: Checking service status..."
if command -v docker &> /dev/null; then
    if docker ps | grep -q ntfy; then
        pass "ntfy container is running"
    else
        warn "ntfy container is not running"
    fi
    
    if docker ps | grep -q gotify; then
        pass "Gotify container is running"
    else
        warn "Gotify container is not running"
    fi
else
    warn "Docker not available, skipping service check"
fi

# Test 8: Test notify.sh help
log "Test 8: Testing notify.sh help..."
if "$NOTIFY_SCRIPT" 2>&1 | grep -q "Usage:"; then
    pass "notify.sh help works"
else
    fail "notify.sh help not working"
fi

# Test 9: Check README completeness
log "Test 9: Checking README completeness..."
README_FILE="$STACK_DIR/README.md"
REQUIRED_SECTIONS=(
    "服务清单"
    "快速开始"
    "环境变量"
    "通知脚本"
    "服务集成"
    "Alertmanager"
    "Watchtower"
    "验收"
)

MISSING_SECTIONS=0
for section in "${REQUIRED_SECTIONS[@]}"; do
    if ! grep -q "$section" "$README_FILE" 2>/dev/null; then
        warn "README missing section: $section"
        ((MISSING_SECTIONS++))
    fi
done

if [ $MISSING_SECTIONS -eq 0 ]; then
    pass "README contains all required sections"
else
    fail "README missing $MISSING_SECTIONS required sections"
fi

# Test 10: Check docker-compose services
log "Test 10: Checking docker-compose services..."
if grep -q "ntfy:" "$STACK_DIR/docker-compose.yml" && \
   grep -q "gotify:" "$STACK_DIR/docker-compose.yml"; then
    pass "Both ntfy and Gotify services defined"
else
    fail "Missing ntfy or Gotify service definition"
fi

# Test 11: Check health checks
log "Test 11: Checking health checks..."
if grep -q "healthcheck:" "$STACK_DIR/docker-compose.yml"; then
    pass "Health checks configured"
else
    fail "Health checks not configured"
fi

# Test 12: Check Traefik labels
log "Test 12: Checking Traefik configuration..."
if grep -q "traefik.enable=true" "$STACK_DIR/docker-compose.yml"; then
    pass "Traefik labels configured"
else
    fail "Traefik labels not configured"
fi

echo ""
echo "========================================"
echo "  Test Results"
echo "========================================"
echo -e "  ${GREEN}Passed${NC}: $TESTS_PASSED"
echo -e "  ${RED}Failed${NC}: $TESTS_FAILED"
echo "========================================"

if [ $TESTS_FAILED -gt 0 ]; then
    echo ""
    echo -e "${RED}Some tests failed. Please review and fix.${NC}"
    exit 1
else
    echo ""
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi
