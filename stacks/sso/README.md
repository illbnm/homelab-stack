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
  ├── outline.DOMAIN  → Outline (OIDC)
  └── portainer.DOMAIN → Portainer (OIDC)

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

### 1. Configure Environment

```bash
# Copy and fill environment variables
cp .env.example .env
nano .env  # Fill ALL values marked REQUIRED

# Generate secrets
export AUTHENTIK_SECRET_KEY=$(openssl rand -base64 32)
export AUTHENTIK_POSTGRES_PASSWORD=$(openssl rand -hex 16)
export AUTHENTIK_REDIS_PASSWORD=$(openssl rand -hex 16)
export AUTHENTIK_BOOTSTRAP_TOKEN=$(openssl rand -hex 32)

# Update .env with generated values
sed -i "s|^AUTHENTIK_SECRET_KEY=.*|AUTHENTIK_SECRET_KEY=$AUTHENTIK_SECRET_KEY|" .env
sed -i "s|^AUTHENTIK_POSTGRES_PASSWORD=.*|AUTHENTIK_POSTGRES_PASSWORD=$AUTHENTIK_POSTGRES_PASSWORD|" .env
sed -i "s|^AUTHENTIK_REDIS_PASSWORD=.*|AUTHENTIK_REDIS_PASSWORD=$AUTHENTIK_REDIS_PASSWORD|" .env
sed -i "s|^AUTHENTIK_BOOTSTRAP_TOKEN=.*|AUTHENTIK_BOOTSTRAP_TOKEN=$AUTHENTIK_BOOTSTRAP_TOKEN|" .env
```

### 2. Start Authentik

```bash
# Start the stack
docker compose up -d

# Wait for healthy (takes ~60s on first run)
docker compose ps
```

### 3. Configure OIDC Providers

```bash
# Create all OIDC providers and write credentials to .env
../../scripts/authentik-setup.sh

# Preview changes without applying
../../scripts/authentik-setup.sh --dry-run
```

This script automatically:
- ✅ Creates user groups (homelab-admins, homelab-users, media-users)
- ✅ Creates OIDC providers for: Grafana, Gitea, Outline, Nextcloud, Open WebUI, Portainer
- ✅ Writes client credentials to .env
- ✅ Creates corresponding Authentik applications

### 4. Restart Services

```bash
# Restart services to pick up new OAuth credentials
cd ../productivity && docker compose restart gitea outline bookstack
cd ../storage && docker compose restart nextcloud
cd ../ai && docker compose restart open-webui
cd ../base && docker compose restart portainer
cd ../monitoring && docker compose restart grafana
```

### 5. Service-Specific Setup

Some services require additional configuration:

```bash
# Nextcloud: Install and configure Social Login app
../../scripts/nextcloud-oidc-setup.sh

# Gitea: Create OAuth2 authentication source
../../scripts/gitea-oidc-setup.sh
```

### 6. Test Login

Visit each service and click "Login with Authentik":
- https://grafana.${DOMAIN}
- https://git.${DOMAIN}
- https://docs.${DOMAIN}
- https://nextcloud.${DOMAIN}
- https://ai.${DOMAIN}
- https://portainer.${DOMAIN}

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

## Integrating Other Services

### Adding New Services to SSO

📖 **See the comprehensive guide:** [docs/sso-integration-guide.md](../../docs/sso-integration-guide.md)

This guide covers:
- Two integration methods (Native OIDC vs ForwardAuth)
- Step-by-step service addition
- Service-specific examples
- User group management
- Troubleshooting

### Option A: OIDC (recommended for services with native OAuth2 support)

Run `../../scripts/authentik-setup.sh` — it automatically creates providers and writes credentials to `.env`.

Services with native OIDC support: Grafana, Gitea, Outline, Nextcloud, Portainer, Open WebUI.

### Option B: ForwardAuth (for services without OAuth2)

Add to any service's Traefik labels:

```yaml
traefik.http.routers.<name>.middlewares: authentik@file
```

Authentik will intercept unauthenticated requests and redirect to the login page at `https://auth.DOMAIN`.

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
