#!/bin/bash
# localize-images.sh - Replace gcr.io/ghcr.io images with China mirrors
# Usage:
#   ./localize-images.sh --cn          Replace images with CN mirrors
#   ./localize-images.sh --restore    Restore original images
#   ./localize-images.sh --dry-run    Preview changes without modifying
#   ./localize-images.sh --check      Check current status
#
# This script modifies docker-compose.yml files to use Chinese mirror
# registries instead of gcr.io, ghcr.io, and other blocked registries.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="${SCRIPT_DIR}/../config/cn-mirrors.yml"

ACTION=""  # cn, restore, dry-run, check

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --cn)
            ACTION="cn"
            shift
            ;;
        --restore)
            ACTION="restore"
            shift
            ;;
        --dry-run)
            ACTION="dry-run"
            shift
            ;;
        --check)
            ACTION="check"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--cn|--restore|--dry-run|--check]"
            echo ""
            echo "Options:"
            echo "  --cn        Replace images with China mirrors"
            echo "  --restore   Restore original gcr.io/ghcr.io images"
            echo "  --dry-run   Preview changes without modifying"
            echo "  --check     Check which images need localization"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [ -z "$ACTION" ]; then
    echo "Error: No action specified"
    echo "Usage: $0 [--cn|--restore|--dry-run|--check]"
    exit 1
fi

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Mirror mappings
declare -A MIRRORS
MIRRORS=(
    ["gcr.io"]="m.daocloud.io/gcr.io"
    ["ghcr.io"]="m.daocloud.io/ghcr.io"
    ["registry.k8s.io"]="m.daocloud.io/registry.k8s.io"
    ["quay.io"]="m.daocloud.io/quay.io"
    ["docker.io"]="m.daocloud.io/docker.io"
    ["k8s.gcr.io"]="m.daocloud.io/k8s.gcr.io"
)

# Find all docker-compose files
find_compose_files() {
    find "$ROOT_DIR" -name "docker-compose.yml" -type f 2>/dev/null
}

# Process a single compose file
process_compose() {
    local file="$1"
    local changed=0

    for src in "${!MIRRORS[@]}"; do
        local dst="${MIRRORS[$src]}"

        case "$ACTION" in
            cn)
                if grep -q "$src" "$file" 2>/dev/null; then
                    if [ "$ACTION" != "dry-run" ]; then
                        sed -i "s|${src}|${dst}|g" "$file"
                    fi
                    ((changed++)) || true
                fi
                ;;
            restore)
                for dst in "${!MIRRORS[@]}"; do
                    local src="${MIRRORS[$dst]}"
                    if grep -q "$dst" "$file" 2>/dev/null; then
                        if [ "$ACTION" != "dry-run" ]; then
                            sed -i "s|${dst}|${src}|g" "$file"
                        fi
                        ((changed++)) || true
                    fi
                done
                ;;
        esac
    done

    echo "$changed"
}

# Check which images need localization
check_images() {
    log "Checking for images that need localization..."

    local found=0
    local files_with_issues=""

    for file in $(find_compose_files); do
        for src in "${!MIRRORS[@]}"; do
            if grep -q "$src" "$file" 2>/dev/null; then
                ((found++)) || true
                files_with_issues="${files_with_issues}
  ${file}"
                break
            fi
        done
    done

    if [ $found -gt 0 ]; then
        warn "Found $found compose files with images needing China mirrors:${files_with_issues}"
        echo ""
        info "Run './localize-images.sh --cn' to replace with China mirrors"
    else
        log "All images are already using China mirrors or don't need replacement"
    fi
}

# Main execution
main() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║     Image Localization Script                     ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    echo ""

    case "$ACTION" in
        check)
            check_images
            ;;
        cn)
            log "Replacing images with China mirrors..."
            local total_changed=0
            local files_changed=0

            for file in $(find_compose_files); do
                local changed=$(process_compose "$file")
                if [ "$changed" -gt 0 ]; then
                    ((files_changed++)) || true
                    ((total_changed+=$changed)) || true
                    log "Modified: ${file}"
                fi
            done

            echo ""
            if [ $files_changed -gt 0 ]; then
                log "Modified $files_changed files ($total_changed replacements)"
            else
                log "No files needed modification"
            fi
            ;;
        restore)
            log "Restoring original images..."
            local total_restored=0
            local files_restored=0

            for file in $(find_compose_files); do
                local restored=$(process_compose "$file")
                if [ "$restored" -gt 0 ]; then
                    ((files_restored++)) || true
                    ((total_restored+=$restored)) || true
                    log "Restored: ${file}"
                fi
            done

            echo ""
            if [ $files_restored -gt 0 ]; then
                log "Restored $files_restored files ($total_restored replacements)"
            else
                log "No files needed restoration"
            fi
            ;;
        dry-run)
            log "DRY RUN - Showing what would be changed..."
            echo ""

            for file in $(find_compose_files); do
                for src in "${!MIRRORS[@]}"; do
                    if grep -q "$src" "$file" 2>/dev/null; then
                        echo "  ${file}:"
                        echo "    Would replace: $src -> ${MIRRORS[$src]}"
                        echo ""
                    fi
                done
            done
            ;;
    esac

    echo ""
}

main "$@"
