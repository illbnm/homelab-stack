#!/usr/bin/env bash
# =============================================================================
# Localize Images in Compose Files
# =============================================================================
set -e

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MIRRORS_FILE="$BASE_DIR/config/cn-mirrors.yml"

if [ ! -f "$MIRRORS_FILE" ]; then
  echo "Error: $MIRRORS_FILE not found."
  exit 1
fi

ACTION=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cn) ACTION="cn"; shift ;;
    --restore) ACTION="restore"; shift ;;
    --dry-run) ACTION="dry-run"; shift ;;
    --check) ACTION="check"; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [ -z "$ACTION" ]; then
  echo "Usage: $0 [--cn | --restore | --dry-run | --check]"
  exit 1
fi

declare -A MAP
declare -A REVERSE_MAP

while IFS=":" read -r orig mirror; do
  orig=$(echo "$orig" | xargs)
  mirror=$(echo "$mirror" | xargs)
  if [[ "$orig" != "mirrors" && -n "$orig" && ! "$orig" =~ ^# ]]; then
    MAP["$orig"]="$mirror"
    REVERSE_MAP["$mirror"]="$orig"
  fi
done < "$MIRRORS_FILE"

find_files() {
  find "$BASE_DIR" -name "docker-compose*.yml" -type f
}

if [ "$ACTION" == "check" ]; then
  NEEDS_REPLACE=0
  for f in $(find_files); do
    for orig in "${!MAP[@]}"; do
      if grep -q "image:.*$orig" "$f"; then
        echo "Needs replacement in $f: $orig"
        NEEDS_REPLACE=1
      fi
    done
  done
  if [ $NEEDS_REPLACE -eq 0 ]; then
    echo "No gcr.io/ghcr.io images found that need replacing."
  fi
  exit $NEEDS_REPLACE
fi

if [ "$ACTION" == "dry-run" ]; then
  echo "Dry run - would modify:"
  for f in $(find_files); do
    for orig in "${!MAP[@]}"; do
      mirror="${MAP[$orig]}"
      if grep -q "$orig" "$f"; then
        echo "  $f: $orig -> $mirror"
      fi
    done
  done
  exit 0
fi

if [ "$ACTION" == "cn" ]; then
  echo "Replacing with domestic mirrors..."
  for f in $(find_files); do
    for orig in "${!MAP[@]}"; do
      mirror="${MAP[$orig]}"
      if sed --version 2>/dev/null | grep -q GNU; then
        sed -i "s|$orig|$mirror|g" "$f"
      else
        sed -i '' "s|$orig|$mirror|g" "$f"
      fi
    done
  done
  echo "Done."
  exit 0
fi

if [ "$ACTION" == "restore" ]; then
  echo "Restoring original images..."
  for f in $(find_files); do
    for mirror in "${!REVERSE_MAP[@]}"; do
      orig="${REVERSE_MAP[$mirror]}"
      if sed --version 2>/dev/null | grep -q GNU; then
        sed -i "s|$mirror|$orig|g" "$f"
      else
        sed -i '' "s|$mirror|$orig|g" "$f"
      fi
    done
  done
  echo "Done."
  exit 0
fi
