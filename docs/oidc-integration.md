# OIDC Integration Guide — Adding Services to Authentik SSO

This guide explains how to add a new service to the HomeLab SSO system.

## Quick Start (for pre-configured services)

```bash
# 1. Start SSO stack
cd stacks/sso && docker compose up -d

# 2. Create OIDC providers for all services
../../scripts/authentik-setup.sh

# 3. Restart dependent services
docker compose -f stacks/monitoring/docker-compose.yml up -d   # Grafana
docker compose -f stacks/productivity/docker-compose.yml up -d  # Gitea, Outline
docker compose -f stacks/storage/docker-compose.yml up -d       # Nextcloud
docker compose -f stacks/ai/docker-compose.yml up -d            # Open WebUI
docker compose -f stacks/base/docker-compose.yml up -d          # Portainer

# 4. For Nextcloud (requires post-setup):
../../scripts/nextcloud-oidc-setup.sh
```

## Service-Specific Configuration

### Grafana

Config file: `config/grafana/grafana.ini`

```ini
[auth.generic_oauth]
name = Authentik
enabled = true
client_id = ${GF_AUTH_GENERIC_OAUTH_CLIENT_ID}
client_secret = ${GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET}
auth_url = https://${AUTHENTIK_DOMAIN}/application/o/authorize/
token_url = https://${AUTHENTIK_DOMAIN}/application/o/token/
api_url = https://${AUTHENTIK_DOMAIN}/application/o/userinfo/
role_attribute_path = contains(groups[*], 'homelab-admins') && 'Admin' || 'Editor'
```

### Gitea

Add to `stacks/productivity/.env` or `app.ini`:

```ini
[openid]
ENABLE_OPENID_SIGNIN = true
ENABLE_OPENID_SIGNUP = true

[oauth2_client.authentik]
PROVIDER = openid-connect
KEY = ${GITEA_OAUTH2_CLIENT_ID}
SECRET = ${GITEA_OAUTH2_CLIENT_SECRET}
OPENID_CONNECT_SCOPES = openid profile email
```

### Outline

Add to `stacks/productivity/.env`:

```bash
OIDC_CLIENT_ID=${OIDC_CLIENT_ID}
OIDC_CLIENT_SECRET=${OIDC_CLIENT_SECRET}
OIDC_AUTH_URI=https://${AUTHENTIK_DOMAIN}/application/o/authorize/
OIDC_TOKEN_URI=https://${AUTHENTIK_DOMAIN}/application/o/token/
OIDC_USERINFO_URI=https://${AUTHENTIK_DOMAIN}/application/o/userinfo/
OIDC_LOGOUT_URI=https://${AUTHENTIK_DOMAIN}/application/o/end-session/
OIDC_DISPLAY_NAME=Authentik
OIDC_SCOPES=openid profile email
```

### Open WebUI

Add to `stacks/ai/.env`:

```bash
OAUTH_CLIENT_ID=${OPEN_WEBUI_OIDC_CLIENT_ID}
OAUTH_CLIENT_SECRET=${OPEN_WEBUI_OIDC_CLIENT_SECRET}
OPENID_PROVIDER_URL=https://${AUTHENTIK_DOMAIN}/application/o/openwebui/.well-known/openid-configuration
OAUTH_PROVIDER_NAME=Authentik
```

### Portainer

Add to `stacks/base/.env`:

```bash
PORTAINER_OAUTH_PROVIDER=authentik
PORTAINER_OAUTH_CLIENT_ID=${PORTAINER_OAUTH_CLIENT_ID}
PORTAINER_OAUTH_CLIENT_SECRET=${PORTAINER_OAUTH_CLIENT_SECRET}
PORTAINER_OAUTH_AUTHORIZATION_URL=https://${AUTHENTIK_DOMAIN}/application/o/authorize/
PORTAINER_OAUTH_ACCESS_TOKEN_URL=https://${AUTHENTIK_DOMAIN}/application/o/token/
PORTAINER_OAUTH_RESOURCE_URL=https://${AUTHENTIK_DOMAIN}/application/o/userinfo/
PORTAINER_OAUTH_REDIRECT_URL=https://${PORTAINER_DOMAIN}/
PORTAINER_OAUTH_USER_IDENTIFIER=sub
PORTAINER_OAUTH_SCOPES=openid profile email
```

## Adding a New Service (generic)

### Step 1: Create OIDC Provider in Authentik

Add to `scripts/authentik-setup.sh`:

```bash
SERVICES["newservice"]="https://${NEWSERVICE_DOMAIN}/callback|NEWSERVICE_CLIENT_ID|NEWSERVICE_CLIENT_SECRET|"
```

Or create manually via Authentik Admin UI:
1. Navigate to Applications → Providers
2. Create OAuth2/OpenID Provider
3. Set redirect URI to your service's callback URL
4. Note the Client ID and Client Secret

### Step 2: Configure the Service

Most services follow OAuth2/OIDC patterns. Key settings:
- **Authorization URL**: `https://auth.DOMAIN/application/o/authorize/`
- **Token URL**: `https://auth.DOMAIN/application/o/token/`
- **User Info URL**: `https://auth.DOMAIN/application/o/userinfo/`
- **Scopes**: `openid profile email`

### Step 3 (optional): ForwardAuth for No-OIDC Services

If a service does NOT natively support OIDC, use Traefik ForwardAuth:

```yaml
# In the service's docker-compose labels:
traefik.http.routers.<name>.middlewares: authentik@file
```

## User Groups

| Group | Access |
|-------|--------|
| `homelab-admins` | All services, admin privileges |
| `homelab-users` | Read/write access to all services |
| `media-users` | Jellyfin/Jellyseerr only |

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "redirect_uri mismatch" | Ensure the redirect URI in Authentik matches exactly (including trailing slash) |
| "invalid_client" | Check Client ID/Secret in service config |
| OIDC discovery fails | Verify Authentik is accessible at `https://auth.DOMAIN` |
| Users can't log in | Ensure user is in at least one group (homelab-admins, homelab-users) |
| PKCE required | Add `use_pkce = true` to service config if supported |
