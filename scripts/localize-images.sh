#!/usr/bin/env bash
# =============================================================================
# Localize Images — 替换 compose 文件中的 gcr.io/ghcr.io 为国内镜像
#
# Usage:
#   ./scripts/localize-images.sh --cn        # Replace with CN mirrors
#   ./scripts/localize-images.sh --restore   # Restore original images
#   ./scripts/localize-images.sh --dry-run   # Preview changes without modifying
#   ./scripts/localize-images.sh --check     # Check if replacement is needed
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.."; pwd)"
MIRROR_MAP="$PROJECT_DIR/config/cn-mirrors.yml"
BACKUP_DIR="$PROJECT_DIR/.image-backup"

# ---------------------------------------------------------------------------
# Parse mirror mapping from cn-mirrors.yml
# ---------------------------------------------------------------------------
declare -A MIRRORS

load_mirrors() {
  if [[ ! -f "$MIRROR_MAP" ]]; then
    log_error "Mirror mapping not found: $MIRROR_MAP"
    exit 1
  fi

  while IFS= read -r line; do
    # Skip comments and empty lines
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    [[ "$line" == "mirrors:" ]] && continue

    # Parse "  original: mirror" format
    if [[ "$line" =~ ^[[:space:]]+([^:]+):[[:space:]]+(.+)$ ]]; then
      local original="${BASH_REMATCH[1]}"
      local mirror="${BASH_REMATCH[2]}"
      # Trim whitespace
      original=$(echo "$original" | xargs)
      mirror=$(echo "$mirror" | xargs)
      MIRRORS["$original"]="$mirror"
    fi
  done < "$MIRROR_MAP"
}

# ---------------------------------------------------------------------------
# Find all compose files
# ---------------------------------------------------------------------------
find_compose_files() {
  find "$PROJECT_DIR/stacks" -name "docker-compose*.yml" -type f | sort
}

# ---------------------------------------------------------------------------
# --cn: Replace images with CN mirrors
# ---------------------------------------------------------------------------
do_cn() {
  local dry_run="${1:-false}"
  local changed=0

  load_mirrors

  if [[ "$dry_run" == "false" ]]; then
    mkdir -p "$BACKUP_DIR"
  fi

  while IFS= read -r file; do
    local rel_path="${file#"$PROJECT_DIR"/}"
    local file_changed=false

    for original in "${!MIRRORS[@]}"; do
      local mirror="${MIRRORS[$original]}"
      if grep -q "$original" "$file"; then
        if [[ "$dry_run" == "true" ]]; then
          echo -e "  ${BLUE}$rel_path${NC}: $original → $mirror"
        else
          # Backup before first modification
          if [[ "$file_changed" == "false" ]]; then
            local backup_path="$BACKUP_DIR/$rel_path"
            mkdir -p "$(dirname "$backup_path")"
            cp "$file" "$backup_path"
          fi
          sed -i "s|${original}|${mirror}|g" "$file"
        fi
        file_changed=true
        ((changed++))
      fi
    done
  done < <(find_compose_files)

  if [[ $changed -eq 0 ]]; then
    log_info "No images to replace. All compose files are clean."
  elif [[ "$dry_run" == "true" ]]; then
    echo ""
    log_info "Found $changed replacement(s). Run with --cn to apply."
  else
    log_info "Replaced $changed image reference(s). Backups saved to $BACKUP_DIR"
  fi
}

# ---------------------------------------------------------------------------
# --restore: Restore original images from backup
# ---------------------------------------------------------------------------
do_restore() {
  if [[ ! -d "$BACKUP_DIR" ]]; then
    log_warn "No backup found at $BACKUP_DIR. Nothing to restore."
    exit 0
  fi

  local restored=0
  while IFS= read -r backup; do
    local rel_path="${backup#"$BACKUP_DIR"/}"
    local target="$PROJECT_DIR/$rel_path"
    if [[ -f "$target" ]]; then
      cp "$backup" "$target"
      log_info "Restored: $rel_path"
      ((restored++))
    fi
  done < <(find "$BACKUP_DIR" -name "docker-compose*.yml" -type f)

  if [[ $restored -eq 0 ]]; then
    log_warn "No files restored."
  else
    log_info "Restored $restored file(s). Removing backup directory."
    rm -rf "$BACKUP_DIR"
  fi
}

# ---------------------------------------------------------------------------
# --check: Report which images need replacement
# ---------------------------------------------------------------------------
do_check() {
  load_mirrors
  local needs_replace=0

  while IFS= read -r file; do
    local rel_path="${file#"$PROJECT_DIR"/}"
    for original in "${!MIRRORS[@]}"; do
      if grep -q "$original" "$file"; then
        echo -e "  ${YELLOW}[NEEDS REPLACE]${NC} $rel_path: $original"
        ((needs_replace++))
      fi
    done
  done < <(find_compose_files)

  if [[ $needs_replace -eq 0 ]]; then
    log_info "All images are already localized (or no gcr.io/ghcr.io images found)."
  else
    echo ""
    log_warn "Found $needs_replace image(s) that can be replaced. Run: $0 --cn"
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
usage() {
  echo "Usage: $0 {--cn|--restore|--dry-run|--check}"
  echo ""
  echo "  --cn        Replace gcr.io/ghcr.io images with CN mirrors"
  echo "  --restore   Restore original images from backup"
  echo "  --dry-run   Preview replacements without modifying files"
  echo "  --check     Check if any images need replacement"
  exit 1
}

[[ $# -lt 1 ]] && usage

case "$1" in
  --cn)      do_cn false ;;
  --restore) do_restore ;;
  --dry-run) do_cn true ;;
  --check)   do_check ;;
  *)         usage ;;
esac
