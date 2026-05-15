# =============================================================================
# Gitea OAuth2 Configuration for Authentik SSO
#
# These environment variables should be added to stacks/productivity/docker-compose.yml
# under the gitea service environment section.
#
# Alternatively, configure via Gitea admin UI:
#   Site Administration → Authentication Sources → Add Authentication Source
#
# Docs: https://docs.gitea.io/en-us/authentication/
# =============================================================================

# Enable Gitea's built-in OAuth2 provider (for downstream clients)
GITEA__oauth2__ENABLE=true
GITEA__oauth2__JWT_SECRET=${GITEA_OAUTH2_JWT_SECRET}

# Note: The OAuth2 authentication *source* must be created via:
#   1. Run: scripts/setup-authentik.sh  (creates the provider in Authentik)
#   2. Gitea Admin UI → Authentication Sources → Add:
#      - Authentication Name: Authentik
#      - OAuth2 Provider: OpenID Connect
#      - Client ID:     (from .env → GITEA_OAUTH_CLIENT_ID)
#      - Client Secret:  (from .env → GITEA_OAUTH_CLIENT_SECRET)
#      - OpenID Connect Auto Discovery URL:
#        https://${AUTHENTIK_DOMAIN}/application/o/gitea/.well-known/openid-configuration
#
# Or use the Gitea API to create the auth source programmatically:
#
# curl -X POST "https://git.${DOMAIN}/api/v1/admin/auths" \
#   -H "Authorization: token YOUR_GITEA_ADMIN_TOKEN" \
#   -H "Content-Type: application/json" \
#   -d '{
#     "name": "Authentik",
#     "type": 6,
#     "is_sync_enabled": true,
#     "oauth2_config": {
#       "provider": "openidConnect",
#       "client_id": "'${GITEA_OAUTH_CLIENT_ID}'",
#       "client_secret": "'${GITEA_OAUTH_CLIENT_SECRET}'",
#       "openid_connect_auto_discovery_url": "https://'${AUTHENTIK_DOMAIN}'/application/o/gitea/.well-known/openid-configuration"
#     }
#   }'
