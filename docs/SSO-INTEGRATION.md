# SSO Integration Guide

This guide explains how to integrate new services with Authentik SSO.

## Overview

Authentik serves as the central Identity Provider (IdP) for all homelab services. Services can integrate via:

1. **OIDC (OpenID Connect)** - Recommended for most modern services
2. **SAML** - For enterprise services requiring SAML
3. **ForwardAuth** - For services without native OIDC support

## Architecture

```
┌─────────────┐
│   Browser   │
└──────┬──────┘
       │
       ▼
┌─────────────────────────────────────────┐
│            Traefik (Proxy)               │
│  - TLS termination                       │
│  - ForwardAuth middleware                │
└─────────────────┬───────────────────────┘
                  │
        ┌─────────┴─────────┐
        │                   │
        ▼                   ▼
┌───────────────┐   ┌──────────────┐
│  Authentik    │   │   Service    │
│  (SSO IdP)    │   │ (OIDC/SAML)  │
└───────────────┘   └──────────────┘
```

## Prerequisites

1. SSO stack running: `cd stacks/sso && docker compose up -d`
2. Initial Authentik setup completed
3. Bootstrap token created (see `.env.example`)

## Adding a New Service

### Step 1: Create OIDC Provider

Add your service to `scripts/setup-authentik.sh`:

```bash
create_oidc_provider \
  "Your-Service" \
  "[\"https://service.${DOMAIN}/oauth/callback\"]" \
  "YOUR_SERVICE_OAUTH_CLIENT_ID" \
  "YOUR_SERVICE_OAUTH_CLIENT_SECRET"
```

### Step 2: Configure Service

#### Option A: Native OIDC Support

Most modern services support OIDC natively. Add these environment variables:

```yaml
environment:
  - OIDC_CLIENT_ID=${YOUR_SERVICE_OAUTH_CLIENT_ID}
  - OIDC_CLIENT_SECRET=${YOUR_SERVICE_OAUTH_CLIENT_SECRET}
  - OIDC_DISCOVERY_URL=https://${AUTHENTIK_DOMAIN}/application/o/your-service/.well-known/openid-configuration
  - OIDC_SCOPES=openid email profile
```

#### Option B: ForwardAuth (No Native OIDC)

For services without OIDC support, use Traefik ForwardAuth:

```yaml
labels:
  - traefik.http.routers.your-service.middlewares=authentik@file
```

This will redirect unauthenticated users to Authentik login.

### Step 3: Test Integration

1. Run setup script: `./scripts/setup-authentik.sh`
2. Restart your service
3. Test login via Authentik

## Service-Specific Configurations

### Grafana

Grafana has built-in OAuth support. Configuration is in `stacks/monitoring/docker-compose.yml`:

```yaml
environment:
  - GF_AUTH_GENERIC_OAUTH_ENABLED=true
  - GF_AUTH_GENERIC_OAUTH_NAME=Authentik
  - GF_AUTH_GENERIC_OAUTH_CLIENT_ID=${GRAFANA_OAUTH_CLIENT_ID}
  - GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET=${GRAFANA_OAUTH_CLIENT_SECRET}
  - GF_AUTH_GENERIC_OAUTH_SCOPES=openid profile email
  - GF_AUTH_GENERIC_OAUTH_AUTH_URL=https://${AUTHENTIK_DOMAIN}/application/o/authorize/
  - GF_AUTH_GENERIC_OAUTH_TOKEN_URL=https://${AUTHENTIK_DOMAIN}/application/o/token/
  - GF_AUTH_GENERIC_OAUTH_API_URL=https://${AUTHENTIK_DOMAIN}/application/o/userinfo/
```

### Gitea

Gitea requires manual OAuth setup via UI or API after installation:

1. Login to Gitea as admin
2. Go to: Site Administration → Authentication Sources
3. Add new OAuth2 provider:
   - Provider Name: `Authentik`
   - Client ID: from `.env`
   - Client Secret: from `.env`
   - Authorization Endpoint: `https://auth.${DOMAIN}/application/o/authorize/`
   - Token Endpoint: `https://auth.${DOMAIN}/application/o/token/`
   - User Info Endpoint: `https://auth.${DOMAIN}/application/o/userinfo/`

### Nextcloud

Nextcloud requires the `user_oidc` app. Run the setup script:

```bash
./scripts/nextcloud-oidc-setup.sh
```

This will:
1. Install `user_oidc` and `group_oidc` apps
2. Configure Authentik as OIDC provider
3. Set up automatic user provisioning
4. Map Authentik groups to Nextcloud groups

### Outline

Outline supports OIDC natively. Configuration in `stacks/productivity/docker-compose.yml`:

```yaml
environment:
  - OIDC_CLIENT_ID=${OUTLINE_OAUTH_CLIENT_ID}
  - OIDC_CLIENT_SECRET=${OUTLINE_OAUTH_CLIENT_SECRET}
  - OIDC_AUTH_URI=https://${AUTHENTIK_DOMAIN}/application/o/authorize/
  - OIDC_TOKEN_URI=https://${AUTHENTIK_DOMAIN}/application/o/token/
  - OIDC_USERINFO_URI=https://${AUTHENTIK_DOMAIN}/application/o/userinfo/
  - OIDC_SCOPES=openid profile email
```

### Open WebUI

Open WebUI supports OAuth via environment variables:

```yaml
environment:
  - ENABLE_OAUTH_SIGNUP=true
  - OAUTH_PROVIDER_NAME=Authentik
  - OAUTH_CLIENT_ID=${OPENWEBUI_OAUTH_CLIENT_ID}
  - OAUTH_CLIENT_SECRET=${OPENWEBUI_OAUTH_CLIENT_SECRET}
  - OPENID_PROVIDER_URL=https://${AUTHENTIK_DOMAIN}/application/o/open-webui/.well-known/openid-configuration
```

### Portainer

Portainer OAuth requires manual configuration:

1. Login to Portainer as admin
2. Go to: Settings → Authentication
3. Select "OAuth"
4. Configure:
   - Client ID: `${PORTAINER_OAUTH_CLIENT_ID}`
   - Client Secret: `${PORTAINER_OAUTH_CLIENT_SECRET}`
   - Authorization URL: `https://${AUTHENTIK_DOMAIN}/application/o/authorize/`
   - Access Token URL: `https://${AUTHENTIK_DOMAIN}/application/o/token/`
   - Resource URL: `https://${AUTHENTIK_DOMAIN}/application/o/userinfo/`
   - Redirect URL: `https://portainer.${DOMAIN}/`
   - User Identifier: `preferred_username`
   - Scopes: `openid email profile`

## User Groups

Authentik groups control service access:

| Group | Access |
|-------|--------|
| `homelab-admins` | Full access to all services |
| `homelab-users` | Access to regular services |
| `media-users` | Access to media services only (Jellyfin, Jellyseerr) |

### Creating Groups

Groups are created automatically by `setup-authentik.sh`. To create manually:

```bash
# Via Authentik UI
Admin → Directory → Groups → Create

# Via API
curl -X POST https://auth.${DOMAIN}/api/v3/core/groups/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "my-new-group"}'
```

### Assigning Users to Groups

```bash
# Via Authentik UI
Admin → Directory → Users → Select user → Groups → Add

# Via API
curl -X POST https://auth.${DOMAIN}/api/v3/core/groups/{group_pk}/add_user/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"pk": "user_pk"}'
```

## Troubleshooting

### Common Issues

1. **"Invalid redirect URI"**
   - Check redirect URI matches exactly in Authentik provider
   - Include protocol (https://) and trailing slash if needed

2. **"Token validation failed"**
   - Verify client secret is correct
   - Check clocks are synchronized (NTP)

3. **"User not found" after login**
   - Enable auto-provisioning in service config
   - Check user attributes mapping

### Debug Mode

Enable verbose logging:

```bash
# Authentik logs
docker logs authentik-server -f

# Check OIDC flow
docker logs authentik-worker -f | grep oidc
```

### Testing OIDC Flow

Use `curl` to test token endpoint:

```bash
# Get token
curl -X POST https://auth.${DOMAIN}/application/o/token/ \
  -d "grant_type=authorization_code" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "code=$AUTH_CODE" \
  -d "redirect_uri=https://service.${DOMAIN}/callback"
```

## Security Best Practices

1. **Use HTTPS everywhere** - Required for OIDC
2. **Rotate secrets regularly** - Especially after incidents
3. **Limit scopes** - Only request needed attributes
4. **Enable MFA** - For admin accounts
5. **Audit access** - Review group memberships regularly
6. **Use strong client secrets** - 32+ characters

## Additional Resources

- [Authentik Documentation](https://docs.goauthentik.io/)
- [OIDC Specification](https://openid.net/connect/)
- [Traefik ForwardAuth](https://doc.traefik.io/traefik/middlewares/http/forwardauth/)