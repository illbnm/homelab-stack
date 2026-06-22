#!/usr/bin/env bash
# =============================================================================
# HomeLab Backup — Docker volumes + configs 3-2-1 Restic Backup
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$SCRIPT_DIR/.."
ENV_FILE="$BASE_DIR/config/.env"

if [[ -f "$ENV_FILE" ]]; then
  source "$ENV_FILE"
else
  # If running from a different directory structure, fallback
  ENV_FILE="$BASE_DIR/.env"
  [[ -f "$ENV_FILE" ]] && source "$ENV_FILE"
fi

TARGET=""
DRY_RUN="false"
RESTORE_ID=""
LIST="false"
VERIFY="false"

while [[ $# -gt 0 ]]; do
  case $1 in
    --target) TARGET="$2"; shift 2 ;;
    --dry-run) DRY_RUN="true"; shift ;;
    --restore) RESTORE_ID="$2"; shift 2 ;;
    --list) LIST="true"; shift ;;
    --verify) VERIFY="true"; shift ;;
    *) echo "Unknown parameter $1"; exit 1 ;;
  esac
done

BACKUP_TARGET=${BACKUP_TARGET:-local}

if [ "$BACKUP_TARGET" = "local" ]; then
  # Local restic server running in proxy network
  RESTIC_REPO="rest:http://restic-server:8000/"
elif [ "$BACKUP_TARGET" = "s3" ] || [ "$BACKUP_TARGET" = "b2" ] || [ "$BACKUP_TARGET" = "sftp" ]; then
  RESTIC_REPO="${RESTIC_REPOSITORY:-}"
fi

export RESTIC_PASSWORD="${RESTIC_PASSWORD:-}"
if [ -z "${RESTIC_PASSWORD:-}" ]; then
  echo "Error: RESTIC_PASSWORD not set in .env"
  exit 1
fi

export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-}"

restic_cmd() {
  docker run --rm \
    --network proxy \
    -e RESTIC_PASSWORD="$RESTIC_PASSWORD" \
    -e RESTIC_REPOSITORY="$RESTIC_REPO" \
    -e AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
    -e AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
    restic/restic:0.16.3 "$@"
}

restic_config() {
  docker run --rm \
    --network proxy \
    -e RESTIC_PASSWORD="$RESTIC_PASSWORD" \
    -e RESTIC_REPOSITORY="$RESTIC_REPO" \
    -e AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
    -e AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
    -v "$BASE_DIR:/config_data:ro" \
    restic/restic:0.16.3 "$@"
}

restic_volume() {
  local vol=$1
  shift
  docker run --rm \
    --network proxy \
    -e RESTIC_PASSWORD="$RESTIC_PASSWORD" \
    -e RESTIC_REPOSITORY="$RESTIC_REPO" \
    -e AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
    -e AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
    -v "${vol}:/data" \
    restic/restic:0.16.3 "$@"
}

notify() {
  local title=$1
  local msg=$2
  if [ -x "$SCRIPT_DIR/notify.sh" ]; then
    "$SCRIPT_DIR/notify.sh" "backup" "$title" "$msg" || true
  fi
}

# Ensure repo is initialized
if ! restic_cmd snapshots >/dev/null 2>&1; then
  echo "Initializing restic repository..."
  if ! restic_cmd init; then
    echo "Notice: Repository might already be initialized or an error occurred."
  fi
fi

if [ "$LIST" = "true" ]; then
  restic_cmd snapshots
  exit 0
fi

if [ "$VERIFY" = "true" ]; then
  restic_cmd check
  exit 0
fi

if [ -n "$RESTORE_ID" ]; then
  if [ -z "$TARGET" ]; then
    echo "Error: --target must be specified for restore. e.g. --target media"
    exit 1
  fi
  echo "Restoring $TARGET from backup $RESTORE_ID..."
  
  if [ "$TARGET" = "configs" ] || [ "$TARGET" = "all" ]; then
    echo "To restore configs, run restic locally. Automatic restore of configs is not supported via this script."
    exit 1
  fi

  # Support restoring a single volume (target is exact volume name) or all volumes for a stack
  VOLUMES=$(docker volume ls --format '{{.Name}}' | grep "^${TARGET}_" || true)
  if [ -z "$VOLUMES" ]; then
    echo "No volumes found for target $TARGET, attempting to restore exactly volume: $TARGET"
    VOLUMES="$TARGET"
  fi

  for vol in $VOLUMES; do
    echo "Restoring volume: $vol"
    restic_volume "$vol" restore "$RESTORE_ID" --target /
  done
  
  notify "Restore Success" "Restored backup $RESTORE_ID for target $TARGET"
  exit 0
fi

if [ -z "$TARGET" ]; then
  echo "Error: --target <stack|all> is required"
  echo "Usage: $0 --target <stack|all> [options]"
  exit 1
fi

backup_volume() {
  local vol=$1
  echo "Backing up volume: $vol"
  if [ "$DRY_RUN" = "true" ]; then
    restic_volume "$vol" backup --dry-run /data --tag "$vol"
  else
    if restic_volume "$vol" backup /data --tag "$vol"; then
      echo "Successfully backed up $vol"
    else
      echo "Failed to back up $vol"
      notify "Backup Failed" "Failed to backup $vol"
      exit 1
    fi
  fi
}

VOLUMES=""
if [ "$TARGET" = "all" ]; then
  VOLUMES=$(docker volume ls --format '{{.Name}}' | grep -v '^[a-f0-9]\{64\}$' || true)
else
  VOLUMES=$(docker volume ls --format '{{.Name}}' | grep "^${TARGET}_" || true)
  if [ -z "$VOLUMES" ]; then
    echo "No volumes found for stack $TARGET. If it's a specific volume, we'll try that."
    VOLUMES="$TARGET"
  fi
fi

echo "Starting backup for target: $TARGET"

for vol in $VOLUMES; do
  [[ -z "$vol" ]] && continue
  backup_volume "$vol"
done

if [ "$TARGET" = "all" ]; then
  echo "Backing up configs..."
  if [ "$DRY_RUN" = "true" ]; then
    restic_config backup --dry-run /config_data --exclude "/config_data/stacks/*/data" --tag "configs"
  else
    if restic_config backup /config_data --exclude "/config_data/stacks/*/data" --tag "configs"; then
      echo "Successfully backed up configs"
    else
      notify "Backup Failed" "Failed to backup configs"
      exit 1
    fi
  fi
fi

if [ "$DRY_RUN" != "true" ]; then
  notify "Backup Success" "Backup completed for target: $TARGET"
fi

echo "Backup complete!"
