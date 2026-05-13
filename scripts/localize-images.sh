#!/usr/bin/env bash
# Localize Docker images for China mainland
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILES=$(find "$ROOT_DIR/stacks" -name "docker-compose.yml")

ACTION="${1:---help}"

case "$ACTION" in
  --cn)
    echo "Replacing images with CN mirrors..."
    for f in $COMPOSE_FILES; do
      sed -i 's|gcr.io/|m.daocloud.io/gcr.io/|g' "$f"
      sed -i 's|ghcr.io/|m.daocloud.io/ghcr.io/|g' "$f"
    done
    echo "✓ All images replaced with CN mirrors"
    ;;
  --restore)
    echo "Restoring original images..."
    for f in $COMPOSE_FILES; do
      sed -i 's|m.daocloud.io/gcr.io/|gcr.io/|g' "$f"
      sed -i 's|m.daocloud.io/ghcr.io/|ghcr.io/|g' "$f"
    done
    echo "✓ Original images restored"
    ;;
  --dry-run)
    echo "Would replace in these files:"
    for f in $COMPOSE_FILES; do
      matches=$(grep -c "gcr.io\|ghcr.io" "$f" 2>/dev/null || echo 0)
      if [ "$matches" -gt 0 ]; then
        echo "  $f ($matches images)"
      fi
    done
    ;;
  --check)
    needs_replace=false
    for f in $COMPOSE_FILES; do
      if grep -q "gcr.io\|ghcr.io" "$f" 2>/dev/null; then
        needs_replace=true
        break
      fi
    done
    if [ "$needs_replace" = true ]; then
      echo "⚠️  Found gcr.io/ghcr.io images - run with --cn to replace"
    else
      echo "✓ All images already using CN mirrors or Docker Hub"
    fi
    ;;
  *)
    echo "Usage: localize-images.sh [--cn|--restore|--dry-run|--check]"
    ;;
esac
