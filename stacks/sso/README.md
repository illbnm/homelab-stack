# SSO Stack — Authentik Identity Provider

> Provides OIDC/SAML single sign-on for all HomeLab services via [Authentik](https://goauthentik.io/).

## Architecture

```
Browser
  │
  ▼
Traefik (443)
  │
  ├── auth.DOMAIN     → Authentik UI (login, admin, user portal)
  ├── grafana.DOMAIN  → Grafana (OIDC)
  ├── git.DOMAIN      → Gitea (OIDC)
  ├── docs.DOMAIN      → Outline (OIDC)
  ├── vault.DOMAIN     → Vaultwarden (ForwardAuth)
  ├── media.DOMAIN      → Jellyfin (ForwardAuth)
  └── *.{DOMAIN}       → Any service (ForwardAuth)

Internal:
  authentik-server:9000 ─┐
                         ├── postgresql:5432
  authentik-worker ──────┤
                         └── redis:6379
  authentik-outpost:9001 ── Traefik ForwardAuth handler
```

## Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| authentik-server | `ghcr.io/goauthentik/server:2024.8.3` | 9000/9443 | Web UI + API + OIDC endpoints |
| authentik-worker | `ghcr.io/goauthentik/server:2024.8.3` | — | Background tasks (email, policies, outposts) |
| authentik-outpost | `ghcr.io/goauthentik/server:2024.8.3` | 9001 | Embedded proxy for Traefik ForwardAuth |
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

# 5. Create OIDC providers for all services
cd ../..
./scripts/setup-authentik.sh

# 6. Open Authentik admin UI and configure users/groups
#    https://auth.yourdomain.com
```

## Environment Variables

See `.env.example` for all variables. Key ones:

| Variable | Required | Description |
|----------|----------|-------------|
| `AUTHENTIK_SECRET_KEY` | YES | Random secret — `openssl rand -base64 32` |
| `AUTHENTIK_POSTGRES_PASSWORD` | YES | PostgreSQL password |
| `AUTHENTIK_REDIS_PASSWORD` | YES | Redis password |
| `AUTHENTIK_BOOTSTRAP_EMAIL` | YES | Initial admin email |
| `AUTHENTIK_BOOTSTRAP_PASSWORD` | YES | Initial admin password |
| `AUTHENTIK_BOOTSTRAP_TOKEN` | YES | API token for setup script |
| `AUTHENTIK_DOMAIN` | YES | e.g. `auth.yourdomain.com` |
| `SMTP_HOST/PORT/USER/PASSWORD/FROM` | Recommended | Email backend for password resets |

## OIDC Integration

Services with native OIDC support: Grafana, Gitea, Outline, Bookstack, Nextcloud (social login), Open WebUI, Jellyseerr.

Services using ForwardAuth (no OIDC): Vaultwarden, Jellyfin, Prometheus, AdGuard, Home Assistant, Node-RED, Zigbee2MQTT, Nginx Proxy Manager, Homarr, Filebrowser, Stable Diffusion.

See [../../docs/sso-integration.md](../../docs/sso-integration.md) for full integration guide.

## User Groups

Three groups are created by `setup-authentik.sh`:

| Group | Access |
|-------|--------|
| `homelab-admins` | Full access to all services + admin UIs |
| `homelab-users` | Standard access to all services |
| `media-users` | Media services only (Jellyfin, Jellyseerr) |

## Health Check

```bash
# All containers healthy
docker compose ps

# Authentik API responding
curl -sf https://auth.DOMAIN/-/health/ready/ && echo OK

# Check admin UI accessible
curl -sf https://auth.DOMAIN/if/admin/ -o /dev/null && echo OK

# Check ForwardAuth outpost
curl -sf http://localhost:9000/-/health/ready/ && echo OK
```

## CN Mirror

If `ghcr.io` is inaccessible, edit `docker-compose.yml` and uncomment the CN mirror line:

```yaml
# image: swr.cn-north-4.myhuaweicloud.com/ddn-k8s/ghcr.io/goauthentik/server:2024.8.3
```

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Container exits immediately | Check `AUTHENTIK_SECRET_KEY` is set and non-empty |
| DB connection refused | Wait 30s for PostgreSQL to initialize; check passwords match |
| OIDC redirect mismatch | Ensure `redirect_uris` in Authentik provider matches exact callback URL |
| ForwardAuth loop | Ensure authentik outpost URL uses internal hostname `authentik-server:9000` not public domain |
| `ghcr.io` pull timeout | Switch to CN mirror in docker-compose.yml |
| Email not sending | Check SMTP credentials; restart authentik-server after changing SMTP vars |

For full troubleshooting guide, see [../../docs/sso-integration.md](../../docs/sso-integration.md).
