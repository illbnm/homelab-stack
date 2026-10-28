#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$ROOT_DIR/config/cn-mirrors.yml"
BACKUP_DIR="$ROOT_DIR/.image_backups"

usage() {
  echo "Usage: $0 [OPTION]"
  echo "  --cn        Replace gcr.io/ghcr.io with CN mirror acceleration"
  echo "  --restore   Restore original compose files from backup"
  echo "  --dry-run   Preview image replacements without modifying files"
  echo "  --check     Check if compose files contain gcr.io/ghcr.io images"
  exit 1
}

MODE=${1:-""}
[ -z "$MODE" ] && usage

if [ "$MODE" = "--check" ]; then
  echo "Checking for foreign registry images in stacks/..."
  FOUND=0
  while IFS= read -r f; do
    if grep -E 'image:\s*(gcr\.io|ghcr\.io)' "$f" >/dev/null 2>&1; then
      echo "  [FOUND] $f"
      FOUND=1
    fi
  done < <(find "$ROOT_DIR/stacks" -type f -name "docker-compose*.yml")
  if [ $FOUND -eq 1 ]; then
    echo "Foreign registries detected. Run './scripts/localize-images.sh --cn' to localize."
    exit 1
  else
    echo "No unlocalized foreign images found."
    exit 0
  fi
fi

if [ "$MODE" = "--dry-run" ]; then
  echo "Dry-run mode: Simulating replacement of gcr.io/ghcr.io -> m.daocloud.io"
  find "$ROOT_DIR/stacks" -type f -name "docker-compose*.yml" -exec grep -H -E 'image:\s*(gcr\.io|ghcr\.io)' {} + || true
  exit 0
fi

if [ "$MODE" = "--restore" ]; then
  if [ ! -d "$BACKUP_DIR" ]; then
    echo "Error: No backup directory found at $BACKUP_DIR"
    exit 1
  fi
  echo "Restoring docker-compose files from $BACKUP_DIR..."
  cp -r "$BACKUP_DIR"/* "$ROOT_DIR/stacks/"
  rm -rf "$BACKUP_DIR"
  echo "Restoration complete."
  exit 0
fi

if [ "$MODE" = "--cn" ]; then
  mkdir -p "$BACKUP_DIR"
  echo "Creating backup of stacks/ into $BACKUP_DIR..."
  cp -r "$ROOT_DIR/stacks"/* "$BACKUP_DIR/"

  echo "Localizing docker-compose images in $ROOT_DIR/stacks..."
  while IFS= read -r f; do
    # Replace ghcr.io and gcr.io with m.daocloud.io mirror
    sed -i 's|ghcr\.io/|m.daocloud.io/ghcr.io/|g' "$f"
    sed -i 's|gcr\.io/|m.daocloud.io/gcr.io/|g' "$f"
    sed -i 's|registry\.k8s\.io/|m.daocloud.io/registry.k8s.io/|g' "$f"
    echo "Localized: $f"
  done < <(find "$ROOT_DIR/stacks" -type f -name "docker-compose*.yml")

  echo " [SUCCESS] All stack compose images localized for China mainland."
fi
