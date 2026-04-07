#!/usr/bin/env bash
# =============================================================================
# Localize Images - Replace Docker image references with CN mirrors
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()  { echo -e "${BLUE}==>${NC} $*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
CONFIG_FILE="$SCRIPT_DIR/../config/cn-mirrors.yml"
STACKS_DIR="$SCRIPT_DIR/../stacks"

declare -A REGISTRY_MIRRORS=(
  ["gcr.io"]="gcr.m.daocloud.io"
  ["ghcr.io"]="ghcr.m.daocloud.io"
  ["k8s.gcr.io"]="k8s-gcr.m.daocloud.io"
  ["registry.k8s.io"]="k8s.m.daocloud.io"
  ["quay.io"]="quay.m.daocloud.io"
  ["docker.io"]="docker.m.daocloud.io"
)

translate_image() {
  local image=$1
  local direction=${2:-cn}
  
  for registry in "${!REGISTRY_MIRRORS[@]}"; do
    local mirror="${REGISTRY_MIRRORS[$registry]}"
    if [[ "$direction" == "cn" ]]; then
      if [[ "$image" == "$registry"* ]]; then
        echo "${image/$registry/$mirror}"
        return
      fi
    else
      if [[ "$image" == "$mirror"* ]]; then
        echo "${image/$mirror/$registry}"
        return
      fi
    fi
  done
  
  echo "$image"
}

find_compose_files() {
  find "$STACKS_DIR" -name "docker-compose*.yml" -o -name "docker-compose*.yaml" | sort
}

check_localization() {
  log_step "Checking if image localization is needed"
  
  local needs_localization=false
  local compose_files
  compose_files=$(find_compose_files)
  
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    
    local images
    images=$(grep -E '^\s+image:' "$file" | awk '{print $2}' | tr -d '"\x27')
    
    while IFS= read -r image; do
      [[ -z "$image" ]] && continue
      
      for registry in "${!REGISTRY_MIRRORS[@]}"; do
        if [[ "$image" == "$registry"* ]]; then
          echo -e "${YELLOW}[NEEDS CN]${NC} $file: $image"
          needs_localization=true
        fi
      done
    done <<< "$images"
  done <<< "$compose_files"
  
  if [[ "$needs_localization" == false ]]; then
    log_info "All images are already localized or don't need localization"
    return 1
  else
    return 0
  fi
}

localize_compose_files() {
  local dry_run=${1:-false}
  local direction=${2:-cn}
  
  log_step "Localizing compose files (direction: $direction, dry-run: $dry_run)"
  
  local compose_files
  compose_files=$(find_compose_files)
  local modified_count=0
  
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    
    local temp_file="$file.tmp"
    local file_modified=false
    
    while IFS= read -r line; do
      if [[ "$line" =~ ^[[:space:]]+image:[[:space:]]+(.*) ]]; then
        local original_image="${BASH_REMATCH[1]}"
        original_image=$(echo "$original_image" | tr -d '"\x27')
        
        local translated_image
        translated_image=$(translate_image "$original_image" "$direction")
        
        if [[ "$translated_image" != "$original_image" ]]; then
          if [[ "$dry_run" == true ]]; then
            echo -e "${YELLOW}[DRY-RUN]${NC} $file:"
            echo "  - $original_image"
            echo "  + $translated_image"
          else
            local indent="${line%%image:*}"
            echo "${indent}image: $translated_image" >> "$temp_file"
            file_modified=true
            modified_count=$((modified_count + 1))
          fi
        else
          [[ "$dry_run" == false ]] && echo "$line" >> "$temp_file"
        fi
      else
        [[ "$dry_run" == false ]] && echo "$line" >> "$temp_file"
      fi
    done < "$file"
    
    if [[ "$file_modified" == true && "$dry_run" == false ]]; then
      mv "$temp_file" "$file"
      log_info "Updated: $file"
    else
      [[ -f "$temp_file" ]] && rm "$temp_file"
    fi
    
  done <<< "$compose_files"
  
  if [[ "$dry_run" == false ]]; then
    log_info "Total images modified: $modified_count"
  fi
}

usage() {
  cat << USAGE_EOF
Usage: $0 [OPTIONS]

Options:
  --cn          Replace images with CN mirrors (default)
  --restore     Restore original image references
  --dry-run     Preview changes without modifying files
  --check       Check if localization is needed
  --help        Show this help message

Examples:
  $0 --cn              # Replace images with CN mirrors
  $0 --restore         # Restore original images
  $0 --dry-run         # Preview changes
  $0 --check           # Check if localization needed
USAGE_EOF
  exit 1
}

main() {
  local mode="cn"
  local dry_run=false
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      --cn)
        mode="cn"
        shift
        ;;
      --restore)
        mode="restore"
        shift
        ;;
      --dry-run)
        dry_run=true
        shift
        ;;
      --check)
        check_localization
        exit $?
        ;;
      --help|-h)
        usage
        ;;
      *)
        log_error "Unknown option: $1"
        usage
        ;;
    esac
  done
  
  localize_compose_files "$dry_run" "$mode"
}

main "$@"
