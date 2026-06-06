#!/bin/bash
# localize-images.sh - Replace gcr.io/ghcr.io/registry.k8s.io/quay.io with CN mirrors
# Usage: ./localize-images.sh [--cn|--restore|--dry-run|--check]
#
# Reads mirror mappings from config/cn-mirrors.yml
# Applies or reverts image URL replacements in all compose files.
#
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
MIRROR_CONFIG="$PROJECT_ROOT/config/cn-mirrors.yml"

info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }

ACTION="${1:-}"
COMPOSE_FILES=()

# Find all compose files
find_compose_files() {
    local count=0
    while IFS= read -r -d '' f; do
        COMPOSE_FILES+=("$f")
        ((count++)) || true
    done < <(find "$PROJECT_ROOT" \( -name "docker-compose*.yml" -o -name "docker-compose*.yaml" \) -print0 2>/dev/null)
    echo "$count compose file(s) found"
}

# Parse mirrors from cn-mirrors.yml (simple line-based parser)
parse_mirrors() {
    local src tgt
    grep -E '^\s+"[^"]+":\s+"[^"]+"' "$MIRROR_CONFIG" 2>/dev/null | while IFS=: read -r src tgt; do
        src=$(echo "$src" | tr -d ' "')
        tgt=$(echo "$tgt" | tr -d ' "')
        echo "$src=$tgt"
    done
}

# Apply mirror replacements
apply_cn_mirrors() {
    info "Applying CN mirror replacements..."
    local applied=0
    for pair in $(parse_mirrors); do
        local src="${pair%%=*}"
        local tgt="${pair##*=}"
        for f in "${COMPOSE_FILES[@]}"; do
            if grep -q "$src" "$f" 2>/dev/null; then
                perl -i -pe "s|$src|$tgt|g" "$f"
                echo "  $src -> $tgt in $(basename "$f")"
                ((applied++)) || true
            fi
        done
    done
    if [[ $applied -eq 0 ]]; then
        info "No images needed replacement (already localized or no matching images)"
    else
        ok "Applied $applied replacement(s)"
    fi
}

# Restore original mirrors
restore_mirrors() {
    info "Restoring original mirror URLs..."
    local restored=0
    for pair in $(parse_mirrors); do
        local src="${pair%%=*}"
        local tgt="${pair##*=}"
        for f in "${COMPOSE_FILES[@]}"; do
            if grep -q "$tgt" "$f" 2>/dev/null; then
                perl -i -pe "s|$tgt|$src|g" "$f"
                echo "  $tgt -> $src in $(basename "$f")"
                ((restored++)) || true
            fi
        done
    done
    if [[ $restored -eq 0 ]]; then
        info "No localized images found to restore"
    else
        ok "Restored $restored replacement(s)"
    fi
}

# Dry run - show what would change
dry_run() {
    info "Dry run - showing planned changes..."
    local count=0
    for pair in $(parse_mirrors); do
        local src="${pair%%=*}"
        local tgt="${pair##*=}"
        for f in "${COMPOSE_FILES[@]}"; do
            if grep -q "$src" "$f" 2>/dev/null; then
                echo "  WOULD REPLACE: $src -> $tgt in $(basename "$f")"
                ((count++)) || true
            fi
        done
    done
    if [[ $count -eq 0 ]]; then
        info "No replacements needed"
    else
        info "Total: $count replacement(s) would be made"
    fi
}

# Check current state
check_state() {
    info "Checking current image state..."
    local needs_localization=0
    for pair in $(parse_mirrors); do
        local src="${pair%%=*}"
        for f in "${COMPOSE_FILES[@]}"; do
            if grep -q "$src" "$f" 2>/dev/null; then
                echo "  NEEDS LOCALIZATION: $src in $(basename "$f")"
                ((needs_localization++)) || true
            fi
        done
    done
    if [[ $needs_localization -eq 0 ]]; then
        ok "All images are localized or no matching images found"
    else
        warn "$needs_localization image(s) need localization"
        echo "Run: $0 --cn to apply"
    fi
}

# Main
if [[ ! -f "$MIRROR_CONFIG" ]]; then
    error "Mirror config not found: $MIRROR_CONFIG"
    exit 1
fi

count=$(find_compose_files)
info "Found $count"

case "$ACTION" in
    --cn)
        apply_cn_mirrors
        ;;
    --restore)
        restore_mirrors
        ;;
    --dry-run)
        dry_run
        ;;
    --check)
        check_state
        ;;
    *)
        echo "Usage: $0 {--cn|--restore|--dry-run|--check}"
        echo ""
        echo "  --cn        Replace international images with CN mirrors"
        echo "  --restore   Restore original international image URLs"
        echo "  --dry-run   Show planned changes without applying"
        echo "  --check     Check which images need localization"
        exit 1
        ;;
esac
