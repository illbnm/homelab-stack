#!/usr/bin/env bash
# Static and live checks for the Authentik SSO bounty implementation.
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

DOMAIN="${DOMAIN:-}"
AUTHENTIK_DOMAIN="${AUTHENTIK_DOMAIN:-${DOMAIN:+auth.${DOMAIN}}}"
AUTHENTIK_URL="${AUTHENTIK_URL:-https://${AUTHENTIK_DOMAIN}}"
AUTHENTIK_BOOTSTRAP_TOKEN="${AUTHENTIK_BOOTSTRAP_TOKEN:-${AUTHENTIK_TOKEN:-}}"

[[ -n "$DOMAIN" ]] || { echo "DOMAIN is required" >&2; exit 1; }
[[ -n "$AUTHENTIK_DOMAIN" ]] || { echo "AUTHENTIK_DOMAIN is required" >&2; exit 1; }

stacks=(base sso monitoring productivity storage ai)

echo "== docker compose config =="
for stack in "${stacks[@]}"; do
  echo "-- stacks/${stack}"
  docker compose -f "$ROOT_DIR/stacks/${stack}/docker-compose.yml" config >/dev/null
done

echo "== shell syntax =="
bash -n "$ROOT_DIR/scripts/authentik-setup.sh"
bash -n "$ROOT_DIR/scripts/setup-authentik.sh"
bash -n "$ROOT_DIR/scripts/gitea-oidc-setup.sh"
bash -n "$ROOT_DIR/scripts/nextcloud-oidc-setup.sh"
bash -n "$ROOT_DIR/scripts/test-authentik-sso.sh"

echo "== live Authentik health =="
curl -fsS "${AUTHENTIK_URL%/}/-/health/ready/" >/dev/null
echo "ready endpoint OK"

echo "== OIDC discovery endpoints =="
for slug in grafana gitea nextcloud outline open-webui portainer; do
  url="${AUTHENTIK_URL%/}/application/o/${slug}/.well-known/openid-configuration"
  curl -fsS "$url" | jq -e '.issuer and .authorization_endpoint and .token_endpoint' >/dev/null
  echo "${slug} discovery OK"
done

if [[ -n "$AUTHENTIK_BOOTSTRAP_TOKEN" ]]; then
  echo "== Authentik API objects =="
  for group in homelab-admins homelab-users media-users; do
    curl -fsS "${AUTHENTIK_URL%/}/api/v3/core/groups/?search=${group}" \
      -H "Authorization: Bearer ${AUTHENTIK_BOOTSTRAP_TOKEN}" |
      jq -e --arg group "$group" '.results[] | select(.name == $group)' >/dev/null
    echo "${group} group OK"
  done
  for provider in "Grafana OAuth2" "Gitea OAuth2" "Nextcloud OAuth2" "Outline OAuth2" "Open WebUI OAuth2" "Portainer OAuth2"; do
    encoded_provider="$(jq -rn --arg value "$provider" '$value | @uri')"
    curl -fsS "${AUTHENTIK_URL%/}/api/v3/providers/oauth2/?search=${encoded_provider}" \
      -H "Authorization: Bearer ${AUTHENTIK_BOOTSTRAP_TOKEN}" |
      jq -e --arg provider "$provider" '.results[] | select(.name == $provider)' >/dev/null
    echo "${provider} provider OK"
  done
else
  echo "AUTHENTIK_BOOTSTRAP_TOKEN not set; skipped API object checks"
fi

echo "Authentik SSO checks passed"
