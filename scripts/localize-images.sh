#!/usr/bin/env bash
# =============================================================================
# localize-images.sh — Replace gcr.io/ghcr.io images with CN mirrors
# Usage:
#   ./localize-images.sh --cn        Replace with CN mirrors
#   ./localize-images.sh --restore  Restore original images
#   ./localize-images.sh --dry-run  Preview changes (no file modifications)
#   ./localize-images.sh --check    Check which images need localization
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
BOLD='\033[1m'; DIM='\033[2m'

log_info()  { echo -e "${GREEN}[localize]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[localize]${NC} $*" >&2; }
log_error() { echo -e "${RED}[localize]${NC} $*" >&2; }
log_step()  { echo -e "${BLUE}[localize]${NC} [STEP] $*"; }
log_dry()  { echo -e "${DIM}[dry-run]${NC} $*"; }

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
CONFIG_FILE="$REPO_ROOT/config/cn-mirrors.yml"
STACKS_DIR="$REPO_ROOT/stacks"

DRY_RUN=false
MODE=""

usage() {
    cat << EOF
Usage: $(basename "$0") <mode>

Replace gcr.io/ghcr.io Docker images in compose files with CN mirrors.

Modes:
  --cn        Replace images with CN mirrors (default)
  --restore   Restore original gcr.io/ghcr.io images
  --dry-run   Preview changes without modifying files
  --check     Show which images would be replaced (no changes)
  --help      Show this help

Examples:
  $(basename "$0") --cn         # Replace with CN mirrors
  $(basename "$0") --dry-run    # Preview what would change
  $(basename "$0") --restore    # Undo changes

The mirror mappings are read from config/cn-mirrors.yml.
Run from repo root: $(basename "$0") --cn
EOF
}

[[ $# -eq 0 || "$1" == "--help" ]] && { usage; exit 0; }

case "$1" in
    --cn)        MODE="localize" ;;
    --restore)   MODE="restore" ;;
    --dry-run)   MODE="localize"; DRY_RUN=true ;;
    --check)     MODE="check" ;;
    *)           log_error "Unknown mode: $1"; usage; exit 1 ;;
esac

if [ ! -f "$CONFIG_FILE" ]; then
    log_error "Mirror config not found: $CONFIG_FILE"
    exit 1
fi

# Parse YAML mapping file (simple parser for key: value lines)
declare -A MIRROR_MAP
parse_config() {
    local current_key=""
    while IFS= read -r line; do
        # Skip comments and blank lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        # Remove indentation and trailing
        line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        # Key: value
        if [[ "$line" =~ ^[[:alnum:]_-]+[[:space:]]*:[[:space:]]*.+ ]]; then
            key=$(echo "$line" | cut -d: -f1)
            val=$(echo "$line" | cut -d: -f2- | sed 's/^[[:space:]]*//')
            MIRROR_MAP[$key]="$val"
        fi
    done < "$CONFIG_FILE"
}

parse_config

echo ""
log_step "Scanning compose files in $STACKS_DIR ..."

changed=0
total_checked=0

find "$STACKS_DIR" -name "docker-compose*.yml" -o -name "docker-compose*.yaml" 2>/dev/null | while read -r compose_file; do
    total_checked=$((total_checked + 1))
    
    if [ "$MODE" == "check" ]; then
        grep -E 'image:\s+(gcr\.io|ghcr\.io)' "$compose_file" 2>/dev/null | while read -r line; do
            img=$(echo "$line" | sed 's/.*image:[[:space:]]*//')
            log_info "$compose_file: $img"
        done
        continue
    fi

    local tmpfile=""
    if [ "$DRY_RUN" == "false" ]; then
        tmpfile=$(mktemp)
    fi

    while IFS= read -r line; do
        replaced=false
        new_line="$line"
        
        for src in "${!MIRROR_MAP[@]}"; do
            dst="${MIRROR_MAP[$src]}"
            if echo "$line" | grep -qF "$src"; then
                new_line=$(echo "$new_line" | sed "s|$src|$dst|g")
                replaced=true
            fi
        done
        
        if [ "$replaced" == "true" ]; then
            if [ "$MODE" == "localize" ]; then
                if [ "$DRY_RUN" == "true" ]; then
                    log_dry "  $line  ->  $new_line"
                else
                    echo "$new_line"
                fi
                changed=$((changed + 1))
            elif [ "$MODE" == "restore" ]; then
                if [ "$DRY_RUN" == "true" ]; then
                    log_dry "  $line  ->  $new_line"
                else
                    echo "$new_line"
                fi
                changed=$((changed + 1))
            fi
        else
            [ "$DRY_RUN" == "false" ] && echo "$line"
        fi
    done < "$compose_file" > "${tmpfile:-$compose_file}"
    
    [ -n "$tmpfile" ] && [ -f "$tmpfile" ] && rm -f "$tmpfile"
done

echo ""
if [ "$DRY_RUN" == "true" ]; then
    log_info "Dry run complete — $changed replacements would be made"
elif [ "$MODE" == "check" ]; then
    log_info "Check complete — images needing localization listed above"
else
    if [ $changed -gt 0 ]; then
        log_info "Updated $changed image references"
        log_info "Restart affected stacks: cd stacks/<name> && docker compose down && docker compose up -d"
    else
        log_info "No images needed $MODE"
    fi
fi
