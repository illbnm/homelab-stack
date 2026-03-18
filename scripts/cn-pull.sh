#!/usr/bin/env bash
# =============================================================================
# cn-pull.sh — Pull images via CN mirror registry
# Replaces ghcr.io/gcr.io/quay.io with m.daocloud.io/* equivalents
# Usage: ./cn-pull.sh [--dry-run] [--stack <name>] [--all]
# =============================================================================
set -euo pipefail

DRY_RUN=false
TARGET=""
ALL=false
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --stack)   shift; TARGET="${1:-}" ;;
        --all)     ALL=true ;;
    esac
done

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CN_PREFIX="m.daocloud.io"

# Mirror function
mirror_image() {
    local img="$1"
    case "$img" in
        ghcr.io/*)   echo "${CN_PREFIX}/ghcr.io/${img#ghcr.io/}" ;;
        gcr.io/*)    echo "${CN_PREFIX}/gcr.io/${img#gcr.io/}" ;;
        quay.io/*)   echo "${CN_PREFIX}/quay.io/${img#quay.io/}" ;;
        *)           echo "$img" ;;
    esac
}

# Find compose files
if $ALL; then
    COMPOSE_FILES=$(find "$PROJECT_DIR/stacks" -name "docker-compose.yml" -type f)
elif [[ -n "$TARGET" ]]; then
    COMPOSE_FILES="$PROJECT_DIR/stacks/$TARGET/docker-compose.yml"
else
    COMPOSE_FILES=$(find "$PROJECT_DIR/stacks" -name "docker-compose.yml" -type f)
fi

PULLED=0
FAILED=0

for f in $COMPOSE_FILES; do
    [[ -f "$f" ]] || continue
    # Extract images
    IMAGES=$(grep -oP 'image:\s*\K[^\s]+' "$f" 2>/dev/null || true)
    for img in $IMAGES; do
        # Skip comments and local images
        [[ "$img" == \#* ]] && continue
        [[ "$img" != */* ]] && continue

        mirroring=$(mirror_image "$img")
        if [[ "$mirroring" != "$img" ]]; then
            if $DRY_RUN; then
                echo "DRY-RUN: $img -> $mirroring"
            else
                if docker pull "$mirroring" 2>/dev/null; then
                    docker tag "$mirroring" "$img" 2>/dev/null || true
                    echo "✓ Pulled and tagged: $img"
                    ((PULLED++))
                else
                    echo "✗ Failed: $mirroring"
                    ((FAILED++))
                fi
            fi
        fi
    done
done

$DRY_RUN && echo "Dry-run complete." && exit 0
echo ""
echo "Pulled: $PULLED | Failed: $FAILED"
