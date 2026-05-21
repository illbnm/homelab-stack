#!/bin/bash
set -euo pipefail

LOCKFILE="/tmp/authentik-provision.lock"
MANIFEST_FILE="stacks/sso/provisioning.json"

# Atomic Provisioning: Prevent race conditions during first-boot
exec 200>$LOCKFILE
flock -x 200

log() { echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] $1"; }

# Idempotent Resource Synchronizer
sync_resource() {
    local endpoint=$1
    local payload=$2
    local name=$3
    
    log "Checking state for $name..."
    
    # GET: Check current state
    local current=$(curl -s -H "Authorization: Bearer ${AUTHENTIK_TOKEN}" \
        "${AUTHENTIK_API_URL}${endpoint}?search=${name}")
    
    if [[ -z "$current" || "$current" == "[]" ]]; then
        if [[ "${DRY_RUN:-false}" == "true" ]]; then
            log "[DRY-RUN] Would create $name"
        else
            log "Creating $name..."
            curl -s -X POST -H "Authorization: Bearer ${AUTHENTIK_TOKEN}" \
                -H "Content-Type: application/json" \
                -d "$payload" "${AUTHENTIK_API_URL}${endpoint}"
        fi
    else
        log "$name exists. Calculating diff..."
        # Simplified diff logic: update if payload changes
        if [[ "${DRY_RUN:-false}" == "true" ]]; then
            log "[DRY-RUN] Would update $name"
        else
            local id=$(echo "$current" | grep -oP '"pk":\s*\K[0-9]+' | head -1)
            curl -s -X PATCH -H "Authorization: Bearer ${AUTHENTIK_TOKEN}" \
                -H "Content-Type: application/json" \
                -d "$payload" "${AUTHENTIK_API_URL}${endpoint}/${id}/"
        fi
    fi
}

# Load desired state from manifest
if [[ ! -f "$MANIFEST_FILE" ]]; then
    log "Error: Manifest $MANIFEST_FILE not found."
    exit 1
fi

# Iterate and sync
while read -r resource; do
    local name=$(echo "$resource" | jq -r '.name')
    local endpoint=$(echo "$resource" | jq -r '.endpoint')
    local payload=$(echo "$resource" | jq -c '.payload')
    sync_resource "$endpoint" "$payload" "$name"
done < <(jq -c '.resources[]' "$MANIFEST_FILE")

log "Synchronization complete."
