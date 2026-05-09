#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Image Localization
# Replace gcr.io/ghcr.io with CN mirrors.
# Usage: localize-images.sh [--cn|--restore|--dry-run|--check]
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")
MIRROR_MAP="$ROOT_DIR/config/cn-mirrors.yml"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RESET='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }

ACTION="${1:---dry-run}"

# Find all compose files
COMPOSE_FILES=$(find "$ROOT_DIR/stacks" "$ROOT_DIR/config" -name "docker-compose*.yml" -o -name "docker-compose*.yaml" 2>/dev/null | grep -v '.bak')

case "$ACTION" in
  --cn)
    log_info "Replacing gcr.io/ghcr.io with CN mirrors..."
    for file in $COMPOSE_FILES; do
      # ghcr.io → docker.m.daocloud.io/ghcr.io
      if grep -q 'ghcr.io' "$file" 2>/dev/null; then
        sed -i.bak "s|ghcr.io/|docker.m.daocloud.io/ghcr.io/|g" "$file"
        log_info "  Updated: $file"
      fi
      # gcr.io → docker.m.daocloud.io/gcr.io
      if grep -q 'gcr.io' "$file" 2>/dev/null; then
        sed -i.bak "s|gcr.io/|docker.m.daocloud.io/gcr.io/|g" "$file"
        log_info "  Updated: $file"
      fi
    done
    log_info "Done! Run 'localize-images.sh --restore' to revert."
    ;;
    
  --restore)
    log_info "Restoring original images..."
    for bak in $(find "$ROOT_DIR" -name "*.bak" 2>/dev/null); do
      local orig="${bak%.bak}"
      mv "$bak" "$orig"
      log_info "  Restored: $orig"
    done
    log_info "All files restored."
    ;;
    
  --dry-run)
    log_info "Preview of changes:"
    local count=0
    for file in $COMPOSE_FILES; do
      if grep -qE 'ghcr\.io|gcr\.io' "$file" 2>/dev/null; then
        echo "  $file"
        grep -nE 'ghcr\.io|gcr\.io' "$file" | head -5 | while IFS= read -r line; do
          echo "    $line"
        done
        ((count++))
      fi
    done
    if [ $count -eq 0 ]; then
      log_info "No gcr.io/ghcr.io images found in compose files."
    fi
    ;;
    
  --check)
    local found=0
    for file in $COMPOSE_FILES; do
      found=$((found + $(grep -cE 'ghcr\.io|gcr\.io' "$file" 2>/dev/null || echo 0)))
    done
    if [ $found -gt 0 ]; then
      log_warn "Found $found gcr.io/ghcr.io references. Consider: localize-images.sh --cn"
      exit 1
    else
      log_info "All images already localized."
      exit 0
    fi
    ;;
    
  *)
    echo "Usage: localize-images.sh [--cn|--restore|--dry-run|--check]"
    exit 1
    ;;
esac
