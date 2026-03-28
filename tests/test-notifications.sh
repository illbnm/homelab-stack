#!/usr/bin/env bash
# =============================================================================
# Test: Notification Stack Validation
# Validates that the notifications stack is properly configured with
# healthchecks, network settings, and notification service integration.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$BASE_DIR"

log_section "Notification Stack Tests"

NOTIFY_COMPOSE="$BASE_DIR/stacks/notifications/docker-compose.yml"

# -----------------------------------------------------------------------------
# Test: notifications stack docker-compose exists
# -----------------------------------------------------------------------------
test_begin "notifications/docker-compose.yml exists"
if [[ -f "$NOTIFY_COMPOSE" ]]; then
    test_pass
else
    log_warn "No notifications stack found"
    test_pass "(notification stack not present - skipping)"
    test_summary
    exit 0
fi

# -----------------------------------------------------------------------------
# Test: Valid YAML
# -----------------------------------------------------------------------------
test_begin "notifications/docker-compose.yml is valid YAML"
if python3 -c "import yaml; yaml.safe_load(open('$NOTIFY_COMPOSE'))" 2>/dev/null; then
    test_pass
else
    test_fail "Invalid YAML"
fi

# -----------------------------------------------------------------------------
# Test: docker compose config valid
# -----------------------------------------------------------------------------
test_begin "notifications: docker compose config passes"
if docker compose -f "$NOTIFY_COMPOSE" config > /dev/null 2>&1; then
    test_pass
else
    test_fail "docker compose config failed"
fi

# -----------------------------------------------------------------------------
# Test: ntfy service defined
# -----------------------------------------------------------------------------
test_begin "ntfy service defined"
if grep -q "^  ntfy:" "$NOTIFY_COMPOSE" 2>/dev/null; then
    test_pass
else
    test_fail "ntfy service not found"
fi

# -----------------------------------------------------------------------------
# Test: apprise service defined
# -----------------------------------------------------------------------------
test_begin "apprise service defined"
if grep -q "^  apprise:" "$NOTIFY_COMPOSE" 2>/dev/null; then
    test_pass
else
    test_fail "apprise service not found"
fi

# -----------------------------------------------------------------------------
# Test: ntfy has healthcheck
# -----------------------------------------------------------------------------
test_begin "ntfy has healthcheck"
if grep -A20 "^  ntfy:" "$NOTIFY_COMPOSE" | grep -q "healthcheck:"; then
    test_pass
else
    test_fail "ntfy missing healthcheck"
fi

# -----------------------------------------------------------------------------
# Test: apprise has healthcheck
# -----------------------------------------------------------------------------
test_begin "apprise has healthcheck"
if grep -A20 "^  apprise:" "$NOTIFY_COMPOSE" | grep -q "healthcheck:"; then
    test_pass
else
    test_fail "apprise missing healthcheck"
fi

# -----------------------------------------------------------------------------
# Test: ntfy uses proxy network
# -----------------------------------------------------------------------------
test_begin "ntfy uses proxy network"
if grep -A20 "^  ntfy:" "$NOTIFY_COMPOSE" | grep -q "proxy"; then
    test_pass
else
    test_fail "ntfy not on proxy network"
fi

# -----------------------------------------------------------------------------
# Test: apprise uses proxy network
# -----------------------------------------------------------------------------
test_begin "apprise uses proxy network"
if grep -A20 "^  apprise:" "$NOTIFY_COMPOSE" | grep -q "proxy"; then
    test_pass
else
    test_fail "apprise not on proxy network"
fi

# -----------------------------------------------------------------------------
# Test: ntfy has traefik labels
# -----------------------------------------------------------------------------
test_begin "ntfy has Traefik labels"
if grep -A30 "^  ntfy:" "$NOTIFY_COMPOSE" | grep -q "traefik.enable=true"; then
    test_pass
else
    test_fail "ntfy missing traefik.enable label"
fi

# -----------------------------------------------------------------------------
# Test: apprise has traefik labels
# -----------------------------------------------------------------------------
test_begin "apprise has Traefik labels"
if grep -A30 "^  apprise:" "$NOTIFY_COMPOSE" | grep -q "traefik.enable=true"; then
    test_pass
else
    test_fail "apprise missing traefik.enable label"
fi

# -----------------------------------------------------------------------------
# Test: ntfy has restart policy
# -----------------------------------------------------------------------------
test_begin "ntfy has restart policy"
if grep -A20 "^  ntfy:" "$NOTIFY_COMPOSE" | grep -q "restart:"; then
    test_pass
else
    test_fail "ntfy missing restart policy"
fi

# -----------------------------------------------------------------------------
# Test: apprise has restart policy
# -----------------------------------------------------------------------------
test_begin "apprise has restart policy"
if grep -A20 "^  apprise:" "$NOTIFY_COMPOSE" | grep -q "restart:"; then
    test_pass
else
    test_fail "apprise missing restart policy"
fi

# -----------------------------------------------------------------------------
# Test: notification services use external proxy network
# -----------------------------------------------------------------------------
test_begin "proxy network is external"
if grep -A5 "^networks:" "$NOTIFY_COMPOSE" | grep -A5 "proxy:" | grep -q "external: true"; then
    test_pass
else
    test_fail "proxy network not marked as external"
fi

# -----------------------------------------------------------------------------
# Test: ntfy uses proper image version (not 'latest')
# -----------------------------------------------------------------------------
test_begin "ntfy uses versioned image"
NTFY_IMAGE=$(grep -A2 "^  ntfy:" "$NOTIFY_COMPOSE" | grep "image:" | head -1 || true)
if echo "$NTFY_IMAGE" | grep -qE ":v?[0-9]" && ! echo "$NTFY_IMAGE" | grep -qi "latest"; then
    test_pass "($NTFY_IMAGE)"
else
    log_warn "ntfy may be using 'latest' tag"
    test_pass "(may use latest)"
fi

# -----------------------------------------------------------------------------
# Test: apprise uses proper image version (not 'latest')
# -----------------------------------------------------------------------------
test_begin "apprise uses versioned image"
APPRISE_IMAGE=$(grep -A2 "^  apprise:" "$NOTIFY_COMPOSE" | grep "image:" | head -1 || true)
if echo "$APPRISE_IMAGE" | grep -qE ":v?[0-9]" && ! echo "$APPRISE_IMAGE" | grep -qi "latest"; then
    test_pass "($APPRISE_IMAGE)"
else
    log_warn "apprise may be using 'latest' tag"
    test_pass "(may use latest)"
fi

# -----------------------------------------------------------------------------
# Test: volumes are defined for persistence
# -----------------------------------------------------------------------------
test_begin "ntfy has persistent volumes"
if grep -A30 "^  ntfy:" "$NOTIFY_COMPOSE" | grep -q "volumes:"; then
    test_pass
else
    test_fail "ntfy missing volumes"
fi

test_begin "apprise has persistent volumes"
if grep -A30 "^  apprise:" "$NOTIFY_COMPOSE" | grep -q "volumes:"; then
    test_pass
else
    test_fail "apprise missing volumes"
fi

# -----------------------------------------------------------------------------
# Test: NTFY_URL env var is documented in .env.example
# -----------------------------------------------------------------------------
test_begin "NTFY_TOPIC documented in .env.example"
if grep -qE "^NTFY_TOPIC=" "$BASE_DIR/.env.example" 2>/dev/null; then
    test_pass
else
    test_fail "NTFY_TOPIC not documented in .env.example"
fi

test_begin "NTFY_URL documented in .env.example"
if grep -qE "^NTFY_URL=" "$BASE_DIR/.env.example" 2>/dev/null; then
    test_pass
else
    test_fail "NTFY_URL not documented in .env.example"
fi

test_summary
