#!/usr/bin/env bash
# Storage Stack Tests — Nextcloud, MinIO, FileBrowser
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
source "$SCRIPT_DIR/../lib/assert.sh"
source "$SCRIPT_DIR/../lib/docker.sh"

reset_counters
log_test_start "Storage Stack"

DOMAIN="${DOMAIN:-localhost}"
ENV_FILE="$ROOT_DIR/.env"
[[ -f "$ENV_FILE" ]] && export $(grep -v '^#' "$ENV_FILE" | xargs)

section "Nextcloud"
assert_container_running "Nextcloud container" "homelab-nextcloud"
assert_http_2xx "Nextcloud status" "http://localhost:11000/status.php" || true

section "MinIO"
assert_container_running "MinIO container" "homelab-minio"
assert_http_2xx "MinIO API accessible" "http://localhost:9001/minio/health/live" || true

section "FileBrowser"
assert_container_running "FileBrowser container" "homelab-filebrowser"

assert_summary