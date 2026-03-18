#!/usr/bin/env bash
# =============================================================================
# Storage Stack Tests
# Tests for Nextcloud, MinIO, FileBrowser, Syncthing
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
source "$SCRIPT_DIR/../lib/assert.sh"
source "$SCRIPT_DIR/../lib/docker.sh"
source "$SCRIPT_DIR/../lib/report.sh"

print_section "Storage Stack"

# Test containers
container_check nextcloud
container_check minio
container_check filebrowser
container_check syncthing

# Test HTTP endpoints
http_check MinIO-Console "http://localhost:9001"