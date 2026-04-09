#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Image Localization Script
# Replaces gcr.io/ghcr.io images with CN mirrors in all compose files.
#
# Usage:
#   ./scripts/localize-images.sh --cn        # Replace with CN mirrors
#   ./scripts/localize-images.sh --restore   # Restore original images
#   ./scripts/localize-images.sh --dry-run   # Preview changes
#   ./scripts/localize-images.sh --check     # Check if replacement needed
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")
MIRROR_CONFIG="${ROOT_DIR}/config/cn-mirrors.yml"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

MODE=""
for arg in "$@"; do
  case "$arg" in
    --cn)      MODE=cn ;;
    --restore) MODE=restore ;;
    --dry-run) MODE=dry-run ;;
    --check)   MODE=check ;;
    --help)    echo "Usage: $0 --cn|--restore|--dry-run|--check"; exit 0 ;;
  esac
done

if [ -z "$MODE" ]; then
  echo "Usage: $0 --cn|--restore|--dry-run|--check"
  exit 1
fi

# Parse cn-mirrors.yml into associative arrays
declare -A MIRROR_MAP
if [ -f "$MIRROR_CONFIG" ]; then
  while IFS=': ' read -r key value; do
    # Skip comments and empty lines
    [[ "$key" =~ ^#.* ]] && continue
    [[ -z "$key" ]] && continue
    # Trim whitespace
    key=$(echo "$key" | xargs)
    value=$(echo "$value" | xargs)
    [ -n "$key" ] && [ -n "$value" ] && MIRROR_MAP["$key"]="$value"
  done < <(grep -v '^#' "$MIRROR_CONFIG" | grep -v '^$' | grep -v '^mirrors:' | grep ':')
fi

# Backup directory
BACKUP_DIR="${ROOT_DIR}/.image-backups"

# Find all docker-compose files
COMPOSE_FILES=$(find "$ROOT_DIR" -name "docker-compose.yml" -o -name "docker-compose.yaml" | sort)

count_changes() {
  local total=0
  for f in $COMPOSE_FILES; do
    for orig in "${!MIRROR_MAP[@]}"; do
      # Match "image: org/image" or "image: org/image:tag"
      count=$(grep -c "image:.*${orig}" "$f" 2>/dev/null || echo 0)
      total=$((total + count))
    done
  done
  echo "$total"
}

case "$MODE" in
  check)
    echo "Checking for images that need CN mirror replacement..."
    echo
    found=0
    for f in $COMPOSE_FILES; do
      for orig in "${!MIRROR_MAP[@]}"; do
        if grep -q "image:.*${orig}" "$f" 2>/dev/null; then
          lines=$(grep "image:.*${orig}" "$f")
          for line in $lines; do
            img=$(echo "$line" | sed 's/.*image:\s*//' | tr -d '"' | tr -d "'")
            printf "  ${YELLOW}[CN-NEED]${NC} %-50s → %s\n" "$img" "${MIRROR_MAP[$orig]}"
            found=$((found + 1))
          done
        fi
      done
    done

    echo
    if [ "$found" -gt 0 ]; then
      log_info "Found $found images that can be localized."
      log_info "Run: $0 --cn  to replace, or  $0 --dry-run  to preview."
    else
      log_info "No images need localization."
    fi
    ;;

  dry-run)
    echo "Previewing CN mirror replacements..."
    echo
    for f in $COMPOSE_FILES; do
      file_changed=false
      for orig in "${!MIRROR_MAP[@]}"; do
        if grep -q "image:.*${orig}" "$f" 2>/dev/null; then
          if ! $file_changed; then
            echo "--- $(realpath --relative-to="$ROOT_DIR" "$f")"
            file_changed=true
          fi
          grep "image:.*${orig}" "$f" | while read -r line; do
            img=$(echo "$line" | sed 's/.*image:\s*//' | tr -d '"' | tr -d "'")
            new_img="${MIRROR_MAP[$orig]}"
            # Preserve tag
            if [[ "$img" == *":"* ]]; then
              tag="${img##*:}"
              new_img="${new_img}:${tag}"
            fi
            printf "  ${RED}- ${img}${NC}\n"
            printf "  ${GREEN}+ ${new_img}${NC}\n"
          done
        fi
      done
    done
    ;;

  cn)
    # Create backups
    mkdir -p "$BACKUP_DIR"
    total=0
    for f in $COMPOSE_FILES; do
      rel_path=$(realpath --relative-to="$ROOT_DIR" "$f")
      backup_path="${BACKUP_DIR}/${rel_path//\//_}"
      cp "$f" "$backup_path"

      file_changed=false
      for orig in "${!MIRROR_MAP[@]}"; do
        if grep -q "image:.*${orig}" "$f" 2>/dev/null; then
          file_changed=true
          # Replace the image in file, preserving tags
          while IFS= read -r line; do
            img=$(echo "$line" | sed 's/.*image:\s*//' | tr -d '"' | tr -d "'")
            new_img="${MIRROR_MAP[$orig]}"
            if [[ "$img" == *":"* ]]; then
              tag="${img##*:}"
              new_img="${new_img}:${tag}"
            fi
            # Replace in file
            sed -i "s|image:.*${img}|image: ${new_img}|" "$f"
            total=$((total + 1))
          done < <(grep "image:.*${orig}" "$f")
        fi
      done
      if $file_changed; then
        log_info "Updated: $rel_path"
      fi
    done
    log_info "Replaced $total images with CN mirrors."
    log_info "Backups saved to $BACKUP_DIR/"
    log_info "To restore: $0 --restore"
    ;;

  restore)
    if [ ! -d "$BACKUP_DIR" ]; then
      log_error "No backup directory found at $BACKUP_DIR"
      exit 1
    fi
    restored=0
    for backup in "$BACKUP_DIR"/*; do
      [ -f "$backup" ] || continue
      basename=$(basename "$backup")
      # Reconstruct path
      for f in $COMPOSE_FILES; do
        rel_path=$(realpath --relative-to="$ROOT_DIR" "$f")
        expected_name="${rel_path//\//_}"
        if [ "$basename" = "$expected_name" ]; then
          cp "$backup" "$f"
          log_info "Restored: $rel_path"
          restored=$((restored + 1))
        fi
      done
    done
    if [ "$restored" -gt 0 ]; then
      log_info "Restored $restored files from backup."
      rm -rf "$BACKUP_DIR"
      log_info "Removed backup directory."
    else
      log_warn "No matching backups found."
    fi
    ;;
esac
