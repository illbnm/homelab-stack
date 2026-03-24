# SSO Stack — Authentik Unified Identity

Provides OIDC/SAML single sign-on for all HomeLab services via [Authentik](https://goauthentik.io/).

## Architecture

```
Browser
  │
  ▼
Traefik (443)
  │  ForwardAuth middleware → authentik-server:9000
  │
  ├── auth.DOMAIN        → Authentik UI (login, admin, user portal)
  ├── grafana.DOMAIN     → Grafana (OIDC)
  ├── git.DOMAIN         → Gitea (OIDC)
  ├── docs.DOMAIN        → Outline (OIDC)
  ├── portainer.DOMAIN   → Portainer (OAuth)
  ├── nextcloud.DOMAIN   → Nextcloud (OIDC via Social Login)
  └── ai.DOMAIN          → Open WebUI (OIDC)

Internal:
  authentik-server ─┐
                    ├── postgresql:5432
  authentik-worker ─┘
                    └── redis:6379
```

## Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| authentik-server | `ghcr.io/goauthentik/server:2024.8.3` | 9000/9443 | Web UI + API + OIDC endpoints |
| authentik-worker | `ghcr.io/goauthentik/server:2024.8.3` | — | Background tasks (email, notifications) |
| postgresql | `postgres:16-alpine` | 5432 (internal) | Authentik database |
| redis | `redis:7-alpine` | 6379 (internal) | Session cache + task queue |

## Prerequisites

- Base stack running (`stacks/base/` — Traefik + proxy network)
- Domain with DNS pointing to your server
- Ports 80 + 443 open

## Quick Start

```bash
# 1. Copy and fill environment variables
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

# 5. Preview what setup will do
../../scripts/setup-authentik.sh --dry-run

# 6. Create OIDC providers + user groups for all services
../../scripts/setup-authentik.sh

# 7. Configure Nextcloud OIDC (after Nextcloud is running)
../../scripts/nextcloud-oidc-setup.sh
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

The setup script creates three groups with different access levels:

| Group | Role | Access |
|-------|------|--------|
| `homelab-admins` | Superuser | All services — admin dashboards, full management |
| `homelab-users` | Standard | Grafana (Editor), Gitea, Outline, Nextcloud, Open WebUI |
| `media-users` | Limited | Jellyfin, Jellyseerr only |

Assign users to groups in the Authentik admin UI: `https://auth.DOMAIN/if/admin/#/identity/groups`

## OIDC Integration Status

| Service | Method | Config Location | Status |
|---------|--------|-----------------|--------|
| Grafana | OIDC (env vars) | `stacks/monitoring/docker-compose.yml` + `config/grafana/grafana.ini` | Auto-configured |
| Gitea | OIDC (env vars) | `stacks/productivity/docker-compose.yml` | Auto-configured |
| Outline | OIDC (env vars) | `stacks/productivity/docker-compose.yml` | Auto-configured |
| Portainer | OAuth (env vars) | `stacks/base/docker-compose.yml` | Auto-configured |
| Nextcloud | OIDC (Social Login) | `scripts/nextcloud-oidc-setup.sh` | Run script after Nextcloud starts |
| Open WebUI | OIDC (env vars) | `stacks/ai/docker-compose.yml` | Auto-configured |

## Integrating a New Service with Authentik

Follow this guide to add SSO to any new service.

### Option A: Native OIDC (for services with built-in OAuth2 support)

**Step 1:** Add the provider to `scripts/setup-authentik.sh`:

```bash
create_oidc_provider \
  "MyService" \
  "https://myservice.${DOMAIN}/auth/callback" \
  "MYSERVICE_OAUTH_CLIENT_ID" \
  "MYSERVICE_OAUTH_CLIENT_SECRET"
```

**Step 2:** Add env var placeholders to `.env.example` and `.env`:

```bash
MYSERVICE_OAUTH_CLIENT_ID=
MYSERVICE_OAUTH_CLIENT_SECRET=
```

**Step 3:** Add OIDC environment variables to the service's `docker-compose.yml`:

```yaml
environment:
  - OAUTH_CLIENT_ID=${MYSERVICE_OAUTH_CLIENT_ID}
  - OAUTH_CLIENT_SECRET=${MYSERVICE_OAUTH_CLIENT_SECRET}
  - OAUTH_AUTHORIZE_URL=https://${AUTHENTIK_DOMAIN}/application/o/authorize/
  - OAUTH_TOKEN_URL=https://${AUTHENTIK_DOMAIN}/application/o/token/
  - OAUTH_USERINFO_URL=https://${AUTHENTIK_DOMAIN}/application/o/userinfo/
```

**Step 4:** Run the setup script to create the provider:

```bash
../../scripts/setup-authentik.sh
```

**Step 5:** Restart the service to pick up the new credentials:

```bash
docker compose up -d
```

### Option B: Traefik ForwardAuth (for services without OAuth2 support)

ForwardAuth protects any service at the reverse-proxy level. No code changes needed.

**Step 1:** Create an Application + Provider in Authentik admin UI:
- Go to `https://auth.DOMAIN/if/admin/`
- Create a new **Proxy Provider** (Forward auth mode)
- Set External Host to `https://myservice.DOMAIN`
- Create an Application linked to this provider

**Step 2:** Add the middleware to the service's Traefik labels:

```yaml
labels:
  - "traefik.http.routers.myservice.middlewares=authentik@file"
```

The `authentik@file` middleware is defined in `config/traefik/dynamic/authentik.yml` and will:
- Redirect unauthenticated users to the Authentik login page
- Pass `X-authentik-username`, `X-authentik-groups`, `X-authentik-email` headers to the backend

**Step 3:** Restart the service. Any unauthenticated request will now redirect to `https://auth.DOMAIN`.

### Option C: ForwardAuth (API mode, no browser redirect)

For APIs that need auth but should return 401 instead of redirecting:

```yaml
labels:
  - "traefik.http.routers.myapi.middlewares=authentik-basic@file"
```

This uses the `authentik-basic@file` middleware defined in `config/traefik/dynamic/authentik.yml`.

## Traefik ForwardAuth Middleware

The middleware is defined in `config/traefik/dynamic/authentik.yml`:

```yaml
http:
  middlewares:
    authentik:
      forwardAuth:
        address: "http://authentik-server:9000/outpost.goauthentik.io/auth/traefik"
        trustForwardHeader: true
        authResponseHeaders:
          - X-authentik-username
          - X-authentik-groups
          - X-authentik-email
          - X-authentik-name
          - X-authentik-uid
```

## Health Check

```bash
# All containers healthy
docker compose ps

# Authentik API responding
curl -sf https://auth.DOMAIN/-/health/ready/ && echo OK

# Check admin UI accessible
curl -sf https://auth.DOMAIN/if/admin/ -o /dev/null && echo OK
```

## CN Mirror

If `ghcr.io` is inaccessible, edit `docker-compose.yml` and uncomment the CN mirror lines:

```yaml
# image: swr.cn-north-4.myhuaweicloud.com/ddn-k8s/ghcr.io/goauthentik/server:2024.8.3
```

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Container exits immediately | Check `AUTHENTIK_SECRET_KEY` is set and non-empty |
| DB connection refused | Wait 30s for PostgreSQL to initialize; check `AUTHENTIK_POSTGRES_PASSWORD` matches |
| OIDC redirect mismatch | Ensure `redirect_uris` in Authentik provider matches exact callback URL |
| ForwardAuth loop | Ensure authentik outpost URL uses internal hostname `authentik-server:9000` not public domain |
| `ghcr.io` pull timeout | Switch to CN mirror in docker-compose.yml |
| Groups not synced | Ensure `openid profile email` scopes are requested; check group claim mapping in Authentik |
| Nextcloud OIDC broken | Re-run `scripts/nextcloud-oidc-setup.sh`; check Social Login app is enabled |
| Open WebUI no login button | Verify `OPENID_PROVIDER_URL` is reachable from the container |
