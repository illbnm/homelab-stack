#!/usr/bin/env bash
# =============================================================================
# Validate All Docker Compose Stacks
# Part of: stacks/testing
#
# Runs `docker compose config --quiet` on every docker-compose.yml found
# in the stacks/ directory. A successful (silent) run means the file is
# syntactically valid and all environment variables are resolved.
#
# Usage: ./validate-stacks.sh
# Output: Human-readable summary to stdout and /results/validate-stacks.log
# Exit:  0 = all valid, 1 = one or more failed
# =============================================================================

set -euo pipefail

STACKS_DIR="${STACKS_ROOT:-/stacks}/stacks"
RESULTS_DIR="/results"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Ensure results directory exists
mkdir -p "$RESULTS_DIR"

LOG_FILE="$RESULTS_DIR/validate-stacks.log"
exec > >(tee -a "$LOG_FILE")
exec 2>&1

PASS=0
FAIL=0
FAILED_STACKS=""

echo "=========================================="
echo " Docker Compose Stack Validation"
echo " Time: $TIMESTAMP"
echo " Stacks dir: $STACKS_DIR"
echo "=========================================="
echo ""

# Find all docker-compose.yml files in stacks/
if [ ! -d "$STACKS_DIR" ]; then
    echo "[ERROR] Stacks directory not found: $STACKS_DIR"
    echo "Make sure STACKS_PATH in .env points to your homelab-stack repo root."
    exit 1
fi

mapfile -t COMPOSE_FILES < <(find "$STACKS_DIR" -name "docker-compose.yml" -not -path "*/.*" 2>/dev/null | sort)

if [ ${#COMPOSE_FILES[@]} -eq 0 ]; then
    echo "[WARN] No docker-compose.yml files found in $STACKS_DIR"
    exit 0
fi

echo "Found ${#COMPOSE_FILES[@]} stack(s) to validate."
echo ""

for compose_file in "${COMPOSE_FILES[@]}"; do
    stack_name=$(echo "$compose_file" | sed "s|$STACKS_DIR/||" | sed 's|/docker-compose.yml||')

    echo -n "Validating $stack_name ... "

    # Run docker compose config --quiet
    # --quiet suppresses output; non-zero exit = validation error
    if docker compose -f "$compose_file" config --quiet 2>&1; then
        echo "✓ OK"
        ((PASS++)) || true
    else
        echo "✗ FAILED"
        echo "--- Error details ---"
        docker compose -f "$compose_file" config 2>&1 | head -20
        echo "---------------------"
        ((FAIL++)) || true
        FAILED_STACKS="$FAILED_STACKS\n  - $stack_name ($compose_file)"
    fi
done

echo ""
echo "=========================================="
echo " Summary: $PASS passed, $FAIL failed"
echo "=========================================="

if [ "$FAIL" -gt 0 ]; then
    echo -e "Failed stacks:$FAILED_STACKS"
    echo "Full log: $LOG_FILE"
    exit 1
else
    echo "All stacks validated successfully."
    exit 0
fi
