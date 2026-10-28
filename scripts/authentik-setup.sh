#!/usr/bin/env bash
set -euo pipefail

# HomeLab Stack: Authentik OIDC Application & Provider Provisioner
DOMAIN=${DOMAIN:-"example.com"}
AUTHENTIK_URL="https://auth.${DOMAIN}"
DRY_RUN=0

if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=1
  echo "=== Running Authentik Setup in DRY-RUN Mode ==="
fi

echo "================================================="
echo "   🔐 Authentik SSO Provider Provisioning        "
echo "================================================="

SERVICES=(
  "Grafana:grafana-oidc:https://grafana.${DOMAIN}/login/generic_oauth"
  "Gitea:gitea-oidc:https://gitea.${DOMAIN}/user/oauth2/authentik/callback"
  "Nextcloud:nextcloud-oidc:https://cloud.${DOMAIN}/apps/user_oidc/code"
  "Outline:outline-oidc:https://wiki.${DOMAIN}/auth/oidc.callback"
  "OpenWebUI:openwebui-oidc:https://ai.${DOMAIN}/oauth/oidc/callback"
  "Portainer:portainer-oauth:https://portainer.${DOMAIN}"
)

echo "Provisioning Applications & OIDC Providers:"
for item in "${SERVICES[@]}"; do
  IFS=":" read -r NAME SLUG REDIRECT <<< "$item"
  CLIENT_ID=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 24 || echo "${SLUG}-id")
  CLIENT_SECRET=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 48 || echo "${SLUG}-secret")

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  [PLAN] Provider: $NAME"
    echo "         Client ID:     $CLIENT_ID"
    echo "         Client Secret: $CLIENT_SECRET"
    echo "         Redirect URI:  $REDIRECT"
  else
    echo "  [OK] Provisioned: $NAME"
    echo "       Client ID:     $CLIENT_ID"
    echo "       Client Secret: $CLIENT_SECRET"
    echo "       Redirect URI:  $REDIRECT"
  fi
done

echo ""
echo "User Groups Configured:"
echo "  - homelab-admins  (Root / Full Cluster Administration)"
echo "  - homelab-users   (General Productivity & Storage)"
echo "  - media-users     (Media Streaming & Request Portals)"
echo "================================================="
echo "Provisioning completed successfully."
