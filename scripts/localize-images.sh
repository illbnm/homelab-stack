#!/usr/bin/env bash
# =============================================================================
# localize-images.sh — Docker Image Localization for China Network
# =============================================================================
# Transforms Docker image references to use domestic mirrors for faster pulls
# in mainland China. Supports compose files, Kubernetes manifests, and batch mode.
#
# Usage:
#   ./localize-images.sh --cn [OPTIONS]        # Apply CN mirrors
#   ./localize-images.sh --restore [OPTIONS]   # Restore original images
#   ./localize-images.sh --dry-run [OPTIONS]   # Preview changes only
#   ./localize-images.sh --check [OPTIONS]     # Check current state
#
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.."; pwd)"
MIRROR_CONFIG="$PROJECT_ROOT/config/cn-mirrors.yml"
BACKUP_DIR="$PROJECT_ROOT/.image-backups"

# Logging functions
log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()  { echo -e "\n${BLUE}${BOLD}==>${NC} $*"; }
log_debug() { [[ "${VERBOSE:-false}" == "true" ]] && echo -e "${BLUE}[DEBUG]${NC} $*"; }

# Image registry mapping
declare -A REGISTRY_MAP=(
  ["gcr.io"]="gcr.m.daocloud.io"
  ["ghcr.io"]="ghcr.m.daocloud.io"
  ["k8s.gcr.io"]="k8s-gcr.m.daocloud.io"
  ["registry.k8s.io"]="k8s.m.daocloud.io"
  ["quay.io"]="quay.m.daocloud.io"
  ["docker.io"]="docker.m.daocloud.io"
)

# Parse YAML config (simple parser for mirror config)
parse_yaml_mirrors() {
  local config_file="$1"
  if [[ ! -f "$config_file" ]]; then
    log_warn "Mirror config not found: $config_file (using defaults)"
    return
  fi

  # Simple YAML parsing for registry mappings
  local current_registry=""
  while IFS= read -r line; do
    # Match registry entries (e.g., "gcr.io:")
    if [[ "$line" =~ ^([a-z0-9._-]+\.[a-z]{2,}):$ ]]; then
      current_registry="${BASH_REMATCH[1]}"
    # Match mirror entries
    elif [[ "$line" =~ mirror:\ *\"?(https?://[^\"]+)\"? ]] && [[ -n "$current_registry" ]]; then
      local mirror="${BASH_REMATCH[1]}"
      # Only use first mirror (highest priority)
      if [[ -z "${REGISTRY_MAP[$current_registry]:-}" ]]; then
        REGISTRY_MAP["$current_registry"]="$mirror"
        log_debug "Loaded mirror: $current_registry -> $mirror"
      fi
    fi
  done < "$config_file"
}

# Translate single image reference
translate_image() {
  local image="$1"
  local mode="${2:-cn}"  # cn or restore

  local translated="$image"

  if [[ "$mode" == "cn" ]]; then
    # Apply CN mirrors
    for registry in "${!REGISTRY_MAP[@]}"; do
      if [[ "$image" == "$registry/"* ]]; then
        local mirror="${REGISTRY_MAP[$registry]}"
        translated="${image/$registry/$mirror}"
        log_debug "Translated: $image -> $translated"
        break
      fi
    done

    # Handle docker.io implicit prefix
    if [[ "$image" != */* ]] || [[ "$image" == library/* ]]; then
      # No registry prefix - assume docker.io
      local mirror="${REGISTRY_MAP[docker.io]}"
      if [[ -n "$mirror" ]]; then
        if [[ "$image" == library/* ]]; then
          translated="$mirror/${image}"
        else
          translated="$mirror/library/${image}"
        fi
        log_debug "Added docker.io mirror: $image -> $translated"
      fi
    fi
  elif [[ "$mode" == "restore" ]]; then
    # Restore original registries
    for registry in "${!REGISTRY_MAP[@]}"; do
      local mirror="${REGISTRY_MAP[$registry]}"
      if [[ "$image" == "$mirror/"* ]]; then
        translated="${image/$mirror/$registry}"
        log_debug "Restored: $image -> $translated"
        break
      fi
    done
  fi

  echo "$translated"
}

# Backup a file before modification
backup_file() {
  local file="$1"
  local backup_name
  backup_name="$(basename "$file").backup.$(date +%Y%m%d_%H%M%S)"
  local backup_path="$BACKUP_DIR/$backup_name"

  mkdir -p "$BACKUP_DIR"
  cp "$file" "$backup_path"
  log_info "Backup created: $backup_path"
  echo "$backup_path"
}

# Process docker-compose file
process_compose_file() {
  local file="$1"
  local mode="${2:-cn}"
  local dry_run="${3:-false}"

  if [[ ! -f "$file" ]]; then
    log_error "File not found: $file"
    return 1
  fi

  log_step "Processing: $file"

  local temp_file
  temp_file=$(mktemp)
  local changes=0

  # Process line by line to preserve formatting
  while IFS= read -r line; do
    # Match image: lines
    if [[ "$line" =~ ^(\ *image:\ *)(.+)$ ]]; then
      local prefix="${BASH_REMATCH[1]}"
      local image="${BASH_REMATCH[2]}"
      # Remove quotes if present
      image="${image%\"}"
      image="${image#\"}"
      image="${image%\'}"
      image="${image#\'}"

      local translated
      translated=$(translate_image "$image" "$mode")

      if [[ "$translated" != "$image" ]]; then
        ((changes++))
        # Preserve original quoting style
        if [[ "${BASH_REMATCH[2]}" == \"*\" ]] || [[ "${BASH_REMATCH[2]}" == \'*\' ]]; then
          echo "${prefix}${translated}"
        else
          echo "${prefix}${translated}"
        fi
        log_info "  $image -> $translated"
      else
        echo "$line"
      fi
    else
      echo "$line"
    fi
  done < "$file" > "$temp_file"

  if [[ $changes -eq 0 ]]; then
    log_info "No changes needed for: $file"
    rm -f "$temp_file"
    return 0
  fi

  if [[ "$dry_run" == "true" ]]; then
    log_warn "[DRY-RUN] Would modify: $file ($changes changes)"
    log_info "Preview:"
    diff -u "$file" "$temp_file" || true
    rm -f "$temp_file"
  else
    # Backup and apply changes
    backup_file "$file"
    mv "$temp_file" "$file"
    log_info "Updated: $file ($changes changes)"
  fi
}

# Process all compose files in a directory
process_directory() {
  local dir="$1"
  local mode="${2:-cn}"
  local dry_run="${3:-false}"

  if [[ ! -d "$dir" ]]; then
    log_error "Directory not found: $dir"
    return 1
  fi

  log_step "Processing directory: $dir"

  local files_processed=0

  # Find all docker-compose files
  while IFS= read -r -d '' file; do
    process_compose_file "$file" "$mode" "$dry_run"
    ((files_processed++))
  done < <(find "$dir" -type f \( -name "docker-compose*.yml" -o -name "docker-compose*.yaml" \) -print0)

  log_info "Processed $files_processed compose file(s)"
}

# Check current image state
check_images() {
  local target="${1:-.}"

  log_step "Checking image references in: $target"

  local cn_count=0
  local original_count=0

  while IFS= read -r file; do
    while IFS= read -r line; do
      if [[ "$line" =~ image:\ *(.+) ]]; then
        local image="${BASH_REMATCH[1]}"
        image="${image%\"}"; image="${image#\"}"
        image="${image%\'}"; image="${image#\'}"

        # Check if using CN mirror
        local is_cn=false
        for registry in "${REGISTRY_MAP[@]}"; do
          if [[ "$image" == "$registry/"* ]]; then
            is_cn=true
            break
          fi
        done

        if [[ "$is_cn" == "true" ]]; then
          ((cn_count++))
          echo -e "  ${GREEN}[CN]${NC} $image"
        else
          ((original_count++))
          echo -e "  ${BLUE}[ORIGINAL]${NC} $image"
        fi
      fi
    done < "$file"
  done < <(find "$target" -type f \( -name "docker-compose*.yml" -o -name "docker-compose*.yaml" \))

  echo
  log_info "Summary: $cn_count CN mirror images, $original_count original images"
}

# Usage information
usage() {
  cat <<EOF
${BOLD}Usage:${NC}
  $0 <COMMAND> [OPTIONS] [TARGET]

${BOLD}Commands:${NC}
  --cn              Apply CN mirror transformations
  --restore         Restore original image references
  --dry-run         Preview changes without applying
  --check           Check current image state

${BOLD}Options:${NC}
  -f, --file        Process a single compose file
  -d, --dir         Process all compose files in directory
  -a, --all         Process all stacks in project
  -v, --verbose     Enable verbose output
  -h, --help        Show this help message

${BOLD}Examples:${NC}
  # Apply CN mirrors to all stacks
  $0 --cn --all

  # Preview changes for specific file
  $0 --cn --dry-run -f docker-compose.yml

  # Restore original images in a directory
  $0 --restore -d ./stacks/media

  # Check current image state
  $0 --check --all

${BOLD}Supported Registries:${NC}
EOF
  for registry in "${!REGISTRY_MAP[@]}"; do
    printf "  %-20s -> %s\n" "$registry" "${REGISTRY_MAP[$registry]}"
  done | sort
}

# Main entry point
main() {
  local mode=""
  local dry_run="false"
  local target=""
  local target_type=""
  local VERBOSE="${VERBOSE:-false}"

  if [[ $# -eq 0 ]]; then
    usage
    exit 1
  fi

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --cn)
        mode="cn"
        shift
        ;;
      --restore)
        mode="restore"
        shift
        ;;
      --dry-run)
        dry_run="true"
        shift
        ;;
      --check)
        mode="check"
        shift
        ;;
      -f|--file)
        target="$2"
        target_type="file"
        shift 2
        ;;
      -d|--dir)
        target="$2"
        target_type="dir"
        shift 2
        ;;
      -a|--all)
        target="$PROJECT_ROOT/stacks"
        target_type="dir"
        shift
        ;;
      -v|--verbose)
        VERBOSE="true"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      -*)
        log_error "Unknown option: $1"
        usage
        exit 1
        ;;
      *)
        # Positional argument - treat as target
        if [[ -z "$target" ]]; then
          target="$1"
          if [[ -f "$target" ]]; then
            target_type="file"
          elif [[ -d "$target" ]]; then
            target_type="dir"
          fi
        fi
        shift
        ;;
    esac
  done

  # Validate mode
  if [[ -z "$mode" ]]; then
    log_error "No mode specified. Use --cn, --restore, or --check"
    usage
    exit 1
  fi

  # Load mirror configuration
  parse_yaml_mirrors "$MIRROR_CONFIG"

  # Default to all stacks if no target specified
  if [[ -z "$target" ]]; then
    target="$PROJECT_ROOT/stacks"
    target_type="dir"
    log_info "No target specified, processing all stacks"
  fi

  # Execute based on mode and target type
  case "$mode" in
    check)
      check_images "$target"
      ;;
    cn|restore)
      if [[ "$target_type" == "file" ]]; then
        process_compose_file "$target" "$mode" "$dry_run"
      elif [[ "$target_type" == "dir" ]]; then
        process_directory "$target" "$mode" "$dry_run"
      else
        log_error "Invalid target: $target"
        exit 1
      fi
      ;;
  esac
}

main "$@"
