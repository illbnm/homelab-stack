#!/usr/bin/env bash
# =============================================================================
# localize-images.sh — Replace foreign container images with CN mirrors
# Automatically replaces gcr.io/ghcr.io/registry.k8s.io images with China mirrors
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()  { echo -e "\n${BLUE}${BOLD}==> $*${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.."; pwd)"
MIRROR_CONFIG="$PROJECT_ROOT/config/cn-mirrors.yml"
BACKUP_DIR="$PROJECT_ROOT/.backups"

# Default compose directories
COMPOSE_DIRS=(
  "$PROJECT_ROOT/stacks"
  "$PROJECT_ROOT"
)

# Mirror mapping (loaded from YAML)
declare -A MIRROR_MAP

# ---------------------------------------------------------------------------
# Load mirror configuration from YAML
# ---------------------------------------------------------------------------
load_mirror_config() {
  if [[ ! -f "$MIRROR_CONFIG" ]]; then
    log_error "Mirror configuration not found: $MIRROR_CONFIG"
    exit 1
  fi

  log_info "Loading mirror configuration..."

  # Parse YAML and build associative array
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^# ]] && continue
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue

    # Extract key-value pairs from YAML
    if [[ "$line" =~ ^[[:space:]]+([^:]+):[[:space:]]+(.+)$ ]]; then
      local key="${BASH_REMATCH[1]}"
      local value="${BASH_REMATCH[2]}"
      # Trim whitespace
      key=$(echo "$key" | xargs)
      value=$(echo "$value" | xargs)
      MIRROR_MAP["$key"]="$value"
    fi
  done < "$MIRROR_CONFIG"

  log_info "Loaded ${#MIRROR_MAP[@]} mirror mappings"
}

# ---------------------------------------------------------------------------
# Create backup of original files
# ---------------------------------------------------------------------------
create_backup() {
  local file=$1
  mkdir -p "$BACKUP_DIR"
  local backup_name
  backup_name=$(basename "$file").backup.$(date +%Y%m%d_%H%M%S)
  cp "$file" "$BACKUP_DIR/$backup_name"
  log_info "Backup created: $BACKUP_DIR/$backup_name"
}

# ---------------------------------------------------------------------------
# Restore from backup
# ---------------------------------------------------------------------------
restore_backup() {
  if [[ ! -d "$BACKUP_DIR" ]]; then
    log_error "No backups found in $BACKUP_DIR"
    exit 1
  fi

  local latest_backup
  latest_backup=$(ls -t "$BACKUP_DIR"/docker-compose*.backup.* 2>/dev/null | head -1)

  if [[ -z "$latest_backup" ]]; then
    log_error "No backup files found"
    exit 1
  fi

  log_info "Restoring from: $latest_backup"
  # This is simplified - in production you'd want to track which file each backup came from
  log_warn "Manual restoration required. Backup files are in: $BACKUP_DIR"
  ls -lh "$BACKUP_DIR"
}

# ---------------------------------------------------------------------------
# Replace image in a single file
# ---------------------------------------------------------------------------
localize_file() {
  local file=$1
  local dry_run=${2:-false}
  local changes=0

  if [[ ! -f "$file" ]]; then
    log_warn "File not found: $file"
    return 0
  fi

  log_info "Processing: $file"

  # Check if file contains any foreign registries
  if ! grep -qE 'image:.*(gcr\.io|ghcr\.io|k8s\.gcr\.io|registry\.k8s\.io|quay\.io)' "$file"; then
    log_info "  No foreign registries found"
    return 0
  fi

  # Create temporary file
  local tmp_file
  tmp_file=$(mktemp)

  # Process line by line
  while IFS= read -r line; do
    local modified_line="$line"

    # Check if line contains an image reference
    if [[ "$line" =~ image: ]]; then
      # Extract image name
      local image
      image=$(echo "$line" | sed -n 's/.*image:[[:space:]]*["\x27]?\([^"'\''[:space:]]*\).*/\1/p')

      if [[ -n "$image" ]]; then
        # Check if we have a mirror mapping
        for key in "${!MIRROR_MAP[@]}"; do
          if [[ "$image" == "$key"* ]]; then
            local mirror="${MIRROR_MAP[$key]}"
            local new_image="${image/$key/$mirror}"

            if [[ "$dry_run" == "true" ]]; then
              log_info "  [DRY-RUN] Would replace: $image -> $new_image"
            else
              modified_line="${line/$image/$new_image}"
              log_info "  Replaced: $image -> $new_image"
            fi
            ((changes++))
            break
          fi
        done
      fi
    fi

    echo "$modified_line" >> "$tmp_file"
  done < "$file"

  # Apply changes if not dry run and changes were made
  if [[ "$dry_run" == "false" && $changes -gt 0 ]]; then
    create_backup "$file"
    mv "$tmp_file" "$file"
    log_info "  Applied $changes changes to $file"
  else
    rm -f "$tmp_file"
  fi

  return $changes
}

# ---------------------------------------------------------------------------
# Find all compose files
# ---------------------------------------------------------------------------
find_compose_files() {
  local files=()

  for dir in "${COMPOSE_DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
      while IFS= read -r -d '' file; do
        files+=("$file")
      done < <(find "$dir" -type f \( -name "docker-compose*.yml" -o -name "docker-compose*.yaml" \) -print0)
    fi
  done

  printf '%s\n' "${files[@]}"
}

# ---------------------------------------------------------------------------
# Check if localization is needed
# ---------------------------------------------------------------------------
check_localization() {
  log_step "Checking if image localization is needed"

  local needs_localization=false

  while IFS= read -r file; do
    if grep -qE 'image:.*(gcr\.io|ghcr\.io|k8s\.gcr\.io|registry\.k8s\.io|quay\.io)' "$file"; then
      log_warn "Foreign registries found in: $file"
      grep -E 'image:.*(gcr\.io|ghcr\.io|k8s\.gcr\.io|registry\.k8s\.io|quay\.io)' "$file" || true
      needs_localization=true
    fi
  done < <(find_compose_files)

  if [[ "$needs_localization" == "true" ]]; then
    echo ""
    log_warn "Run './scripts/localize-images.sh --cn' to replace with CN mirrors"
    return 1
  else
    log_info "All images already using accessible registries"
    return 0
  fi
}

# ---------------------------------------------------------------------------
# Main operations
# ---------------------------------------------------------------------------
do_localize() {
  local dry_run=${1:-false}

  load_mirror_config

  log_step "${BOLD}Localizing container images for China network${NC}"
  [[ "$dry_run" == "true" ]] && log_info "DRY RUN MODE - No files will be modified"

  local total_changes=0

  while IFS= read -r file; do
    localize_file "$file" "$dry_run"
    total_changes=$((total_changes + $?))
  done < <(find_compose_files)

  if [[ "$dry_run" == "false" && $total_changes -gt 0 ]]; then
    log_info ""
    log_info "${GREEN}Localization complete! $total_changes image(s) replaced.${NC}"
    log_info "Backups saved in: $BACKUP_DIR"
    log_info ""
    log_warn "Next steps:"
    log_warn "  1. Review changes: git diff stacks/"
    log_warn "  2. Pull images: ./scripts/cn-pull.sh --all"
    log_warn "  3. Deploy stacks: ./scripts/stack-manager.sh start <stack>"
  fi
}

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Replace foreign container images with China-accessible mirrors.

Options:
  --cn        Apply CN mirror replacements
  --restore   Restore original files from backup
  --dry-run   Preview changes without modifying files
  --check     Check if localization is needed
  -h, --help  Show this help message

Examples:
  # Preview what would be changed
  $0 --dry-run

  # Apply CN mirror replacements
  $0 --cn

  # Check if images need localization
  $0 --check

  # Restore original files
  $0 --restore

Mirror mapping is configured in: config/cn-mirrors.yml
EOF
  exit 1
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  local mode="${1:-}"

  case $mode in
    --cn)
      do_localize false
      ;;
    --dry-run)
      do_localize true
      ;;
    --check)
      check_localization
      ;;
    --restore)
      restore_backup
      ;;
    -h|--help)
      usage
      ;;
    *)
      log_error "Invalid option: $mode"
      usage
      ;;
  esac
}

main "$@"
