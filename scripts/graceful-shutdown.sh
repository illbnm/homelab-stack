#!/usr/bin/env bash
# =============================================================================
# graceful-shutdown.sh — Stop all stacks in correct order
# Waits up to 10s for containers to exit gracefully
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()  { echo -e "${BLUE}[STOP]${NC} $*"; }
ok()    { echo -e "${GREEN}[ OK ]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TIMEOUT=10

# --- Shutdown order: app stacks first, base last ---
STACKS_ORDER=(
    "stacks/ai"
    "stacks/media"
    "stacks/home-automation"
    "stacks/monitoring"
    "stacks/sso"
    "stacks/databases"
    "stacks/network"
    "stacks/productivity"
    "stacks/storage"
    "stacks/dashboard"
    "stacks/notifications"
    "stacks/base"
)

for stack_dir in "${STACKS_ORDER[@]}"; do
    compose_file="$PROJECT_DIR/$stack_dir/docker-compose.yml"
    [[ -f "$compose_file" ]] || continue

    name="$(basename "$stack_dir")"
    info "Stopping stack: $name"

    # Get running containers for this stack
    containers=$(docker compose -f "$compose_file" ps --services --filter "status=running" 2>/dev/null || true)
    if [[ -z "$containers" ]]; then
        ok "$name — already stopped"
        continue
    fi

    # Graceful stop
    docker compose -f "$compose_file" stop --timeout "$TIMEOUT" 2>/dev/null || true
    ok "$name — stopped"
done

# Final check: any remaining containers?
REMAINING=$(docker ps --format '{{.Names}}' 2>/dev/null | wc -l)
if [[ "$REMAINING" -gt 0 ]]; then
    warn "$REMAINING containers still running (not managed by stacks)"
else
    ok "All stacks shut down gracefully"
fi
