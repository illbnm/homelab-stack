#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
ENV_FILE="$ROOT_DIR/.env"

random_hex() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 24
  else
    LC_ALL=C tr -dc 'a-f0-9' < /dev/urandom | head -c 48
  fi
}

set_env() {
  local key=$1
  local value=$2
  local tmp
  tmp=$(mktemp)
  awk -v key="$key" -v value="$value" '
    BEGIN { done = 0 }
    $0 ~ "^" key "=" { print key "=" value; done = 1; next }
    { print }
    END { if (done == 0) print key "=" value }
  ' "$ENV_FILE" > "$tmp"
  mv "$tmp" "$ENV_FILE"
}

[[ -f "$ENV_FILE" ]] || cp "$ROOT_DIR/.env.example" "$ENV_FILE"

set_env TZ "UTC"
set_env DOMAIN "homelab.test"
set_env ACME_EMAIL "ci@example.com"
set_env TRAEFIK_DASHBOARD_USER "admin"
set_env TRAEFIK_DASHBOARD_PASSWORD_HASH "admin:ci-password-hash"
set_env AUTHENTIK_SECRET_KEY "$(random_hex)"
set_env AUTHENTIK_POSTGRES_PASSWORD "$(random_hex)"
set_env AUTHENTIK_REDIS_PASSWORD "$(random_hex)"
set_env AUTHENTIK_ADMIN_EMAIL "admin@homelab.test"
set_env AUTHENTIK_ADMIN_PASSWORD "$(random_hex)"
set_env AUTHENTIK_BOOTSTRAP_TOKEN "$(random_hex)"
set_env AUTHENTIK_DOMAIN "auth.homelab.test"
set_env GRAFANA_OAUTH_CLIENT_ID "grafana-ci"
set_env GRAFANA_OAUTH_CLIENT_SECRET "$(random_hex)"
set_env GITEA_OAUTH_CLIENT_ID "gitea-ci"
set_env GITEA_OAUTH_CLIENT_SECRET "$(random_hex)"
set_env OUTLINE_OAUTH_CLIENT_ID "outline-ci"
set_env OUTLINE_OAUTH_CLIENT_SECRET "$(random_hex)"
set_env PORTAINER_OAUTH_CLIENT_ID "portainer-ci"
set_env PORTAINER_OAUTH_CLIENT_SECRET "$(random_hex)"
set_env POSTGRES_PASSWORD "$(random_hex)"
set_env POSTGRES_ROOT_USER "postgres"
set_env POSTGRES_ROOT_PASSWORD "$(random_hex)"
set_env REDIS_PASSWORD "$(random_hex)"
set_env MARIADB_ROOT_PASSWORD "$(random_hex)"
set_env GITEA_DB_PASSWORD "$(random_hex)"
set_env NEXTCLOUD_DB_PASSWORD "$(random_hex)"
set_env OUTLINE_DB_PASSWORD "$(random_hex)"
set_env AUTHENTIK_DB_PASSWORD "$(random_hex)"
set_env VAULTWARDEN_DB_PASSWORD "$(random_hex)"
set_env BOOKSTACK_DB_PASSWORD "$(random_hex)"
set_env GRAFANA_ADMIN_USER "admin"
set_env GRAFANA_ADMIN_PASSWORD "$(random_hex)"
set_env VAULTWARDEN_ADMIN_TOKEN "$(random_hex)"
set_env WG_HOST "vpn.homelab.test"
set_env WG_PASSWORD "$(random_hex)"
set_env NEXTCLOUD_ADMIN_USER "admin"
set_env NEXTCLOUD_ADMIN_PASSWORD "$(random_hex)"
set_env MINIO_ROOT_USER "minioadmin"
set_env MINIO_ROOT_PASSWORD "$(random_hex)"
set_env MEDIA_ROOT "/tmp/homelab/media"
set_env DOWNLOADS_ROOT "/tmp/homelab/downloads"
set_env MEDIA_PATH "/tmp/homelab/media"
set_env DOWNLOAD_PATH "/tmp/homelab/downloads"
set_env STORAGE_PATH "/tmp/homelab/storage"
set_env OLLAMA_GPU_ENABLED "false"
set_env GOTIFY_PASSWORD "$(random_hex)"
set_env NTFY_AUTH_ENABLED "false"
set_env CN_MODE "false"

mkdir -p "$ROOT_DIR/config/traefik" "$ROOT_DIR/config/traefik/dynamic" "$ROOT_DIR/config"
touch "$ROOT_DIR/config/traefik/acme.json"
chmod 600 "$ROOT_DIR/config/traefik/acme.json"
cp "$ENV_FILE" "$ROOT_DIR/config/.env"
