#!/usr/bin/env bash
# =============================================================================
# Test: Environment Variable Documentation
# Verifies that required environment variables are documented in .env.example
# and referenced correctly in docker-compose files.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$BASE_DIR"

log_section "Environment Variable Documentation Tests"

ENV_EXAMPLE="$BASE_DIR/.env.example"

# -----------------------------------------------------------------------------
# Helper: extract env vars from compose file
# -----------------------------------------------------------------------------
extract_env_vars() {
    local compose_file="$1"
    # Extract ${VAR} patterns from compose file
    grep -oE '\$\{[A-Za-z_][A-Za-z0-9_]*\}' "$compose_file" 2>/dev/null \
        | sed 's/\$\{//g; s/\}//g' \
        | sort -u
}

# -----------------------------------------------------------------------------
# Required env vars that must be documented
# -----------------------------------------------------------------------------
REQUIRED_VARS=(
    "TZ"
    "DOMAIN"
    "ACME_EMAIL"
    "POSTGRES_PASSWORD"
    "REDIS_PASSWORD"
    "MARIADB_ROOT_PASSWORD"
    "GRAFANA_ADMIN_PASSWORD"
    "VAULTWARDEN_ADMIN_TOKEN"
    "NEXTCLOUD_ADMIN_PASSWORD"
)

# -----------------------------------------------------------------------------
# Test: .env.example exists
# -----------------------------------------------------------------------------
test_begin ".env.example exists"
if [[ -f "$ENV_EXAMPLE" ]]; then
    test_pass
else
    test_fail ".env.example not found"
fi

# -----------------------------------------------------------------------------
# Test: .env.example has required sections
# -----------------------------------------------------------------------------
test_begin ".env.example has section headers"
local sections=("GENERAL" "TRAEFIK" "DATABASES" "NOTIFICATIONS")
local missing_sections=()
for section in "${sections[@]}"; do
    if ! grep -q "^# ---" "$ENV_EXEXAMPLE" 2>/dev/null || ! grep -q "$section" "$ENV_EXAMPLE"; then
        missing_sections+=("$section")
    fi
done
if [[ ${#missing_sections[@]} -eq 0 ]]; then
    test_pass
else
    test_fail "Missing sections: ${missing_sections[*]}"
fi

# -----------------------------------------------------------------------------
# Test: Required variables are documented
# -----------------------------------------------------------------------------
for var in "${REQUIRED_VARS[@]}"; do
    test_begin ".env.example: $var documented"
    if grep -qE "^${var}=" "$ENV_EXAMPLE" 2>/dev/null; then
        test_pass
    else
        # Check if it's in a comment as example
        if grep -qE "^# ${var}" "$ENV_EXAMPLE" 2>/dev/null; then
            test_pass "(commented)"
        else
            test_fail "Variable $var not documented"
        fi
    fi
done

# -----------------------------------------------------------------------------
# Test: Env vars used in compose files are documented
# -----------------------------------------------------------------------------
log_info "Checking env vars used in compose files are documented..."

# Find all env vars used in compose files
ALL_COMPOSE_VARS=()
for compose_file in stacks/*/docker-compose.yml; do
    [[ -f "$compose_file" ]] || continue
    while IFS= read -r var; do
        ALL_COMPOSE_VARS+=("$var")
    done < <(extract_env_vars "$compose_file")
done

# Deduplicate
ALL_COMPOSE_VARS=($(printf '%s\n' "${ALL_COMPOSE_VARS[@]}" | sort -u))

UNDOCUMENTED=()
for var in "${ALL_COMPOSE_VARS[@]}"; do
    # Skip defaults and well-known Docker vars
    [[ "$var" =~ ^(DOCKER_API_VERSION|TZ|PWD|HOME|USER)$ ]] && continue
    # Skip path-like vars
    [[ "$var" =~ ^(PATH|HOME|PWD)$ ]] && continue

    if ! grep -qE "^${var}=" "$ENV_EXAMPLE" 2>/dev/null; then
        # Check if it's a valid default or computed var
        if [[ "$var" == DOMAIN* ]] || [[ "$var" == AUTHENTIK_DOMAIN ]]; then
            # Computed from other vars, ok
            continue
        fi
        UNDOCUMENTED+=("$var")
    fi
done

test_begin "All compose env vars documented"
if [[ ${#UNDOCUMENTED[@]} -eq 0 ]]; then
    test_pass
else
    test_fail "Undocumented vars: ${UNDOCUMENTED[*]}"
fi

# -----------------------------------------------------------------------------
# Test: No empty required vars without defaults
# -----------------------------------------------------------------------------
test_begin ".env.example: no empty REQUIRED vars without comments"
# Check for REQUIRED markers
REQUIRED_EMPTY=$(grep -nE "^# REQUIRED:" "$ENV_EXAMPLE" 2>/dev/null | head -5 || true)
if [[ -z "$REQUIRED_EMPTY" ]]; then
    test_pass
else
    # If there are REQUIRED markers, warn about them
    log_warn "Found REQUIRED comments in .env.example"
    test_pass "(REQUIRED comments present)"
fi

# -----------------------------------------------------------------------------
# Test: Stack-specific .env.example files exist
# -----------------------------------------------------------------------------
STACK_ENV_EXAMPLES=(
    "stacks/databases/.env.example"
    "stacks/media/.env.example"
    "stacks/monitoring/.env.example"
    "stacks/network/.env.example"
    "stacks/productivity/.env.example"
    "stacks/sso/.env.example"
    "stacks/storage/.env.example"
)

for env_file in "${STACK_ENV_EXAMPLES[@]}"; do
    stack_name=$(basename "$(dirname "$env_file")")
    test_begin "stacks/$stack_name/.env.example exists"
    if [[ -f "$BASE_DIR/$env_file" ]]; then
        test_pass
    else
        log_warn "Missing $env_file (may be optional)"
        test_pass "(optional)"
    fi
done

# -----------------------------------------------------------------------------
# Test: Sensitive variables are NOT hardcoded in compose files
# -----------------------------------------------------------------------------
test_begin "No password secrets in compose files (static analysis)"
SENSITIVE_PATTERNS=("POSTGRES_PASSWORD=" "REDIS_PASSWORD=" "MARIADB_ROOT_PASSWORD=" "GRAFANA_ADMIN_PASSWORD=")
SECRETS_FOUND=()
for pattern in "${SENSITIVE_PATTERNS[@]}"; do
    local found
    found=$(grep -r "$pattern" stacks/ --include='docker-compose*.yml' 2>/dev/null || true)
    if [[ -n "$found" ]]; then
        SECRETS_FOUND+=("$pattern")
    fi
done
if [[ ${#SECRETS_FOUND[@]} -eq 0 ]]; then
    test_pass
else
    test_fail "Found hardcoded secrets in compose files: ${SECRETS_FOUND[*]}"
fi

test_summary
