#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Image Localization Script
# Replaces gcr.io/ghcr.io images with CN mirrors in compose files
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Colors
# -----------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# -----------------------------------------------------------------------------
# Script info
# -----------------------------------------------------------------------------
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")
CONFIG_FILE="$ROOT_DIR/config/cn-mirrors.yml"
BACKUP_SUFFIX=".bak.$(date +%Y%m%d%H%M%S)"

# -----------------------------------------------------------------------------
# Mirror mappings
# -----------------------------------------------------------------------------
declare -A MIRROR_MAP=(
    ["gcr.io"]="gcr.m.daocloud.io"
    ["ghcr.io"]="ghcr.m.daocloud.io"
    ["k8s.gcr.io"]="k8s-gcr.m.daocloud.io"
    ["registry.k8s.io"]="k8s.m.daocloud.io"
    ["quay.io"]="quay.m.daocloud.io"
    ["docker.io"]="docker.m.daocloud.io"
)

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------
log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()  { echo; echo -e "${BOLD}${CYAN}==> $*${NC}"; }
log_diff() { echo -e "  ${GREEN}-- $1 -> $2${NC}"; }

# -----------------------------------------------------------------------------
# Usage
# -----------------------------------------------------------------------------
usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --cn         Replace with CN mirrors
  --restore    Restore original image references
  --dry-run    Preview changes without modifying files
  --check      Check if any images need localization

Examples:
  $(basename "$0") --cn
  $(basename "$0") --restore
  $(basename "$0") --dry-run
  $(basename "$0") --check
EOF
    exit 0
}

# -----------------------------------------------------------------------------
# Translate image name
# -----------------------------------------------------------------------------
translate_image() {
    local image="$1"
    for registry in "${!MIRROR_MAP[@]}"; do
        if [[ "$image" == "$registry"* ]]; then
            local mirror="${MIRROR_MAP[$registry]}"
            echo "${image/$registry/$mirror}"
            return 0
        fi
    done
    echo "$image"
}

# -----------------------------------------------------------------------------
# Find all compose files
# -----------------------------------------------------------------------------
find_compose_files() {
    find "$ROOT_DIR/stacks" -name "docker-compose*.yml" -type f 2>/dev/null
}

# -----------------------------------------------------------------------------
# Process compose file
# -----------------------------------------------------------------------------
process_compose_file() {
    local file="$1"
    local mode="$2"
    local changed=0
    
    local tmp_file
    tmp_file=$(mktemp)
    
    # Create backup if not exists
    if [[ "$mode" != "dry-run" && ! -f "${file}${BACKUP_SUFFIX}" ]]; then
        cp "$file" "${file}${BACKUP_SUFFIX}"
    fi
    
    while IFS= read -r line; do
        local trimmed
        trimmed=$(echo "$line" | sed 's/^[[:space:]]*//')
        
        if [[ "$trimmed" =~ ^image: ]]; then
            local current_image
            current_image=$(echo "$line" | sed -n 's/.*image:[[:space:]]*//' | sed 's/["'"'"']//g' | tr -d '"' | tr -d "'")
            
            local new_image
            if [[ "$mode" == "cn" ]]; then
                new_image=$(translate_image "$current_image")
                if [[ "$new_image" != "$current_image" ]]; then
                    local new_line="${line/$current_image/$new_image}"
                    echo "$new_line" >> "$tmp_file"
                    log_diff "$current_image" "$new_image"
                    ((changed++))
                else
                    echo "$line" >> "$tmp_file"
                fi
            elif [[ "$mode" == "restore" ]]; then
                if [[ -f "${file}${BACKUP_SUFFIX}" ]]; then
                    local original_image
                    original_image=$(grep -E "^image:.*${current_image}" "${file}${BACKUP_SUFFIX}" | head -1 | sed -n 's/.*image:[[:space:]]*//' | sed 's/["'"'"']//g' | tr -d '"' | tr -d "'")
                    if [[ -n "$original_image" ]]; then
                        echo "${line/$current_image/$original_image}" >> "$tmp_file"
                        log_diff "$current_image" "$original_image"
                        ((changed++))
                    else
                        echo "$line" >> "$tmp_file"
                    fi
                else
                    echo "$line" >> "$tmp_file"
                fi
            else
                echo "$line" >> "$tmp_file"
            fi
        else
            echo "$line" >> "$tmp_file"
        fi
    done < "$file"
    
    if [[ "$mode" != "dry-run" && $changed -gt 0 ]]; then
        mv "$tmp_file" "$file"
    else
        rm -f "$tmp_file"
    fi
    
    echo "$changed"
}

# -----------------------------------------------------------------------------
# CN mode: replace images
# -----------------------------------------------------------------------------
do_cn() {
    log_step "Replacing images with CN mirrors"
    
    local total_changed=0
    local file
    
    while IFS= read -r file; do
        log_info "Processing: $file"
        local changed
        changed=$(process_compose_file "$file" "cn")
        if [[ "$changed" -gt 0 ]]; then
            total_changed=$((total_changed + 1))
        fi
    done < <(find_compose_files)
    
    log_step "Done! Changed $total_changed image reference(s)"
}

# -----------------------------------------------------------------------------
# Restore mode: restore original images
# -----------------------------------------------------------------------------
do_restore() {
    log_step "Restoring original image references"
    
    local total_changed=0
    local file
    
    while IFS= read -r file; do
        log_info "Restoring: $file"
        local changed
        changed=$(process_compose_file "$file" "restore")
        if [[ "$changed" -gt 0 ]]; then
            total_changed=$((total_changed + 1))
            rm -f "${file}${BACKUP_SUFFIX}"
        fi
    done < <(find_compose_files)
    
    log_step "Done! Restored $total_changed image reference(s)"
}

# -----------------------------------------------------------------------------
# Dry-run mode: preview changes
# -----------------------------------------------------------------------------
do_dry_run() {
    log_step "Previewing changes (dry-run mode)"
    
    local total_would_change=0
    local file
    
    while IFS= read -r file; do
        local changed
        changed=$(process_compose_file "$file" "cn")
        if [[ "$changed" -gt 0 ]]; then
            total_would_change=$((total_would_change + 1))
        fi
    done < <(find_compose_files)
    
    if [[ $total_would_change -eq 0 ]]; then
        log_info "No changes needed - all images are already using CN mirrors or local."
    else
        log_warn "Would change $total_would_change image reference(s)"
    fi
}

# -----------------------------------------------------------------------------
# Check mode: check if localization needed
# -----------------------------------------------------------------------------
do_check() {
    log_step "Checking image localization status"
    
    local needs_localization=0
    local already_localized=0
    local file
    
    while IFS= read -r file; do
        while IFS= read -r line; do
            if [[ "$line" =~ ^image: ]]; then
                local current_image
                current_image=$(echo "$line" | sed -n 's/.*image:[[:space:]]*//' | sed 's/["'"'"']//g' | tr -d '"' | tr -d "'")
                
                local needs_mirror=false
                for registry in "${!MIRROR_MAP[@]}"; do
                    if [[ "$current_image" == "$registry"* ]]; then
                        needs_mirror=true
                        break
                    fi
                done
                
                if [[ "$needs_mirror" == true ]]; then
                    log_warn "$file: $current_image needs CN mirror"
                    needs_localization=$((needs_localization + 1))
                else
                    log_info "$file: $current_image is OK"
                    already_localized=$((already_localized + 1))
                fi
            fi
        done < "$file"
    done < <(find_compose_files)
    
    log_step "Done!"
    if [[ $needs_localization -gt 0 ]]; then
        log_warn "$needs_localization image(s) need CN mirror. Run: $0 --cn"
    else
        log_info "All $already_localized image(s) are properly localized or don't need CN mirrors"
    fi
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
case "${1:-}" in
    --cn)
        do_cn
        ;;
    --restore)
        do_restore
        ;;
    --dry-run)
        do_dry_run
        ;;
    --check)
        do_check
        ;;
    *)
        usage
        ;;
esac
