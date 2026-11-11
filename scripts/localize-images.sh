#!/usr/bin/env bash
# Usage: ./scripts/localize-images.sh [--cn|--restore|--dry-run|--check]
# Replaces or restores gcr.io / ghcr.io / lscr.io images across stacks/*/docker-compose.yml.
set -euo pipefail

MODE=""
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STACKS_DIR="${STACKS_DIR:-${ROOT_DIR}/stacks}"

for arg in "$@"; do
  case "$arg" in
    --cn|--restore|--dry-run|--check) MODE="$arg" ;;
    *)
      echo "Usage: $0 [--cn|--restore|--dry-run|--check]" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$MODE" ]]; then
  echo "Usage: $0 [--cn|--restore|--dry-run|--check]" >&2
  exit 1
fi

mapfile -t COMPOSE_FILES < <(find "$STACKS_DIR" -maxdepth 2 -name "docker-compose.yml" 2>/dev/null | sort)

case "$MODE" in
  --check)
    unlocalized=0
    for f in "${COMPOSE_FILES[@]}"; do
      if grep -Eq '^[[:space:]]*image:[[:space:]]*(gcr\.io|ghcr\.io|lscr\.io)/' "$f"; then
        echo "[NEED-REPLACE] $f"
        unlocalized=$((unlocalized + 1))
      fi
    done
    echo "[CHECK] Compose files with direct gcr.io/ghcr.io/lscr.io references: ${unlocalized}"
    exit 0
    ;;
  --dry-run)
    for f in "${COMPOSE_FILES[@]}"; do
      echo "[DRY-RUN] Checking $f"
      grep -En '^[[:space:]]*image:[[:space:]]*(gcr\.io|ghcr\.io|lscr\.io)/' "$f" || true
    done
    exit 0
    ;;
  --cn)
    for f in "${COMPOSE_FILES[@]}"; do
      sed -i.bak -E \
        -e 's|^([[:space:]]*image:[[:space:]]*)gcr\.io/|\1m.daocloud.io/gcr.io/|g' \
        -e 's|^([[:space:]]*image:[[:space:]]*)ghcr\.io/|\1m.daocloud.io/ghcr.io/|g' \
        -e 's|^([[:space:]]*image:[[:space:]]*)lscr\.io/|\1m.daocloud.io/lscr.io/|g' \
        "$f"
      rm -f "${f}.bak"
      echo "[CN-MIRROR] Updated $f"
    done
    ;;
  --restore)
    for f in "${COMPOSE_FILES[@]}"; do
      sed -i.bak -E \
        -e 's|^([[:space:]]*image:[[:space:]]*)m\.daocloud\.io/gcr\.io/|\1gcr.io/|g' \
        -e 's|^([[:space:]]*image:[[:space:]]*)m\.daocloud\.io/ghcr\.io/|\1ghcr.io/|g' \
        -e 's|^([[:space:]]*image:[[:space:]]*)m\.daocloud\.io/lscr\.io/|\1lscr.io/|g' \
        "$f"
      rm -f "${f}.bak"
      echo "[RESTORED] Restored $f"
    done
    ;;
esac
