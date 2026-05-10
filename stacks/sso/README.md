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
  ├── outline.DOMAIN     → Outline (OIDC)
  ├── nextcloud.DOMAIN   → Nextcloud (OIDC via sociallogin)
  ├── openwebui.DOMAIN   → Open WebUI (OIDC)
  └── portainer.DOMAIN   → Portainer (OIDC)

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

# 5. Create OIDC providers and user groups for all services
../../scripts/setup-authentik.sh

# 6. (Optional) Preview without making changes
../../scripts/setup-authentik.sh --dry-run
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
| `GRAFANA_OAUTH_CLIENT_ID` | Auto | Filled by setup-authentik.sh |
| `GRAFANA_OAUTH_CLIENT_SECRET` | Auto | Filled by setup-authentik.sh |
| `GITEA_OAUTH_CLIENT_ID` | Auto | Filled by setup-authentik.sh |
| `GITEA_OAUTH_CLIENT_SECRET` | Auto | Filled by setup-authentik.sh |
| `OUTLINE_OAUTH_CLIENT_ID` | Auto | Filled by setup-authentik.sh |
| `OUTLINE_OAUTH_CLIENT_SECRET` | Auto | Filled by setup-authentik.sh |
| `NEXTCLOUD_OAUTH_CLIENT_ID` | Auto | Filled by setup-authentik.sh |
| `NEXTCLOUD_OAUTH_CLIENT_SECRET` | Auto | Filled by setup-authentik.sh |
| `PORTAINER_OAUTH_CLIENT_ID` | Auto | Filled by setup-authentik.sh |
| `PORTAINER_OAUTH_CLIENT_SECRET` | Auto | Filled by setup-authentik.sh |
| `OPENWEBUI_OAUTH_CLIENT_ID` | Auto | Filled by setup-authentik.sh |
| `OPENWEBUI_OAUTH_CLIENT_SECRET` | Auto | Filled by setup-authentik.sh |

## User Groups

Three groups are auto-created by `setup-authentik.sh`:

| Group | Access Level |
|-------|-------------|
| `homelab-admins` | Full access to all service admin interfaces |
| `homelab-users` | Access to standard services (Nextcloud, Gitea, Outline…) |
| `media-users` | Access to Jellyfin/Jellyseerr only |

Assign users to groups via Authentik Admin UI → Directory → Groups.

## Service OIDC Integrations

| Service | Integration | Config File / Script |
|---------|------------|---------------------|
| Grafana | OIDC (generic_oauth) | `config/grafana/grafana.ini` |
| Gitea | OIDC | `stacks/productivity/.env` |
| Nextcloud | OIDC (sociallogin) | `scripts/nextcloud-oidc-setup.sh` |
| Outline | OIDC | `stacks/productivity/.env` |
| Open WebUI | OIDC | `stacks/ai/.env` |
| Portainer | OAuth | `stacks/base/.env` |

## Integrating Other Services

### Option A: OIDC (recommended for services with native OAuth2 support)

Run `../../scripts/setup-authentik.sh` — it automatically creates providers and writes credentials to `.env`. Then configure each service's OIDC settings to point to Authentik.

### Option B: ForwardAuth (for services without OAuth2)

Add to any service's Traefik labels:

```yaml
traefik.http.routers.<name>.middlewares: authentik@file
```

Authentik will intercept unauthenticated requests and redirect to the login page.

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
| DB connection refused | Wait 30s for PostgreSQL to initialize |
| OIDC redirect mismatch | Ensure `redirect_uris` in Authentik matches exact callback URL |
| ForwardAuth loop | Ensure outpost URL uses `authentik-server:9000` not public domain |
| `ghcr.io` pull timeout | Switch to CN mirror in docker-compose.yml |
| Duplicate middleware error | Removed in v2 — only `middlewares.yml` defines the `authentik` middleware |
