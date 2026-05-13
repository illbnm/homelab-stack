#!/usr/bin/env bash
# Configure Gitea external authentication for the Authentik OIDC provider.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

load_env_file() {
  local file="$1"
  if [[ -f "$file" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$file"
    set +a
  fi
}

load_env_file "$ROOT_DIR/.env"
load_env_file "$ROOT_DIR/stacks/sso/.env"
load_env_file "$ROOT_DIR/stacks/productivity/.env"

DOMAIN="${DOMAIN:-}"
AUTHENTIK_DOMAIN="${AUTHENTIK_DOMAIN:-${DOMAIN:+auth.${DOMAIN}}}"
CLIENT_ID="${GITEA_OAUTH_CLIENT_ID:-}"
CLIENT_SECRET="${GITEA_OAUTH_CLIENT_SECRET:-}"
CONTAINER="${GITEA_CONTAINER:-gitea}"
AUTH_NAME="${GITEA_OIDC_AUTH_NAME:-authentik}"

[[ -n "$DOMAIN" ]] || { echo "DOMAIN is required" >&2; exit 1; }
[[ -n "$AUTHENTIK_DOMAIN" ]] || { echo "AUTHENTIK_DOMAIN is required" >&2; exit 1; }
[[ -n "$CLIENT_ID" ]] || { echo "GITEA_OAUTH_CLIENT_ID is required" >&2; exit 1; }
[[ -n "$CLIENT_SECRET" ]] || { echo "GITEA_OAUTH_CLIENT_SECRET is required" >&2; exit 1; }

docker inspect "$CONTAINER" >/dev/null 2>&1 || {
  echo "Container '$CONTAINER' is not running" >&2
  exit 1
}

if docker exec --user git "$CONTAINER" gitea admin auth list | grep -qiE "^[[:space:]]*[0-9]+[[:space:]]+${AUTH_NAME}[[:space:]]"; then
  docker exec --user git "$CONTAINER" gitea admin auth update-oauth \
    --id "$(docker exec --user git "$CONTAINER" gitea admin auth list | awk -v name="$AUTH_NAME" '$2 == name {print $1; exit}')" \
    --name "$AUTH_NAME" \
    --provider openidConnect \
    --key "$CLIENT_ID" \
    --secret "$CLIENT_SECRET" \
    --auto-discover-url "https://${AUTHENTIK_DOMAIN}/application/o/gitea/.well-known/openid-configuration"
else
  docker exec --user git "$CONTAINER" gitea admin auth add-oauth \
    --name "$AUTH_NAME" \
    --provider openidConnect \
    --key "$CLIENT_ID" \
    --secret "$CLIENT_SECRET" \
    --auto-discover-url "https://${AUTHENTIK_DOMAIN}/application/o/gitea/.well-known/openid-configuration"
fi

echo "Gitea OIDC auth source configured for Authentik"
