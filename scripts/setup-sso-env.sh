#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — SSO Environment Setup
# Generates secure secrets for the SSO stack.
# Usage: cd stacks/sso && bash ../../scripts/setup-sso-env.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SSO_DIR="$SCRIPT_DIR/../stacks/sso"

if [ ! -f "$SSO_DIR/.env" ]; then
  cp "$SSO_DIR/.env.example" "$SSO_DIR/.env"
  echo "Created .env from .env.example"
fi

source "$SSO_DIR/.env"

AUTHENTIK_SECRET_KEY=${AUTHENTIK_SECRET_KEY:-$(openssl rand -base64 32)}
AUTHENTIK_POSTGRES_PASSWORD=${AUTHENTIK_POSTGRES_PASSWORD:-$(openssl rand -hex 16)}
AUTHENTIK_REDIS_PASSWORD=${AUTHENTIK_REDIS_PASSWORD:-$(openssl rand -hex 16)}
AUTHENTIK_BOOTSTRAP_TOKEN=${AUTHENTIK_BOOTSTRAP_TOKEN:-$(openssl rand -hex 32)}
AUTHENTIK_BOOTSTRAP_PASSWORD=${AUTHENTIK_BOOTSTRAP_PASSWORD:-$(openssl rand -base64 16)}

sed -i "s|^AUTHENTIK_SECRET_KEY=.*|AUTHENTIK_SECRET_KEY=$AUTHENTIK_SECRET_KEY|" "$SSO_DIR/.env"
sed -i "s|^AUTHENTIK_POSTGRES_PASSWORD=.*|AUTHENTIK_POSTGRES_PASSWORD=$AUTHENTIK_POSTGRES_PASSWORD|" "$SSO_DIR/.env"
sed -i "s|^AUTHENTIK_REDIS_PASSWORD=.*|AUTHENTIK_REDIS_PASSWORD=$AUTHENTIK_REDIS_PASSWORD|" "$SSO_DIR/.env"
sed -i "s|^AUTHENTIK_BOOTSTRAP_TOKEN=.*|AUTHENTIK_BOOTSTRAP_TOKEN=$AUTHENTIK_BOOTSTRAP_TOKEN|" "$SSO_DIR/.env"
sed -i "s|^AUTHENTIK_BOOTSTRAP_PASSWORD=.*|AUTHENTIK_BOOTSTRAP_PASSWORD=$AUTHENTIK_BOOTSTRAP_PASSWORD|" "$SSO_DIR/.env"

echo "SSO environment secrets generated and written to $SSO_DIR/.env"
