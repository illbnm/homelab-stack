#!/usr/bin/env bash
# =============================================================================
# HomeLab Backup Script — 3-2-1 Strategy
# Usage: backup.sh --target <stack|all> [options]
#
# Copyright (c) 2026 思捷娅科技 (SJYKJ)
# License: MIT
# Author: 小米粒 (Xiaomili) - AI Agent
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../stacks/backup/.env"

# Load environment
if [[ -f "$ENV_FILE" ]]; then
    set -a
    source "$ENV_FILE"
    set +a
fi

# ---- Configuration ----
BACKUP_DIR="${BACKUP_LOCAL_PATH:-/opt/homelab/backups}"
RESTIC_PASSWORD="${RESTIC_PASSWORD:-changeme}"
NTFY_URL="${NTFY_URL:-}"
NTFY_TOPIC="${NTFY_TOPIC:-homelab-backup}"
LOG_FILE="/var/log/homelab-backup-$(date +%Y%m%d-%H%M%S).log"

# Stack volumes map
declare -A STACK_VOLUMES=(
    [base]="traefik-logs portainer-data"
    [databases]="postgres-data redis-data mariadb-data"
    [sso]="authentik-db authentik-media authentik-redis"
    [media]="jellyfin-config sonarr-config radarr-config qbittorrent-config prowlarr-config"
    [storage]="nextcloud-data minio-data filebrowser-db"
    [home-automation]="homeassistant-config mosquitto-data zigbee2mqtt-data"
    [network]="adguard-data wireguard-data"
    [ai]="ollama-data open-webui-data stable-diffusion-data"
    [monitoring]="prometheus-data grafana-data loki-data"
    [notifications]="ntfy-data gotify-data"
    [backup]="duplicati-config restic-data"
)

# ---- Functions ----
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

notify() {
    local title="$1" body="$2"
    if [[ -n "$NTFY_URL" ]]; then
        curl -s -H "Title: $title" -d "$body" "${NTFY_URL}/${NTFY_TOPIC}" >/dev/null 2>&1 || true
    fi
}

get_restic_repo() {
    case "${BACKUP_TARGET:-local}" in
        local)  echo "$BACKUP_DIR/restic" ;;
        s3)     echo "s3:${BACKUP_S3_ENDPOINT:-}/${BACKUP_S3_BUCKET:-homelab-backup}" ;;
        b2)     echo "b2:${BACKUP_B2_BUCKET:-homelab-backup}:/" ;;
        sftp)   echo "sftp:${BACKUP_SFTP_USER:-root}@${BACKUP_SFTP_HOST:-}://${BACKUP_SFTP_PATH:-/backup}" ;;
        r2)     echo "s3:https://${BACKUP_R2_ACCOUNT_ID:-}.r2.cloudflarestorage.com/${BACKUP_R2_BUCKET:-homelab-backup}" ;;
        *)      echo "$BACKUP_DIR/restic" ;;
    esac
}

backup_stack() {
    local stack="$1"
    local repo
    repo="$(get_restic_repo)"

    export RESTIC_PASSWORD
    export AWS_ACCESS_KEY_ID="${BACKUP_S3_ACCESS_KEY:-${BACKUP_R2_ACCESS_KEY:-}}"
    export AWS_SECRET_ACCESS_KEY="${BACKUP_S3_SECRET_KEY:-${BACKUP_R2_SECRET_KEY:-}}"
    export B2_ACCOUNT_ID="${BACKUP_B2_ACCOUNT_ID:-}"
    export B2_ACCOUNT_KEY="${BACKUP_B2_ACCOUNT_KEY:-}"

    # Initialize repo if needed
    restic cat config --repo "$repo" 2>/dev/null || restic init --repo "$repo"

    # Backup stack volumes
    local volumes="${STACK_VOLUMES[$stack]:-}"
    if [[ -z "$volumes" ]]; then
        log "WARN: Unknown stack '$stack', skipping"
        return
    fi

    log "Backing up stack: $stack"
    for vol in $volumes; do
        local vol_path
        vol_path=$(docker volume inspect "$vol" --format '{{.Mountpoint}}' 2>/dev/null || echo "")
        if [[ -n "$vol_path" && -d "$vol_path" ]]; then
            if [[ "${DRY_RUN:-false}" == "true" ]]; then
                log "  DRY-RUN: would backup $vol ($vol_path)"
            else
                log "  Backing up $vol..."
                restic backup "$vol_path" \
                    --repo "$repo" \
                    --tag "stack:$stack" \
                    --tag "volume:$vol" \
                    --host "$(hostname)" \
                    --compression auto 2>&1 | tee -a "$LOG_FILE" || true
            fi
        fi
    done
}

restore_backup() {
    local backup_id="$1"
    local repo
    repo="$(get_restic_repo)"
    export RESTIC_PASSWORD

    log "Restoring from snapshot: $backup_id"
    restic restore "$backup_id" \
        --repo "$repo" \
        --target /opt/homelab/restored/ 2>&1 | tee -a "$LOG_FILE"
    log "Restore complete. Files at /opt/homelab/restored/"
}

list_backups() {
    local repo
    repo="$(get_restic_repo)"
    export RESTIC_PASSWORD
    restic snapshots --repo "$repo" 2>&1 | tee -a "$LOG_FILE"
}

verify_backup() {
    local repo
    repo="$(get_restic_repo)"
    export RESTIC_PASSWORD
    log "Verifying backup integrity..."
    restic check --repo "$repo" 2>&1 | tee -a "$LOG_FILE"
}

cleanup_old() {
    local repo
    repo="$(get_restic_repo)"
    export RESTIC_PASSWORD
    # Keep 7 daily, 4 weekly, 3 monthly
    restic forget --repo "$repo" \
        --keep-daily 7 \
        --keep-weekly 4 \
        --keep-monthly 3 \
        --prune 2>&1 | tee -a "$LOG_FILE"
}

# ---- Main ----
main() {
    local target="all"
    local action="backup"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --target)   target="$2"; shift 2 ;;
            --dry-run)  DRY_RUN=true; shift ;;
            --restore)  action="restore"; target="$2"; shift 2 ;;
            --list)     action="list"; shift ;;
            --verify)   action="verify"; shift ;;
            --cleanup)  action="cleanup"; shift ;;
            -h|--help)
                echo "Usage: $0 --target <stack|all> [--dry-run|--restore <id>|--list|--verify|--cleanup]"
                echo ""
                echo "Stacks: ${!STACK_VOLUMES[*]}"
                exit 0
                ;;
            *) echo "Unknown option: $1"; exit 1 ;;
        esac
    done

    log "=== HomeLab Backup ==="
    log "Action: $action | Target: $target | Mode: ${BACKUP_TARGET:-local}"

    case "$action" in
        backup)
            if [[ "$target" == "all" ]]; then
                for stack in "${!STACK_VOLUMES[@]}"; do
                    backup_stack "$stack"
                done
            else
                backup_stack "$target"
            fi
            if [[ "${DRY_RUN:-false}" != "true" ]]; then
                cleanup_old
            fi
            notify "Backup Complete" "Target=$target Mode=${BACKUP_TARGET:-local}"
            log "=== Backup Complete ==="
            ;;
        restore)
            restore_backup "$target"
            notify "Restore Complete" "Snapshot=$target"
            ;;
        list)
            list_backups
            ;;
        verify)
            verify_backup
            notify "Verify Complete" "Backup integrity verified"
            ;;
        cleanup)
            cleanup_old
            ;;
    esac
}

main "$@"
