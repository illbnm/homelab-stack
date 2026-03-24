#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Localize Images for CN Network
# Scans docker-compose files for gcr.io/ghcr.io images and replaces them
# with Chinese mirror equivalents that are accessible from mainland China.
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")
STACKS_DIR="$ROOT_DIR/stacks"
BACKUP_DIR="$ROOT_DIR/.localize-backups"

# Registry mapping: blocked -> CN mirror
declare -A REGISTRY_MAP=(
  ["gcr.io"]="gcr.m.daocloud.io"
  ["ghcr.io"]="ghcr.m.daocloud.io"
  ["k8s.gcr.io"]="k8s-gcr.m.daocloud.io"
  ["registry.k8s.io"]="k8s.m.daocloud.io"
  ["quay.io"]="quay.m.daocloud.io"
  ["us-docker.pkg.dev"]="us-docker.m.daocloud.io"
  ["eu-docker.pkg.dev"]="eu-docker.m.daocloud.io"
  ["asia-docker.pkg.dev"]="asia-docker.m.daocloud.io"
  ["docker.io"]="docker.m.daocloud.io"
)

# ---------------------------------------------------------------------------
# Find all compose files
# ---------------------------------------------------------------------------
find_compose_files() {
  find "$STACKS_DIR" -name "docker-compose*.yml" -o -name "docker-compose*.yaml" 2>/dev/null | sort
}

# ---------------------------------------------------------------------------
# Detect which registries are blocked (need localization)
# ---------------------------------------------------------------------------
detect_blocked_registries() {
  local files
  files=$(find_compose_files)
  [[ -z "$files" ]] && { log_warn "No compose files found"; return; }

  declare -A found=()

  while IFS= read -r file; do
    local images
    images=$(grep -E '^\s+image:' "$file" 2>/dev/null | awk '{print $2}' | tr -d "'"\" || true)
    while IFS= read -r img; do
      [[ -z "$img" ]] && continue
      for registry in "${!REGISTRY_MAP[@]}"; do
        if [[ "$img" == *"$registry/"* ]]; then
          found["$registry"]=1
        fi
      done
    done <<< "$images"
  done <<< "$files"

  echo
  echo -e "${BLUE}=== Blocked Registry Detection ===${NC}"
  echo
  log_info "Registries that need CN localization:"

  if [[ ${#found[@]} -eq 0 ]]; then
    log_info "No blocked registries found in compose files."
    return
  fi

  for registry in "${!found[@]}"; do
    local mirror="${REGISTRY_MAP[$registry]}"
    log_warn "  $registry -> $mirror"
  done
}

# ---------------------------------------------------------------------------
# Check if images are accessible
# ---------------------------------------------------------------------------
check_image_access() {
  local files
  files=$(find_compose_files)
  [[ -z "$files" ]] && return

  echo
  echo -e "${BLUE}=== Image Accessibility Check ===${NC}"
  echo

  declare -A checked=()

  while IFS= read -r file; do
    local images
    images=$(grep -E '^\s+image:' "$file" 2>/dev/null | awk '{print $2}' | tr -d "'"\" || true)
    while IFS= read -r img; do
      [[ -z "$img" ]] && continue
      local base_img="${img%%:*}"
      [[ -n "${checked[$base_img]:-}" ]] && continue
      checked["$base_img"]=1

      local blocked=false
      for registry in "${!REGISTRY_MAP[@]}"; do
        if [[ "$img" == *"$registry/"* ]]; then
          blocked=true
          break
        fi
      done

      if $blocked; then
        # Try to resolve via mirror
        local translated
        translated=$(translate_image "$img")
        log_warn "BLOCKED:  $img"
        log_info "  MIRROR: $translated"
        # Try manifest check
        if docker manifest inspect "$translated" &>/dev/null; then
          log_info "  STATUS: mirror accessible ✓"
        else
          log_warn "  STATUS: mirror unverified (may still work at pull time)"
        fi
      else
        log_info "OK:     $img"
      fi
    done <<< "$images"
  done <<< "$files"
}

# ---------------------------------------------------------------------------
# Translate image name to mirror equivalent
# ---------------------------------------------------------------------------
translate_image() {
  local image=$1
  for registry in "${!REGISTRY_MAP[@]}"; do
    if [[ "$image" == *"$registry/"* ]]; then
      echo "${image/$registry/${REGISTRY_MAP[$registry]}}"
      return
    fi
  done
  echo "$image"
}

# ---------------------------------------------------------------------------
# Localize compose files (replace blocked registries)
# ---------------------------------------------------------------------------
localize_files() {
  local files
  files=$(find_compose_files)
  [[ -z "$files" ]] && { log_warn "No compose files found"; return; }

  mkdir -p "$BACKUP_DIR"

  local modified=0
  while IFS= read -r file; do
    local rel_path="${file#$ROOT_DIR/}"

    # Check if file needs changes
    local needs_change=false
    for registry in "${!REGISTRY_MAP[@]}"; do
      if grep -q "image:.*${registry}/" "$file" 2>/dev/null; then
        needs_change=true
        break
      fi
    done
    $needs_change || continue

    # Backup
    local backup_file="$BACKUP_DIR/$(basename "$(dirname "$file")")-$(basename "$file").bak.$(date +%Y%m%d_%H%M%S)"
    cp "$file" "$backup_file"
    log_info "Backed up: $rel_path -> $(basename "$backup_file")"

    # Replace registries
    local changes=0
    for registry in "${!REGISTRY_MAP[@]}"; do
      local mirror="${REGISTRY_MAP[$registry]}"
      if grep -q "$registry/" "$file" 2>/dev/null; then
        sed -i "s|${registry}/|${mirror}/|g" "$file"
        ((changes++))
      fi
    done

    if [[ $changes -gt 0 ]]; then
      log_info "Localized: $rel_path ($changes registry replacements)"
      ((modified++))
    fi
  done <<< "$files"

  echo
  log_info "Localized $modified compose file(s)"
  log_info "Backups saved to: $BACKUP_DIR"
}

# ---------------------------------------------------------------------------
# Restore compose files from backups
# ---------------------------------------------------------------------------
restore_files() {
  if [[ ! -d "$BACKUP_DIR" ]]; then
    log_error "No backup directory found at $BACKUP_DIR"
    exit 1
  fi

  local files
  files=$(find "$BACKUP_DIR" -name "*.bak.*" -type f 2>/dev/null | sort)
  [[ -z "$files" ]] && { log_warn "No backup files found"; return; }

  echo
  echo -e "${BLUE}=== Restoring Localized Files ===${NC}"
  echo

  local restored=0
  while IFS= read -r backup; do
    # Extract original path: basename is <dir>-<file>.bak.<timestamp>
    local fname
    fname=$(basename "$backup")
    # Remove .bak.<timestamp> suffix
    local original_name="${fname%%.bak.*}"
    # Restore to its stack directory
    local stack_name
    stack_name=$(dirname "$backup" | sed 's|.*/||')
    # The backup filename format is <stack>-<compose_file>.bak.<ts>
    # Find the original file
    local original_file
    original_file=$(find "$STACKS_DIR" -name "$original_name" -type f 2>/dev/null | head -1)

    if [[ -n "$original_file" ]]; then
      cp "$backup" "$original_file"
      log_info "Restored: $(basename "$original_file")"
      ((restored++))
    fi
  done <<< "$files"

  log_info "Restored $restored file(s)"
}

# ---------------------------------------------------------------------------
# Dry-run: show what would change
# ---------------------------------------------------------------------------
dry_run() {
  local files
  files=$(find_compose_files)
  [[ -z "$files" ]] && { log_warn "No compose files found"; return; }

  echo
  echo -e "${BLUE}=== Dry Run — Proposed Changes ===${NC}"
  echo

  local total=0
  while IFS= read -r file; do
    local rel_path="${file#$ROOT_DIR/}"
    local file_changes=0

    for registry in "${!REGISTRY_MAP[@]}"; do
      local mirror="${REGISTRY_MAP[$registry]}"
      local matches
      matches=$(grep -n "image:.*${registry}/" "$file" 2>/dev/null || true)
      if [[ -n "$matches" ]]; then
        echo -e "${YELLOW}$rel_path${NC}:"
        while IFS= read -r line; do
          local line_num
          line_num=$(echo "$line" | cut -d: -f1)
          local content
          content=$(echo "$line" | cut -d: -f2-)
          local new_content
          new_content=$(echo "$content" | sed "s|${registry}/|${mirror}/|g")
          echo "  L${line_num}: $(echo "$content" | sed 's/^\s*//')"
          echo "    -> $(echo "$new_content" | sed 's/^\s*//')"
          ((file_changes++))
        done <<< "$matches"
      fi
    done
    total=$((total + file_changes))
  done <<< "$files"

  echo
  log_info "Total image references that would be changed: $total"
  log_info "Run without --dry-run to apply changes"
}

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Localize Docker Compose images for CN network (replace blocked registries).

Options:
  --cn           Apply localization (replace blocked registries)
  --restore      Restore compose files from backups
  --dry-run      Show proposed changes without applying
  --check        Check which registries are blocked
  --accessibility  Test image accessibility (slow)
  -h, --help     Show this help

Examples:
  $0 --check        # See which registries need localization
  $0 --dry-run      # Preview changes
  $0 --cn           # Apply localization
  $0 --restore      # Undo changes
EOF
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  echo
  echo -e "${BLUE}=== HomeLab Stack — Image Localizer ===${NC}"
  echo

  local action="${1:-}"
  case "$action" in
    --cn)           localize_files ;;
    --restore)      restore_files ;;
    --dry-run)      dry_run ;;
    --check)        detect_blocked_registries ;;
    --accessibility) check_image_access ;;
    -h|--help)      usage; exit 0 ;;
    *)
      log_error "No action specified"
      usage
      exit 1
      ;;
  esac
}

main "$@"
