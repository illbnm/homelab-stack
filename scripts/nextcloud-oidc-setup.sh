#!/usr/bin/env bash
set -euo pipefail

# ----------------------------------------------------------------------
# Nextcloud OIDC Social‑Login Setup
# ----------------------------------------------------------------------
# This script installs the “sociallogin” app in a Nextcloud Docker
# container and configures it for Authentik OIDC authentication.
#
# Required environment / arguments:
#   --client-id       OIDC client identifier
#   --client-secret   OIDC client secret
#   --nextcloud-url   Base URL of the Nextcloud instance (e.g. https://nc.example.com)
#   --admin-user      Nextcloud admin username (default: admin)
#
# The script is idempotent – it detects an existing installation and
# configuration and only applies missing steps.
# ----------------------------------------------------------------------

log() {
    local level=$1
    local msg=$2
    echo "$(date +'%Y-%m-%d %H:%M:%S') [${level}] ${msg}"
}

usage() {
    cat <<EOF
Usage: ${0##*/} --client-id <id> --client-secret <secret> --nextcloud-url <url> [--admin-user <user>]

Options:
  --client-id       OIDC client identifier (required)
  --client-secret   OIDC client secret (required)
  --nextcloud-url   Base URL of the Nextcloud instance (required)
  --admin-user      Nextcloud admin username (default: admin)
  -h, --help        Show this help message
EOF
}

# ----------------------------------------------------------------------
# Argument parsing
# ----------------------------------------------------------------------
CLIENT_ID=""
CLIENT_SECRET=""
NEXTCLOUD_URL=""
ADMIN_USER="admin"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --client-id)
            CLIENT_ID="${2:?Missing value for --client-id}"
            shift 2
            ;;
        --client-secret)
            CLIENT_SECRET="${2:?Missing value for --client-secret}"
            shift 2
            ;;
        --nextcloud-url)
            NEXTCLOUD_URL="${2:?Missing value for --nextcloud-url}"
            shift 2
            ;;
        --admin-user)
            ADMIN_USER="${2:?Missing value for --admin-user}"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log "ERROR" "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# ----------------------------------------------------------------------
# Validate required parameters
# ----------------------------------------------------------------------
if [[ -z "$CLIENT_ID" || -z "$CLIENT_SECRET" || -z "$NEXTCLOUD_URL" ]]; then
    log "ERROR" "Missing required arguments."
    usage
    exit 1
fi

# ----------------------------------------------------------------------
# Helper utilities
# ----------------------------------------------------------------------
docker_exec() {
    local container=$1
    shift
    docker exec -i "$container" "$@"
}

# Detect Nextcloud container name (first container with "nextcloud" in its name)
NEXTCLOUD_CONTAINER=$(docker ps --filter "name=nextcloud" --format "{{.Names}}" | head -n1)
if [[ -z "$NEXTCLOUD_CONTAINER" ]]; then
    log "ERROR" "Nextcloud Docker container not found."
    exit 1
fi
log "INFO" "Using Nextcloud container: $NEXTCLOUD_CONTAINER"

# Verify required CLI tools
for cmd in curl jq unzip tar; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        log "ERROR" "Required command not found: $cmd"
        exit 1
    fi
done

# ----------------------------------------------------------------------
# Install sociallogin app if missing
# ----------------------------------------------------------------------
APP_NAME="sociallogin"
APP_DIR="/var/www/html/apps/${APP_NAME}"
if docker_exec "$NEXTCLOUD_CONTAINER" test -d "$APP_DIR"; then
    log "INFO" "App '${APP_NAME}' already present."
else
    log "INFO" "Downloading '${APP_NAME}' app..."
    TMP_ZIP="/tmp/${APP_NAME}.zip"
    curl -fsSL "https://github.com/nextcloud/${APP_NAME}/releases/latest/download/${APP_NAME}.zip" -o "$TMP_ZIP"
    log "INFO" "Extracting app into Nextcloud container..."
    docker cp "$TMP_ZIP" "${NEXTCLOUD_CONTAINER}:${TMP_ZIP}"
    docker_exec "$NEXTCLOUD_CONTAINER" unzip -q "$TMP_ZIP" -d /var/www/html/apps/
    docker_exec "$NEXTCLOUD_CONTAINER" rm -f "$TMP_ZIP"
    log "INFO" "App '${APP_NAME}' installed."
fi

# ----------------------------------------------------------------------
# Enable the app
# ----------------------------------------------------------------------
if docker_exec "$NEXTCLOUD_CONTAINER" php /var/www/html/occ app:list | grep -q "^${APP_NAME}"; then
    log "INFO" "App '${APP_NAME}' already enabled."
else
    log "INFO" "Enabling '${APP_NAME}'..."
    docker_exec "$NEXTCLOUD_CONTAINER" php /var/www/html/occ app:enable "${APP_NAME}"
    log "INFO" "App '${APP_NAME}' enabled."
fi

# ----------------------------------------------------------------------
# Configure OIDC settings
# ----------------------------------------------------------------------
configure_setting() {
    local key=$1
    local value=$2
    local current
    current=$(docker_exec "$NEXTCLOUD_CONTAINER" php /var/www/html/occ config:system:get "${APP_NAME}_${key}" || echo "")
    if [[ "$current" == "$value" ]]; then
        log "INFO" "Setting '${key}' already set to desired value."
    else
        log "INFO" "Setting '${key}' to '${value}'."
        docker_exec "$NEXTCLOUD_CONTAINER" php /var/www/html/occ config:system:set "${APP_NAME}_${key}" --value="${value}"
    fi
}

# OIDC parameters
configure_setting "oidc_client_id" "$CLIENT_ID"
configure_setting "oidc_client_secret" "$CLIENT_SECRET"
configure_setting "oidc_provider_url" "${NEXTCLOUD_URL}"
configure_setting "oidc_redirect_uri" "${NEXTCLOUD_URL}/index.php/apps/${APP_NAME}/login"

# ----------------------------------------------------------------------
# Verify configuration
# ----------------------------------------------------------------------
log "INFO" "Verifying OIDC configuration..."
EXPECTED_KEYS=("oidc_client_id" "oidc_client_secret" "oidc_provider_url" "oidc_redirect_uri")
for key in "${EXPECTED_KEYS[@]}"; do
    value=$(docker_exec "$NEXTCLOUD_CONTAINER" php /var/www/html/occ config:system:get "${APP_NAME}_${key}" || echo "")
    if [[ -z "$value" ]]; then
        log "ERROR" "Configuration key '${key}' is empty."
        exit 1
    fi
done
log "INFO" "All required OIDC settings are present."

# ----------------------------------------------------------------------
# Optional: clear cache to apply changes immediately
# ----------------------------------------------------------------------
log "INFO" "Clearing Nextcloud cache..."
docker_exec "$NEXTCLOUD_CONTAINER" php /var/www/html/occ maintenance:mode --on
docker_exec "$NEXTCLOUD_CONTAINER" php /var/www/html/occ maintenance:mode --off

log "INFO" "Nextcloud OIDC setup completed successfully."
exit 0