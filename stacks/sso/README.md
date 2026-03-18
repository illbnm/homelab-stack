# SSO Stack — Authentik Unified Identity

Provides OIDC/SAML single sign-on for all HomeLab services via [Authentik](https://goauthentik.io/).
This is the central authentication hub — all other stacks authenticate through this stack.

## Architecture

```
Browser
  │
  ▼
Traefik (443)
  │  ForwardAuth middleware → authentik-server:9000
  │
  ├── auth.DOMAIN       → Authentik UI (login, admin, user portal)
  ├── grafana.DOMAIN    → Grafana (OIDC)
  ├── git.DOMAIN        → Gitea (OIDC)
  ├── docs.DOMAIN       → Outline (OIDC)
  ├── cloud.DOMAIN      → Nextcloud (OIDC via Social Login)
  ├── ai.DOMAIN         → Open WebUI (OIDC)
  ├── portainer.DOMAIN  → Portainer (OAuth)
  └── *.DOMAIN          → ForwardAuth for non-OIDC services

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
| authentik-worker | `ghcr.io/goauthentik/server:2024.8.3` | — | Background tasks (email, outposts) |
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

# 2. Generate secrets
AUTHENTIK_SECRET_KEY=$(openssl rand -base64 32)
AUTHENTIK_POSTGRES_PASSWORD=$(openssl rand -hex 16)
AUTHENTIK_REDIS_PASSWORD=$(openssl rand -hex 16)

# Update .env with generated values
sed -i "s|^AUTHENTIK_SECRET_KEY=.*|AUTHENTIK_SECRET_KEY=$AUTHENTIK_SECRET_KEY|" .env
sed -i "s|^AUTHENTIK_POSTGRES_PASSWORD=.*|AUTHENTIK_POSTGRES_PASSWORD=$AUTHENTIK_POSTGRES_PASSWORD|" .env
sed -i "s|^AUTHENTIK_REDIS_PASSWORD=.*|AUTHENTIK_REDIS_PASSWORD=$AUTHENTIK_REDIS_PASSWORD|" .env

# Fill remaining values
nano .env  # Set DOMAIN, AUTHENTIK_BOOTSTRAP_EMAIL, AUTHENTIK_BOOTSTRAP_PASSWORD

# 3. Start the stack
docker compose up -d

# 4. Wait for healthy (takes ~60s on first run)
docker compose ps

# 5. Create API token in Authentik Admin → Directory → Tokens
#    Add to .env: AUTHENTIK_BOOTSTRAP_TOKEN=your-token

# 6. Create all OIDC providers automatically
../../scripts/setup-authentik.sh

# 7. Set up Nextcloud OIDC (Social Login app)
../../scripts/nextcloud-oidc-setup.sh
```

## OIDC Integrations

The `setup-authentik.sh` script automatically creates OIDC providers for 6 services:

| Service | Redirect URI | .env Variables |
|---------|-------------|----------------|
| Grafana | `https://grafana.DOMAIN/login/generic_oauth` | `GRAFANA_OAUTH_CLIENT_ID/SECRET` |
| Gitea | `https://git.DOMAIN/user/oauth2/Authentik/callback` | `GITEA_OAUTH_CLIENT_ID/SECRET` |
| Outline | `https://docs.DOMAIN/auth/oidc.callback` | `OUTLINE_OAUTH_CLIENT_ID/SECRET` |
| Portainer | `https://portainer.DOMAIN/` | `PORTAINER_OAUTH_CLIENT_ID/SECRET` |
| Nextcloud | `https://cloud.DOMAIN/apps/oidc_login/oidc` | `NEXTCLOUD_OAUTH_CLIENT_ID/SECRET` |
| Open WebUI | `https://ai.DOMAIN/oauth/oidc/callback` | `OPENWEBUI_OAUTH_CLIENT_ID/SECRET` |

### Dry Run

Preview what would be created without making changes:

```bash
../../scripts/setup-authentik.sh --dry-run
```

### Per-Service Configuration

**Grafana** — Native OIDC. Config in `stacks/monitoring/docker-compose.yml` via `GF_AUTH_GENERIC_OAUTH_*` env vars.

**Gitea** — Native OIDC. After running setup script, configure in Gitea Admin → Authentication Sources.

**Nextcloud** — Uses Social Login app. Run `scripts/nextcloud-oidc-setup.sh` after setup-authentik.sh.

**Outline** — Native OIDC. Config in `stacks/productivity/.env` via `OIDC_*` env vars.

**Open WebUI** — Native OIDC. Config in `stacks/ai/.env`.

**Portainer** — Native OAuth. Configure in Portainer Settings → Authentication → OAuth.

## User Groups

The setup script creates three groups with distinct access levels:

| Group | Role | Access |
|-------|------|--------|
| `homelab-admins` | Superuser | All services — admin panels, Grafana Admin |
| `homelab-users` | Standard | Regular service access — Grafana Viewer |
| `media-users` | Limited | Jellyfin/Jellyseerr only |

### Grafana Role Mapping

```
homelab-admins → Grafana Admin
homelab-users  → Grafana Viewer
```

This is configured via `GF_AUTH_GENERIC_OAUTH_ROLE_ATTRIBUTE_PATH` in the monitoring stack.

## Traefik ForwardAuth

For services without native OIDC support, use the ForwardAuth middleware:

```yaml
# In docker-compose.yml labels:
labels:
  - traefik.http.routers.<name>.middlewares=authentik@file
```

The middleware is defined in `config/traefik/dynamic/middlewares.yml` and passes these headers to upstream services:
- `X-authentik-username`
- `X-authentik-groups`
- `X-authentik-email`
- `X-authentik-name`
- `X-authentik-uid`

## Adding a New Service to SSO

### Step 1: Create OIDC Provider

```bash
# In Authentik Admin → Applications → Providers → Create
# Type: OAuth2/OIDC Provider
# Name: Your-Service
# Authorization flow: default-provider-authorization-implicit-consent
# Redirect URI: https://your-service.DOMAIN/callback
```

### Step 2: Create Application

```bash
# In Authentik Admin → Applications → Create
# Name: Your-Service
# Slug: your-service
# Provider: select the provider created above
```

### Step 3a: For services with native OIDC

Add to the service's environment variables:
```yaml
environment:
  - OIDC_CLIENT_ID=<from Authentik>
  - OIDC_CLIENT_SECRET=<from Authentik>
  - OIDC_AUTH_URL=https://auth.DOMAIN/application/o/authorize/
  - OIDC_TOKEN_URL=https://auth.DOMAIN/application/o/token/
  - OIDC_USERINFO_URL=https://auth.DOMAIN/application/o/userinfo/
  - OIDC_ISSUER=https://auth.DOMAIN/application/o/your-service/
```

### Step 3b: For services without OIDC

Add ForwardAuth middleware in Traefik labels:
```yaml
labels:
  - traefik.http.routers.your-service.middlewares=authentik@file
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

## Health Check

```bash
# All containers healthy
docker compose ps

# Authentik API responding
curl -sf https://auth.DOMAIN/-/health/ready/ && echo OK

# Check admin UI accessible
curl -sf https://auth.DOMAIN/if/admin/ -o /dev/null && echo OK

# Test OIDC discovery endpoint
curl -sf https://auth.DOMAIN/application/o/grafana/.well-known/openid-configuration | jq .
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
| "Invalid client" on login | Provider not created — run `setup-authentik.sh` |
| Groups not synced | Check scopes include `openid profile email`; verify group claim mapping |
| Nextcloud OIDC button missing | Run `scripts/nextcloud-oidc-setup.sh`; check Social Login app is enabled |
