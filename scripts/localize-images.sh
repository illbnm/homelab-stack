#!/usr/bin/env bash
# =============================================================================
# localize-images.sh — Docker 镜像本地化工具
# 将 gcr.io/ghcr.io/k8s.gcr.io 镜像替换为国内镜像源
# =============================================================================
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_change() { echo -e "${CYAN}[CHANGE]${NC} $*"; }

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.."; pwd)"
CONFIG_FILE="${PROJECT_ROOT}/config/cn-mirrors.yml"
BACKUP_DIR="${PROJECT_ROOT}/.image-backups"

# Default mirror prefix (can be overridden by config)
# shellcheck disable=SC2034
DEFAULT_CN_PREFIX="m.daocloud.io"

# Registry mappings (prefix-based)
declare -A REGISTRY_MAP=(
  ["gcr.io"]="gcr.m.daocloud.io"
  ["ghcr.io"]="ghcr.m.daocloud.io"
  ["k8s.gcr.io"]="k8s-gcr.m.daocloud.io"
  ["registry.k8s.io"]="k8s.m.daocloud.io"
  ["quay.io"]="quay.m.daocloud.io"
  ["lscr.io"]="lscr.m.daocloud.io"
  ["docker.io"]="docker.m.daocloud.io"
)

# Image mappings from config
declare -A IMAGE_MAP

# Parse YAML config (simple parser for cn-mirrors.yml)
parse_config() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    return 0
  fi
  
  # Simple YAML parser for our specific format
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip comments and empty lines
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// }" ]] && continue
    
    # Parse "original: replacement" format (with proper YAML key handling)
    if [[ "$line" =~ ^[[:space:]]*([^:]+):[[:space:]]*(.+)$ ]]; then
      local orig="${BASH_REMATCH[1]}"
      local repl="${BASH_REMATCH[2]}"
      # Trim whitespace
      orig="${orig#"${orig%%[![:space:]]*}"}"
      orig="${orig%"${orig##*[![:space:]]}"}"
      repl="${repl#"${repl%%[![:space:]]*}"}"
      repl="${repl%"${repl##*[![:space:]]}"}"
      IMAGE_MAP["$orig"]="$repl"
    fi
  done < "$CONFIG_FILE"
}

# Load image mappings from config
load_mappings() {
  # Parse YAML config
  parse_config
  
  # Add default mappings for common images
  IMAGE_MAP["gcr.io/cadvisor/cadvisor"]="gcr.m.daocloud.io/cadvisor/cadvisor"
  IMAGE_MAP["ghcr.io/ajnart/homarr"]="ghcr.m.daocloud.io/ajnart/homarr"
  IMAGE_MAP["ghcr.io/gethomepage/homepage"]="ghcr.m.daocloud.io/gethomepage/homepage"
  IMAGE_MAP["ghcr.io/open-webui/open-webui"]="ghcr.m.daocloud.io/open-webui/open-webui"
  IMAGE_MAP["ghcr.io/abiosoft/sd-webui-docker"]="ghcr.m.daocloud.io/abiosoft/sd-webui-docker"
  IMAGE_MAP["ghcr.io/goauthentik/server"]="ghcr.m.daocloud.io/goauthentik/server"
}

# Check if image needs translation
needs_translation() {
  local image="$1"
  
  for registry in "${!REGISTRY_MAP[@]}"; do
    if [[ "$image" == "$registry/"* ]]; then
      return 0
    fi
  done
  
  return 1
}

# Translate single image to CN mirror
translate_image() {
  local image="$1"
  local cn_image=""
  
  # Extract image without tag
  local image_no_tag="${image%%:*}"
  local tag="${image##*:}"
  [[ "$image_no_tag" == "$image" ]] && tag=""
  
  # Check for exact match in IMAGE_MAP first
  if [[ -n "${IMAGE_MAP[$image_no_tag]:-}" ]]; then
    cn_image="${IMAGE_MAP[$image_no_tag]}"
    [[ -n "$tag" ]] && cn_image="${cn_image}:${tag}"
    echo "$cn_image"
    return 0
  fi
  
  # Check for prefix-based mapping
  for registry in "${!REGISTRY_MAP[@]}"; do
    if [[ "$image" == "$registry/"* ]]; then
      local mirror="${REGISTRY_MAP[$registry]}"
      cn_image="${image/$registry/$mirror}"
      echo "$cn_image"
      return 0
    fi
  done
  
  # No translation needed
  echo "$image"
  return 1
}

# Find all compose files
find_compose_files() {
  find "${PROJECT_ROOT}/stacks" -name "docker-compose*.yml" -type f 2>/dev/null | sort || true
}

# Backup compose file
backup_file() {
  local file="$1"
  local backup_name
  backup_name=$(basename "$file").bak.$(date +%Y%m%d_%H%M%S)
  
  mkdir -p "$BACKUP_DIR"
  cp "$file" "$BACKUP_DIR/$backup_name"
  log_info "Backup saved: $BACKUP_DIR/$backup_name"
}

# Check current state
check_state() {
  log_info "Checking image localization state..."
  echo ""
  
  local needs_localization=false
  
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    
    local file_needs_change=false
    while IFS= read -r line; do
      if [[ "$line" =~ ^[[:space:]]*image:[[:space:]]*(.+)$ ]]; then
        local image="${BASH_REMATCH[1]}"
        image="${image//\"/}"
        image="${image//\'/}"
        
        if needs_translation "$image"; then
          if [[ "$file_needs_change" == false ]]; then
            echo -e "${YELLOW}File: $file${NC}"
            file_needs_change=true
            needs_localization=true
          fi
          local cn_image
          cn_image=$(translate_image "$image")
          echo "  $image"
          echo "  → $cn_image"
        fi
      fi
    done < "$file"
    
    $file_needs_change && echo ""
  done < <(find_compose_files)
  
  if $needs_localization; then
    echo ""
    log_warn "Found images that can be localized for CN network"
    log_info "Run '$0 --cn' to apply changes"
    return 1
  else
    log_info "All images are already localized or don't need translation"
    return 0
  fi
}

# Dry run - show changes without applying
dry_run() {
  log_info "Dry run mode - showing changes without modifying files"
  echo ""
  
  local changes=0
  
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    
    while IFS= read -r line; do
      if [[ "$line" =~ ^([[:space:]]*image:[[:space:]]*)(.+)$ ]]; then
        local prefix="${BASH_REMATCH[1]}"
        local image="${BASH_REMATCH[2]}"
        image="${image//\"/}"
        image="${image//\'/}"
        
        if needs_translation "$image"; then
          local cn_image
          cn_image=$(translate_image "$image")
          echo -e "${YELLOW}$file${NC}:"
          echo "  - ${prefix}${image}"
          echo "  + ${prefix}${cn_image}"
          echo ""
          ((changes++)) || true
        fi
      fi
    done < "$file"
  done < <(find_compose_files)
  
  if [[ $changes -eq 0 ]]; then
    log_info "No changes needed"
  else
    log_info "Total changes: $changes"
  fi
}

# Localize images (--cn)
localize_images() {
  log_info "Localizing images for CN network..."
  echo ""
  
  local total_changes=0
  
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    
    local changed=false
    local temp_file
    temp_file=$(mktemp "${file}.tmp.XXXXXX")
    
    # Backup original
    backup_file "$file"
    
    while IFS= read -r line; do
      if [[ "$line" =~ ^([[:space:]]*image:[[:space:]]*)(.+)$ ]]; then
        local prefix="${BASH_REMATCH[1]}"
        local image="${BASH_REMATCH[2]}"
        local quote=""
        
        # Preserve quotes
        if [[ "$image" == \"*\" ]]; then
          quote='"'
          image="${image#\"}"
          image="${image%\"}"
        elif [[ "$image" == \'*\' ]]; then
          quote="'"
          image="${image#\'}"
          image="${image%\'}"
        fi
        
        if needs_translation "$image"; then
          local cn_image
          cn_image=$(translate_image "$image")
          echo "${prefix}${quote}${cn_image}${quote}" >> "$temp_file"
          log_change "$file: $image → $cn_image"
          changed=true
          ((total_changes++)) || true
        else
          echo "$line" >> "$temp_file"
        fi
      else
        echo "$line" >> "$temp_file"
      fi
    done < "$file"
    
    if $changed; then
      mv "$temp_file" "$file"
    else
      rm -f "$temp_file"
    fi
  done < <(find_compose_files)
  
  echo ""
  if [[ $total_changes -gt 0 ]]; then
    log_info "Localization complete: $total_changes images changed"
    log_info "Backups saved in: $BACKUP_DIR"
  else
    log_info "No images needed localization"
  fi
}

# Restore original images (--restore)
restore_images() {
  log_info "Restoring original images..."
  echo ""
  
  local total_changes=0
  
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    
    local changed=false
    local temp_file
    temp_file=$(mktemp "${file}.tmp.XXXXXX")
    
    while IFS= read -r line; do
      if [[ "$line" =~ ^([[:space:]]*image:[[:space:]]*)(.+)$ ]]; then
        local prefix="${BASH_REMATCH[1]}"
        local image="${BASH_REMATCH[2]}"
        local quote=""
        
        # Preserve quotes
        if [[ "$image" == \"*\" ]]; then
          quote='"'
          image="${image#\"}"
          image="${image%\"}"
        elif [[ "$image" == \'*\' ]]; then
          quote="'"
          image="${image#\'}"
          image="${image%\'}"
        fi
        
        # Restore from CN mirror to original
        local original_image="$image"
        for registry in "${!REGISTRY_MAP[@]}"; do
          local mirror="${REGISTRY_MAP[$registry]}"
          if [[ "$image" == "$mirror/"* ]]; then
            original_image="${image/$mirror/$registry}"
            break
          fi
        done
        
        if [[ "$original_image" != "$image" ]]; then
          echo "${prefix}${quote}${original_image}${quote}" >> "$temp_file"
          log_change "$file: $image → $original_image"
          changed=true
          ((total_changes++)) || true
        else
          echo "$line" >> "$temp_file"
        fi
      else
        echo "$line" >> "$temp_file"
      fi
    done < "$file"
    
    if $changed; then
      mv "$temp_file" "$file"
    else
      rm -f "$temp_file"
    fi
  done < <(find_compose_files)
  
  echo ""
  if [[ $total_changes -gt 0 ]]; then
    log_info "Restore complete: $total_changes images restored"
  else
    log_info "No images needed restoration"
  fi
}

# Verify no gcr.io/ghcr.io remain
verify_localization() {
  log_info "Verifying localization..."
  
  local found_original=false
  
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    
    if grep -E 'image:.*gcr\.io|image:.*ghcr\.io|image:.*k8s\.gcr\.io|image:.*quay\.io' "$file" | grep -v '#' | grep -q .; then
      log_warn "Found non-localized images in: $file"
      grep -E 'image:.*gcr\.io|image:.*ghcr\.io|image:.*k8s\.gcr\.io|image:.*quay\.io' "$file" | grep -v '#'
      found_original=true
    fi
  done < <(find_compose_files)
  
  if $found_original; then
    log_error "Verification failed: Some images are not localized"
    return 1
  else
    log_info "Verification passed: All images are localized"
    return 0
  fi
}

# Usage
usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --cn           Replace gcr.io/ghcr.io/k8s.gcr.io with CN mirrors
  --restore      Restore original image names
  --dry-run      Preview changes without modifying files
  --check        Check if localization is needed
  --verify       Verify all images are localized
  -h, --help     Show this help

Examples:
  $0 --cn        # Localize images for CN network
  $0 --restore   # Restore original images
  $0 --dry-run   # Preview changes
  $0 --check     # Check current state

Config file: config/cn-mirrors.yml
Backup dir:  .image-backups/

Supported registries for translation:
  - gcr.io          → gcr.m.daocloud.io
  - ghcr.io         → ghcr.m.daocloud.io
  - k8s.gcr.io      → k8s-gcr.m.daocloud.io
  - registry.k8s.io → k8s.m.daocloud.io
  - quay.io         → quay.m.daocloud.io
  - lscr.io         → lscr.m.daocloud.io
  - docker.io       → docker.m.daocloud.io

EOF
  exit 0
}

# Main
main() {
  cd "$PROJECT_ROOT"
  load_mappings
  
  local action=""
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      --cn) action="localize" ;;
      --restore) action="restore" ;;
      --dry-run) action="dry-run" ;;
      --check) action="check" ;;
      --verify) action="verify" ;;
      -h|--help) usage ;;
      *) log_error "Unknown option: $1"; usage ;;
    esac
    shift
  done
  
  case "$action" in
    localize)
      localize_images
      verify_localization
      ;;
    restore)
      restore_images
      ;;
    dry-run)
      dry_run
      ;;
    check)
      check_state
      ;;
    verify)
      verify_localization
      ;;
    "")
      usage
      ;;
  esac
}

main "$@"
