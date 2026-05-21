#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Docker Compose Syntax & Config Validation
# Validates all stack compose files without starting containers
# Usage: ./scripts/test-compose.sh [--fix]
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$SCRIPT_DIR/.."
STACKS_DIR="$BASE_DIR/stacks"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASSED=0; FAILED=0; WARNINGS=0

pass() { echo -e "  ${GREEN}PASS${NC} $1"; ((PASSED++)); }
fail() { echo -e "  ${RED}FAIL${NC} $1"; ((FAILED++)); }
warn() { echo -e "  ${YELLOW}WARN${NC} $1"; ((WARNINGS++)); }

# Check docker compose is available
if ! command -v docker &>/dev/null; then
    echo "docker not found — skipping compose validation"
    echo "Install Docker to run full validation"
    exit 0
fi

echo "============================================"
echo "  HomeLab Stack — Compose Validation"
echo "============================================"

# 1. Syntax validation for all compose files
echo ""
echo "[1] Docker Compose syntax validation"
for compose in "$STACKS_DIR"/*/docker-compose*.yml; do
    stack=$(basename "$(dirname "$compose")")
    if docker compose -f "$compose" config --quiet 2>/dev/null; then
        pass "$stack: valid syntax"
    else
        # Try with env subst fallback
        if DOMAIN=test.example.com TZ=UTC \
           docker compose -f "$compose" config >/dev/null 2>&1; then
            pass "$stack: valid syntax (with env defaults)"
        else
            fail "$stack: invalid syntax — $(docker compose -f "$compose" config 2>&1 | head -1)"
        fi
    fi
done

# 2. Image tag pinning check (no :latest)
echo ""
echo "[2] Image tag pinning (no ':latest')"
for compose in "$STACKS_DIR"/*/docker-compose*.yml; do
    stack=$(basename "$(dirname "$compose")")
    latest_count=$(grep -c 'image:.*:latest' "$compose" 2>/dev/null || true)
    if [[ $latest_count -eq 0 ]]; then
        pass "$stack: all images pinned"
    else
        fail "$stack: $latest_count image(s) using ':latest' tag"
    fi
done

# 3. Network validation
echo ""
echo "[3] Network configuration"
for compose in "$STACKS_DIR"/*/docker-compose*.yml; do
    stack=$(basename "$(dirname "$compose")")
    if grep -q 'external: true' "$compose" 2>/dev/null; then
        # Check proxy network is referenced
        if grep -q 'proxy' "$compose"; then
            pass "$stack: proxy network configured"
        else
            warn "$stack: external network but no proxy reference"
        fi
    fi
done

# 4. Health check presence
echo ""
echo "[4] Health check coverage"
for compose in "$STACKS_DIR"/*/docker-compose*.yml; do
    stack=$(basename "$(dirname "$compose")")
    total=$(grep -c 'image:' "$compose" 2>/dev/null || true)
    health=$(grep -c 'healthcheck:' "$compose" 2>/dev/null || true)
    if [[ $total -gt 0 ]] && [[ $health -ge $total ]]; then
        pass "$stack: $health/$total services have health checks"
    elif [[ $total -gt 0 ]] && [[ $health -gt 0 ]]; then
        warn "$stack: $health/$total services have health checks"
    elif [[ $total -gt 0 ]]; then
        fail "$stack: 0/$total services have health checks"
    fi
done

# 5. Environment variable references
echo ""
echo "[5] Required env var references"
for compose in "$STACKS_DIR"/*/docker-compose*.yml; do
    stack=$(basename "$(dirname "$compose")")
    # Check DOMAIN is referenced (needed for Traefik labels)
    if grep -q '\${DOMAIN' "$compose" 2>/dev/null; then
        pass "$stack: uses DOMAIN variable"
    fi
    # Check for TZ
    if grep -q '\${TZ' "$compose" 2>/dev/null; then
        pass "$stack: uses TZ variable"
    fi
done

# 6. .env.example existence
echo ""
echo "[6] .env.example files"
for stack_dir in "$STACKS_DIR"/*/; do
    stack=$(basename "$stack_dir")
    if [[ -f "$stack_dir/.env.example" ]]; then
        pass "$stack: .env.example exists"
    else
        warn "$stack: no .env.example"
    fi
done

# 7. README existence
echo ""
echo "[7] Documentation"
for stack_dir in "$STACKS_DIR"/*/; do
    stack=$(basename "$stack_dir")
    if [[ -f "$stack_dir/README.md" ]]; then
        pass "$stack: README.md exists"
    else
        warn "$stack: no README.md"
    fi
done

# Summary
echo ""
echo "============================================"
echo "  Results: $PASSED passed, $FAILED failed, $WARNINGS warnings"
echo "============================================"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
exit 0
