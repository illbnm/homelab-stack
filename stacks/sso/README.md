# SSO Stack — Authentik Unified Identity

Provides OIDC/SAML single sign-on for all HomeLab services via [Authentik](https://goauthentik.io/).

## Architecture

```
                        ┌─────────────────────────────────┐
                        │          Traefik (443)          │
                        │  ForwardAuth → authentik-server │
                        └────────────┬────────────────────┘
                                     │
       ┌──────────────┬──────────────┼──────────────┬──────────────┐
       │              │              │              │              │
  auth.DOMAIN   grafana.DOMAIN  git.DOMAIN   nextcloud.DOMAIN  ...
  (Authentik)    (OIDC)         (OIDC)        (OIDC)
       │
       ├─ authentik-server ──┐
       │                     ├── postgresql:5432
       ├─ authentik-worker ──┤
       │                     └── redis:6379
       │
       └─ Embedded Outpost (ForwardAuth for non-OIDC services)

  Groups:
    homelab-admins  → Full access to all services
    homelab-users   → Standard service access
    media-users     → Jellyfin / Jellyseerr only
```

## Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| authentik-server | `ghcr.io/goauthentik/server:2024.12.3` | 9000/9443 | Web UI + API + OIDC endpoints |
| authentik-worker | `ghcr.io/goauthentik/server:2024.12.3` | — | Background tasks (email, notifications) |
| postgresql | `postgres:16-alpine` | 5432 (internal) | Authentik database |
| redis | `redis:7-alpine` | 6379 (internal) | Session cache + task queue |

## Prerequisites

- Base stack running (`stacks/base/` — Traefik + proxy network)
- Domain with DNS pointing to your server
- Ports 80 + 443 open

## Quick Start

```bash
# 1. Copy and fill environment variables
cd stacks/sso
cp .env.example .env
nano .env  # Fill ALL values marked REQUIRED

# 2. Generate secrets
export AUTHENTIK_SECRET_KEY=$(openssl rand -base64 32)
export AUTHENTIK_POSTGRES_PASSWORD=$(openssl rand -hex 16)
export AUTHENTIK_REDIS_PASSWORD=$(openssl rand -hex 16)
export AUTHENTIK_BOOTSTRAP_TOKEN=$(openssl rand -hex 32)

# Update .env with generated values
sed -i "s|^AUTHENTIK_SECRET_KEY=.*|AUTHENTIK_SECRET_KEY=$AUTHENTIK_SECRET_KEY|" .env
sed -i "s|^AUTHENTIK_POSTGRES_PASSWORD=.*|AUTHENTIK_POSTGRES_PASSWORD=$AUTHENTIK_POSTGRES_PASSWORD|" .env
sed -i "s|^AUTHENTIK_REDIS_PASSWORD=.*|AUTHENTIK_REDIS_PASSWORD=$AUTHENTIK_REDIS_PASSWORD|" .env
sed -i "s|^AUTHENTIK_BOOTSTRAP_TOKEN=.*|AUTHENTIK_BOOTSTRAP_TOKEN=$AUTHENTIK_BOOTSTRAP_TOKEN|" .env

# 3. Start the stack
docker compose up -d

# 4. Wait for healthy (takes ~60s on first run)
docker compose ps

# 5. Create OIDC providers and groups for all services
../../scripts/setup-authentik.sh
```

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `AUTHENTIK_SECRET_KEY` | YES | Random secret — `openssl rand -base64 32` |
| `AUTHENTIK_POSTGRES_PASSWORD` | YES | PostgreSQL password |
| `AUTHENTIK_REDIS_PASSWORD` | YES | Redis password |
| `AUTHENTIK_BOOTSTRAP_EMAIL` | YES | Initial admin email |
| `AUTHENTIK_BOOTSTRAP_PASSWORD` | YES | Initial admin password |
| `AUTHENTIK_BOOTSTRAP_TOKEN` | YES | API token for setup script |
| `AUTHENTIK_DOMAIN` | YES | e.g. `auth.yourdomain.com` |

## User Groups

The setup script creates three default groups:

| Group | Purpose | Typical members |
|-------|---------|-----------------|
| `homelab-admins` | Full admin access to all services | You, trusted admins |
| `homelab-users` | Access to standard services (Gitea, Outline, etc.) | Family, friends |
| `media-users` | Jellyfin/Jellyseerr only | Media consumers |

**Group assignment:** After running the setup script, go to Authentik Admin → Directory → Groups → assign users.

**Access control:** Configure group-based access in each service (see OIDC integration below) or use the ForwardAuth middleware with group matching.

## OIDC Integration Guide

Run `../../scripts/setup-authentik.sh` to auto-create all providers. Credentials are written to `.env`.

### Grafana

In `config/grafana/grafana.ini` or environment:

```ini
[auth.generic_oauth]
enabled = true
name = Authentik
allow_sign_up = true
client_id = ${GRAFANA_OAUTH_CLIENT_ID}
client_secret = ${GRAFANA_OAUTH_CLIENT_SECRET}
scopes = openid profile email
auth_url = https://auth.DOMAIN/application/o/authorize/
token_url = https://auth.DOMAIN/application/o/token/
api_url = https://auth.DOMAIN/application/o/userinfo/
role_attribute_path = contains(groups[*], 'homelab-admins') && 'Admin' || 'Viewer'
```

### Gitea

In `stacks/productivity/.env`:

```env
GITEA__oauth2_client__ENABLED=true
GITEA__oauth2_client__OPENID_CONNECT_ENABLED=true
GITEA__oauth2_client__REGISTER_EMAIL_CONFIRM=false
```

Then configure in Gitea: Site Administration → Authentication Sources → Add OAuth2 Source:
- Provider: OpenID Connect
- Name: Authentik
- Client ID/Secret: from `.env`
- OpenID Discovery URL: `https://auth.DOMAIN/application/o/gitea/.well-known/openid-configuration`

### Nextcloud

Install the **Social Login** app (occ `app:enable sociallogin`), then add to `config/config.php`:

```php
'social_login_auto_create_groups' => ['homelab-users'],
'social_login_oidc_providers' => [
  'authentik' => [
    'clientId'     => getenv('NEXTCLOUD_OAUTH_CLIENT_ID'),
    'clientSecret' => getenv('NEXTCLOUD_OAUTH_CLIENT_SECRET'),
    'authUrl'      => 'https://auth.DOMAIN/application/o/authorize/',
    'tokenUrl'     => 'https://auth.DOMAIN/application/o/token/',
    'userInfoUrl'  => 'https://auth.DOMAIN/application/o/userinfo/',
    'logoutUrl'    => 'https://auth.DOMAIN/application/o/nextcloud/end-session/',
    'scope'        => 'openid profile email',
    'groups'       => 'groups',
    'title'        => 'Authentik SSO',
  ],
],
```

### Outline

In `stacks/productivity/.env`:

```env
OIDC_CLIENT_ID=${OPENWEBUI_OAUTH_CLIENT_ID}
OIDC_CLIENT_SECRET=${OPENWEBUI_OAUTH_CLIENT_SECRET}
OIDC_AUTH_URI=https://auth.DOMAIN/application/o/authorize/
OIDC_TOKEN_URI=https://auth.DOMAIN/application/o/token/
OIDC_USERINFO_URI=https://auth.DOMAIN/application/o/userinfo/
OIDC_LOGOUT_URI=https://auth.DOMAIN/application/o/outline/end-session/
OIDC_DISPLAY_NAME=Authentik
```

### Open WebUI

In `stacks/ai/.env`:

```env
OPENID_CLIENT_ID=${OPENWEBUI_OAUTH_CLIENT_ID}
OPENID_CLIENT_SECRET=${OPENWEBUI_OAUTH_CLIENT_SECRET}
OPENID_PROVIDER_NAME=Authentik
OPENID_REDIRECT_URI=https://openwebui.DOMAIN/oauth/oidc/callback
OPENID_PROVIDER_URL=https://auth.DOMAIN/application/o/open-web-ui/
OPENID_SCOPE="openid profile email"
```

### Portainer

In `stacks/base/.env` or Portainer UI → Settings → Authentication:

```env
PORTAINER_OAUTH_CLIENT_ID=${PORTAINER_OAUTH_CLIENT_ID}
PORTAINER_OAUTH_CLIENT_SECRET=${PORTAINER_OAUTH_CLIENT_SECRET}
```

Configure via Portainer Settings → Authentication → OAuth:
- Provider: Custom OAuth
- Client ID / Secret: from `.env`
- Authorization URL: `https://auth.DOMAIN/application/o/authorize/`
- Access Token URL: `https://auth.DOMAIN/application/o/token/`
- Resource URL: `https://auth.DOMAIN/application/o/userinfo/`
- Redirect URL: `https://portainer.DOMAIN/`
- User info key: `email`

### Vaultwarden

Vaultwarden does not support OIDC natively. Use **ForwardAuth** (see below) to protect it.

### Jellyfin

Jellyfin has limited OIDC support. Use **ForwardAuth** for authentication, or integrate via [jellyfin-plugin-oidc](https://github.com/9p4/jellyfin-plugin-oidc).

### Home Assistant

1. Install **Authentik** integration via HACS or manually
2. Configure via `configuration.yaml`:

```yaml
authentik:
  domain: auth.DOMAIN
  client_id: !secret authentik_ha_client_id
  client_secret: !secret authentik_ha_client_secret
```

## ForwardAuth Middleware

For services without native OIDC support, use Traefik ForwardAuth. The middleware is pre-configured in `config/traefik/dynamic/authentik.yml`.

### Usage

Add to any service's Traefik labels:

```yaml
traefik.http.routers.myservice.middlewares: authentik@file
```

### Two modes

| Middleware | Behavior | Use case |
|-----------|----------|----------|
| `authentik@file` | Redirect to login page | Web UIs (Vaultwarden, Jellyfin) |
| `authentik-basic@file` | Return 401 (no redirect) | APIs, webhooks |

### Example: Protect Vaultwarden

```yaml
labels:
  - "traefik.http.routers.vaultwarden.middlewares=authentik@file,security-headers@file"
```

Unauthenticated requests will be redirected to `https://auth.DOMAIN` for login.

### Group-based access

Create a Traefik middleware that checks `X-authentik-groups` header:

```yaml
# In config/traefik/dynamic/authentik.yml
    authentik-media-only:
      forwardAuth:
        address: "http://authentik-server:9000/outpost.goauthentik.io/auth/traefik"
        trustForwardHeader: true
        authResponseHeaders:
          - X-authentik-username
          - X-authentik-groups
```

Then configure the policy in Authentik Admin → Applications → select the app → Policy / Group binding.

## Health Check

```bash
# All containers healthy
docker compose ps

# Authentik API responding
curl -sf https://auth.DOMAIN/-/health/ready/ && echo OK

# Check admin UI accessible
curl -sf https://auth.DOMAIN/if/admin/ -o /dev/null && echo OK
```

## Adding a New Service

To add SSO to a new service:

1. **Add provider vars** to `stacks/sso/.env.example`:
   ```env
   NEWSERVICE_OAUTH_CLIENT_ID=
   NEWSERVICE_OAUTH_CLIENT_SECRET=
   ```

2. **Add to setup script** (`scripts/setup-authentik.sh`):
   ```bash
   create_oidc_provider \
     "NewService" \
     "https://newservice.${DOMAIN}/callback" \
     "NEWSERVICE_OAUTH_CLIENT_ID" \
     "NEWSERVICE_OAUTH_CLIENT_SECRET"
   ```

3. **Configure the service** using its OIDC settings (see guides above).

4. **Re-run** the setup script:
   ```bash
   ./scripts/setup-authentik.sh
   ```

## CN Mirror

If `ghcr.io` is inaccessible, edit `docker-compose.yml` and uncomment the CN mirror lines:

```yaml
# image: swr.cn-north-4.myhuaweicloud.com/ddn-k8s/ghcr.io/goauthentik/server:2024.12.3
```

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Container exits immediately | Check `AUTHENTIK_SECRET_KEY` is set and non-empty |
| DB connection refused | Wait 30s for PostgreSQL to initialize; check password matches |
| OIDC redirect mismatch | Ensure `redirect_uris` in Authentik matches exact callback URL |
| ForwardAuth loop | Use internal hostname `authentik-server:9000` not public domain |
| `ghcr.io` pull timeout | Switch to CN mirror in docker-compose.yml |
| Groups not applied | Assign users to groups in Authentik Admin → Directory → Groups |
| Setup script fails 401 | Generate fresh `AUTHENTIK_BOOTSTRAP_TOKEN` and add it in Authentik Admin → Tokens |
