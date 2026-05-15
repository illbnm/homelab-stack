# =============================================================================
# Portainer OAuth2 Configuration for Authentik SSO
#
# Portainer supports OAuth2 via its UI configuration.
# Configure after first login at: Settings → Authentication → OAuth
#
# Docs: https://docs.portainer.io/admin/settings/authentication/oauth
# =============================================================================

# Configuration Steps:
# 1. Login to Portainer at https://portainer.${DOMAIN}
# 2. Go to Settings → Authentication
# 3. Select "OAuth" and choose "Custom"
# 4. Fill in:
#
#    OAuth Configuration:
#    ┌─────────────────────────────────────────────────────────────┐
#    │ Client ID:        ${PORTAINER_OAUTH_CLIENT_ID}             │
#    │ Client Secret:    ${PORTAINER_OAUTH_CLIENT_SECRET}         │
#    │ Authorization URL: https://${AUTHENTIK_DOMAIN}/application/o/authorize/ │
#    │ Access Token URL:  https://${AUTHENTIK_DOMAIN}/application/o/token/     │
#    │ Resource URL:      https://${AUTHENTIK_DOMAIN}/application/o/userinfo/  │
#    │ Redirect URL:      https://portainer.${DOMAIN}/            │
#    │ Logout URL:        https://${AUTHENTIK_DOMAIN}/application/o/portainer/end-session/ │
#    │ User Identifier:   preferred_username                      │
#    │ Scopes:            openid profile email                    │
#    └─────────────────────────────────────────────────────────────┘
#
# 5. Click "Save Settings"
# 6. Users can now login with "Login with Authentik" button
#
# Redirect URI (must match in Authentik provider):
# https://portainer.${DOMAIN}/
#
# Note: Portainer also supports ForwardAuth via Traefik middleware.
# If using ForwardAuth, the OAuth2 config above is optional.
# See: config/traefik/dynamic/middlewares.yml → authentik middleware
