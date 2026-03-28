# SSO Integration Guide — Authentik Identity Provider

This guide covers how Authentik SSO is set up and how to integrate new services.

## Overview

Authentik provides single sign-on (SSO) for all homelab services via:
- **OIDC (OpenID Connect)** — for services with native OAuth2/OIDC support
- **Traefik ForwardAuth** — for services without native OIDC
- **Embedded Outpost** — Authentik's built-in proxy provider for ForwardAuth

```
Browser
  │
  ▼
Traefik (:443)
  │
  ├── auth.DOMAIN       → Authentik UI + OIDC endpoints
  ├── grafana.DOMAIN    → Grafana (OIDC native)
  ├── git.DOMAIN        → Gitea (OIDC)
  ├── docs.DOMAIN       → Outline (OIDC)
  ├── vault.DOMAIN      → Vaultwarden (ForwardAuth)
  ├── media.DOMAIN      → Jellyfin (ForwardAuth)
  └── *.{DOMAIN}        → Any service (ForwardAuth)

Internal:
  authentik-server:9000 ← Traefik ForwardAuth → authentik-outpost:9001
```

## Architecture

### Stacks

| Stack | File | Purpose |
|-------|------|---------|
| `stacks/sso/` | docker-compose.yml | Authentik server + worker + PostgreSQL + Redis + embedded outpost |
| `stacks/base/` | docker-compose.yml | Traefik (ForwardAuth middleware configured) |

### Networks

| Network | Type | Used by |
|---------|------|---------|
| `proxy` | external | All services via Traefik |
| `sso` | internal | Authentik stack only |

### Authentik Components

| Container | Image | Port | Purpose |
|-----------|-------|------|---------|
| `authentik-server` | `goauthentik/server:2024.8.3` | 9000 | Web UI, API, OIDC/SAML endpoints |
| `authentik-worker` | `goauthentik/server:2024.8.3` | — | Background tasks, email, policy evaluation |
| `authentik-outpost` | `goauthentik/server:2024.8.3` | 9001 | Embedded proxy provider for Traefik ForwardAuth |
| `postgresql` | `postgres:16-alpine` | 5432 | Authentik database |
| `redis` | `redis:7-alpine` | 6379 | Cache and task queue |

## Setup

### 1. Generate Secrets

```bash
# Generate all required secrets
export AUTHENTIK_SECRET_KEY=$(openssl rand -base64 32)
export AUTHENTIK_POSTGRES_PASSWORD=$(openssl rand -hex 16)
export AUTHENTIK_REDIS_PASSWORD=$(openssl rand -hex 16)
export AUTHENTIK_BOOTSTRAP_TOKEN=$(openssl rand -hex 32)
```

### 2. Configure Environment

```bash
cp .env.example .env
cp stacks/sso/.env.example stacks/sso/.env
# Edit both .env files with your domain, email, and secrets
```

### 3. Start SSO Stack

```bash
docker network create proxy 2>/dev/null || true
cd stacks/sso && docker compose up -d

# Wait for containers to be healthy
docker compose ps
# All should show "healthy" after ~60s

# Run the setup script to create all OIDC providers
cd ../..
./scripts/setup-authentik.sh
```

### 4. Configure Users & Groups

After Authentik is running, open `https://auth.${DOMAIN}`:

1. **Create Groups** (in Authentik UI or via API):
   - `homelab-admins` — full admin access to all services
   - `homelab-users` — standard user access
   - `media-users` — access to media services only (Jellyfin, Jellyseerr)

2. **Create Users** and assign them to groups

3. **Assign Applications to Groups** via Property Mappings:
   ```
   In Authentik Admin → Applications → [app] → Policy Engine
   Add group permission for the appropriate group
   ```

## Integrating New Services

### Option A: Services with Native OIDC Support

If the service supports OIDC/OAuth2, add credentials to `.env` and configure in the service's docker-compose.

**Services with native OIDC:**
- Grafana
- Gitea
- Outline
- Bookstack
- Nextcloud (via Social Login app)
- Open WebUI
- Jellyseerr

**Steps:**
1. Add environment variables to `.env`:
   ```bash
   MY_SERVICE_OIDC_CLIENT_ID=
   MY_SERVICE_OIDC_CLIENT_SECRET=
   ```
2. Add OIDC env vars to the service's `docker-compose.yml`:
   ```yaml
   environment:
     - OIDC_CLIENT_ID=${MY_SERVICE_OIDC_CLIENT_ID}
     - OIDC_CLIENT_SECRET=${MY_SERVICE_OIDC_CLIENT_SECRET}
     - OIDC_ISSUER=https://${AUTHENTIK_DOMAIN}/application/o/my-service/
   ```
3. Run `scripts/setup-authentik.sh` to create the provider (or manually in Authentik UI)
4. Restart the service

**Callback URL format** (used in Authentik provider redirect_uris):
```
https://service.${DOMAIN}/auth/oidc.callback
https://service.${DOMAIN}/login/oidc/Authentik/callback
https://service.${DOMAIN}/api/auth/oidc/callback
```
Check the service's documentation for the exact callback URL.

### Option B: Services Without OIDC (ForwardAuth)

For services without native OIDC support, use Traefik ForwardAuth.

**Adding ForwardAuth to any service:**

In the service's `docker-compose.yml`, add this Traefik label:
```yaml
labels:
  - "traefik.http.routers.<service-name>.middlewares=authentik@file"
```

**Example:**
```yaml
# Protect Jellyfin with Authentik ForwardAuth
jellyfin:
  image: jellyfin/jellyfin:10.9.11
  labels:
    - traefik.enable=true
    - "traefik.http.routers.jellyfin.rule=Host(`media.${DOMAIN}`)"
    - traefik.http.routers.jellyfin.middlewares=authentik@file
```

**How it works:**
1. User visits `https://media.${DOMAIN}`
2. Traefik intercepts the request
3. Traefik ForwardAuth sends request to `authentik-outpost:9001`
4. If user has valid Authentik session → request proceeds
5. If not → redirect to Authentik login page
6. After login → redirected back to original URL

**ForwardAuth response headers** (available to the upstream service):
```
X-authentik-username  → user's username
X-authentik-email     → user's email
X-authentik-groups    → comma-separated group list
X-authentik-name      → user's display name
X-authentik-uid       → user's UID
```

## Service Integration Matrix

| Service | Integration | Notes |
|---------|-------------|-------|
| Grafana | OIDC | Native Grafana OAuth2 support |
| Gitea | OIDC | Native OAuth2 support |
| Outline | OIDC | Built-in OIDC support |
| Bookstack | OIDC | Set `AUTH_METHOD=oidc` |
| Nextcloud | OIDC | Via "Social Login" Nextcloud app |
| Open WebUI | OIDC | Enable `ENABLE_OAUTH=true` |
| Jellyseerr | OIDC | Built-in OIDC support |
| Portainer | OAuth2 | Configure via Portainer UI |
| Jellyfin | ForwardAuth | Enable in Jellyfin Admin UI |
| Vaultwarden | ForwardAuth | Uses master password, not OIDC |
| Prometheus | ForwardAuth | No native auth |
| AdGuard Home | ForwardAuth | No native OIDC |
| Home Assistant | ForwardAuth | No native OIDC for self-hosted |
| Node-RED | ForwardAuth | No native OIDC |
| Zigbee2MQTT | ForwardAuth | No native OIDC |
| Nginx Proxy Manager | ForwardAuth | No native OIDC |
| Homarr | ForwardAuth | No native OIDC |
| Filebrowser | ForwardAuth | No native OIDC |
| Stable Diffusion | ForwardAuth | No native OIDC |

## Email Configuration (SMTP)

Authentik sends email for:
- Password reset links
- Invitation emails
- User registration confirmation

**Configuration in `.env`:**
```bash
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_USER=authentik@yourdomain.com
SMTP_PASSWORD=your-smtp-password
SMTP_FROM=authentik@yourdomain.com
SMTP_USE_TLS=true
```

After updating `.env`, restart the SSO stack:
```bash
cd stacks/sso && docker compose restart authentik-server authentik-worker
```

## Troubleshooting

### Container exits immediately
- Check `AUTHENTIK_SECRET_KEY` is set and non-empty
- Run `docker compose logs authentik-server` to see the error

### ForwardAuth loop (infinite redirect)
- Ensure the outpost is running: `docker compose ps authentik-outpost`
- Check the proxy provider was created in Authentik UI
- Verify `authentik-outpost` can reach `authentik-server` (same `sso` network)

### OIDC redirect mismatch
- The `redirect_uris` in Authentik provider must exactly match the service's callback URL
- Common callback URLs:
  - Grafana: `/login/generic_oauth`
  - Gitea: `/user/oauth2/Authentik/callback`
  - Outline: `/auth/oidc.callback`
  - Jellyseerr: `/api/auth/oidc/callback`

### Groups not mapping to roles
- In Authentik Admin → Applications → [app] → Policy Engine
- Ensure the correct group is assigned to the application
- Check the `groups` claim is included in the OIDC token (add to property mapping)

### DB connection refused
- Wait 30s for PostgreSQL to initialize
- Check `AUTHENTIK_POSTGRES_PASSWORD` matches `POSTGRES_PASSWORD` in postgresql env

### ghcr.io pull timeout
- Uncomment the CN mirror line in `stacks/sso/docker-compose.yml`:
  ```yaml
  # image: swr.cn-north-4.myhuaweicloud.com/ddn-k8s/ghcr.io/goauthentik/server:2024.8.3
  ```

## Environment Variables Reference

### Root `.env`

| Variable | Required | Description |
|----------|----------|-------------|
| `AUTHENTIK_SECRET_KEY` | Yes | Random secret, `openssl rand -base64 32` |
| `AUTHENTIK_POSTGRES_PASSWORD` | Yes | PostgreSQL password |
| `AUTHENTIK_REDIS_PASSWORD` | Yes | Redis password |
| `AUTHENTIK_BOOTSTRAP_EMAIL` | Yes | Initial admin email |
| `AUTHENTIK_BOOTSTRAP_PASSWORD` | Yes | Initial admin password |
| `AUTHENTIK_BOOTSTRAP_TOKEN` | Yes | API token for setup script |
| `AUTHENTIK_DOMAIN` | Yes | Authentik domain, `auth.${DOMAIN}` |
| `SMTP_HOST` | Yes | SMTP server hostname |
| `SMTP_PORT` | Yes | SMTP port (587 for TLS, 465 for SSL) |
| `SMTP_USER` | Yes | SMTP username |
| `SMTP_PASSWORD` | Yes | SMTP password |
| `SMTP_FROM` | Yes | From address for emails |
| `SMTP_USE_TLS` | Yes | Use TLS (`true`/`false`) |

### OIDC Client Variables (auto-filled by `setup-authentik.sh`)

| Variable | Service |
|----------|---------|
| `GRAFANA_OAUTH_CLIENT_ID/SECRET` | Grafana |
| `GITEA_OAUTH_CLIENT_ID/SECRET` | Gitea |
| `OUTLINE_OAUTH_CLIENT_ID/SECRET` | Outline |
| `BOOKSTACK_OIDC_CLIENT_ID/SECRET` | Bookstack |
| `NEXTCLOUD_OIDC_CLIENT_ID/SECRET` | Nextcloud |
| `OPEN_WEBUI_OIDC_CLIENT_ID/SECRET` | Open WebUI |
| `JELLYSEERR_OIDC_CLIENT_ID/SECRET` | Jellyseerr |
| `PORTAINER_OAUTH_CLIENT_ID/SECRET` | Portainer |
| `AUTHENTIK_OUTPOST_CLIENT_ID/SECRET` | Traefik ForwardAuth |
