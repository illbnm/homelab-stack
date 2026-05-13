#!/bin/bash
set -euo pipefail

COMPOSE_DIR="$(cd "$(dirname "$0")/../stacks/sso" && pwd)"
ENV_FILE="$COMPOSE_DIR/.env"

DRY_RUN=false
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=true
fi

generate_secret() {
  openssl rand -hex 32
}

if $DRY_RUN; then
  echo "[dry-run] Would generate .env at $ENV_FILE"
  echo "[dry-run] AUTHENTIK_SECRET_KEY=$(generate_secret)"
  echo "[dry-run] PG_PASS=$(generate_secret)"
  echo "[dry-run] AUTHENTIK_BOOTSTRAP_PASSWORD=<prompt>"
  exit 0
fi

if [ -f "$ENV_FILE" ]; then
  echo "ERROR: $ENV_FILE already exists. Remove it to re-initialise." >&2
  exit 1
fi

if [ -z "${AUTHENTIK_DOMAIN:-}" ]; then
  read -rp "Authentik domain (e.g. auth.example.com): " AUTHENTIK_DOMAIN
fi
if [ -z "${AUTHENTIK_BOOTSTRAP_EMAIL:-}" ]; then
  read -rp "Admin email [admin@example.com]: " AUTHENTIK_BOOTSTRAP_EMAIL
  AUTHENTIK_BOOTSTRAP_EMAIL="${AUTHENTIK_BOOTSTRAP_EMAIL:-admin@example.com}"
fi
if [ -z "${AUTHENTIK_BOOTSTRAP_PASSWORD:-}" ]; then
  read -rsp "Admin password (input hidden): " AUTHENTIK_BOOTSTRAP_PASSWORD
  echo
fi

AUTHENTIK_SECRET_KEY="$(generate_secret)"
PG_PASS="$(generate_secret)"

cat > "$ENV_FILE" <<EOF
AUTHENTIK_DOMAIN=${AUTHENTIK_DOMAIN}
AUTHENTIK_SECRET_KEY=${AUTHENTIK_SECRET_KEY}
AUTHENTIK_BOOTSTRAP_EMAIL=${AUTHENTIK_BOOTSTRAP_EMAIL}
AUTHENTIK_BOOTSTRAP_PASSWORD=${AUTHENTIK_BOOTSTRAP_PASSWORD}
PG_USER=authentik
PG_PASS=${PG_PASS}
PG_DB=authentik
EOF
chmod 600 "$ENV_FILE"

echo "Generated $ENV_FILE"
echo "Start the stack with: docker compose -f $COMPOSE_DIR/docker-compose.yml up -d"
