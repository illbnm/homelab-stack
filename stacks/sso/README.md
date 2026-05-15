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
  ├── auth.DOMAIN     → Authentik UI (login, admin, user portal)
  ├── grafana.DOMAIN  → Grafana (OIDC)
  ├── git.DOMAIN      → Gitea (OIDC)
  ├── docs.DOMAIN     → Outline (OIDC)
  ├── nextcloud.DOMAIN → Nextcloud (OIDC via sociallogin)
  ├── ai.DOMAIN       → Open WebUI (OIDC)
  ├── wiki.DOMAIN     → BookStack (OIDC)
  └── portainer.DOMAIN → Portainer (OAuth2 / ForwardAuth)

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

# 2. Generate secrets (or use the ones you set in .env)
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

# 5. Preview what the setup script will do
../../scripts/setup-authentik.sh --dry-run

# 6. Create OIDC providers for all services + user groups
../../scripts/setup-authentik.sh

# 7. Setup Nextcloud OIDC (if using Nextcloud)
../../scripts/nextcloud-oidc-setup.sh

# 8. Verify SSO is working
../../scripts/test-sso.sh
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

### OAuth2 Client Credentials (auto-filled by setup script)

| Variable | Service |
|----------|---------|
| `GRAFANA_OAUTH_CLIENT_ID` / `SECRET` | Grafana OIDC |
| `GITEA_OAUTH_CLIENT_ID` / `SECRET` | Gitea OAuth2 |
| `OUTLINE_OAUTH_CLIENT_ID` / `SECRET` | Outline OIDC |
| `PORTAINER_OAUTH_CLIENT_ID` / `SECRET` | Portainer OAuth |
| `NEXTCLOUD_OAUTH_CLIENT_ID` / `SECRET` | Nextcloud (sociallogin) |
| `OPENWEBUI_OAUTH_CLIENT_ID` / `SECRET` | Open WebUI OIDC |
| `BOOKSTACK_OIDC_CLIENT_ID` / `SECRET` | BookStack OIDC |

## User Groups (RBAC)

The setup script creates these groups in Authentik:

| Group | Permissions | Services |
|-------|-------------|----------|
| `homelab-admins` | Superuser | All services with admin access |
| `homelab-users` | Standard user | All regular services |
| `media-users` | Limited | Media stack only (Jellyfin, Jellyseerr) |

Assign users to groups in Authentik admin: **Directory → Groups**

## Integrating Other Services

### Option A: OIDC (recommended for services with native OAuth2 support)

Run `../../scripts/setup-authentik.sh` — it automatically creates providers and writes credentials to `.env`.

Config examples for each service are in the `configs/` directory:
- `configs/grafana/grafana.ini` — Grafana OIDC config
- `configs/gitea/README.md` — Gitea OAuth2 setup
- `configs/nextcloud/oidc-config.txt` — Nextcloud sociallogin config
- `configs/outline/.env` — Outline OIDC env vars
- `configs/open-webui/.env` — Open WebUI OIDC env vars
- `configs/portainer/oauth-setup.md` — Portainer OAuth setup guide

### Option B: ForwardAuth (for services without OAuth2)

Add to any service's Traefik labels:

```yaml
traefik.http.routers.<name>.middlewares: authentik@file
```

Authentik will intercept unauthenticated requests and redirect to the login page at `https://auth.DOMAIN`.

### Adding a New Service

1. **OIDC method**: Add a new `create_oidc_provider` call in `scripts/setup-authentik.sh`
2. **ForwardAuth method**: Just add `authentik@file` middleware label — no provider needed

## Setup Script Options

```bash
# Preview all changes (no API calls made)
./scripts/setup-authentik.sh --dry-run

# Only create user groups (skip provider creation)
./scripts/setup-authentik.sh --groups-only

# Full setup (providers + groups)
./scripts/setup-authentik.sh
```

## Health Check

```bash
# All containers healthy
docker compose ps

# Authentik API responding
curl -sf https://auth.DOMAIN/-/health/ready/ && echo OK

# Check admin UI accessible
curl -sf https://auth.DOMAIN/if/admin/ -o /dev/null && echo OK

# Full SSO test suite
../../scripts/test-sso.sh
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
| Missing group claims | Ensure provider has `groups` scope and `include_claims_in_id_token: true` |
