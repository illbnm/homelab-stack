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
  ├── auth.DOMAIN       → Authentik UI (login, admin, user portal)
  ├── grafana.DOMAIN    → Grafana (OIDC)
  ├── git.DOMAIN        → Gitea (OIDC)
  ├── outline.DOMAIN     → Outline (OIDC)
  ├── nextcloud.DOMAIN  → Nextcloud (OIDC via oidc_login)
  ├── ai.DOMAIN         → OpenWebUI (OIDC)
  └── portainer.DOMAIN  → Portainer (OAuth)

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

## Quick Start

```bash
cd stacks/sso

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

# 5. Create OIDC providers + user groups
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
| `AUTHENTIK_BOOTSTRAP_TOKEN` | YES | API token for setup script (`openssl rand -hex 32`) |
| `AUTHENTIK_DOMAIN` | YES | e.g. `auth.yourdomain.com` |

## Services Integrated via OIDC

| Service | Config File | OIDC Provider |
|---------|------------|---------------|
| Grafana | `config/grafana/grafana.ini` | Generic OAuth |
| Gitea | `stacks/productivity/.env` | OAuth2 |
| Outline | `stacks/productivity/.env` | OIDC |
| Nextcloud | `scripts/nextcloud-oidc-setup.sh` | oidc_login app |
| OpenWebUI | `stacks/ai/docker-compose.yml` | OIDC |
| Portainer | `stacks/base/.env` | OAuth |

## User Groups

The setup script creates three groups:

| Group | Access |
|-------|--------|
| `homelab-admins` | Full admin access to all services |
| `homelab-users` | Standard user access |
| `media-users` | Media-only (Jellyfin/Jellyseerr) |

Group membership controls access via Authentik policies. Assign users to groups in the Authentik admin UI under **Directory → Groups**.

## Integrating Other Services

### Option A: OIDC (services with native OAuth2 support)

1. Add provider in `scripts/setup-authentik.sh`:
```bash
create_oidc_provider \
  "ServiceName" \
  "https://service.${DOMAIN}/callback/path" \
  "SERVICE_OIDC_CLIENT_ID" \
  "SERVICE_OIDC_CLIENT_SECRET"
```

2. Run the setup script:
```bash
./scripts/setup-authentik.sh
```

3. Add credentials to the service's `.env`:
```bash
SERVICE_OIDC_CLIENT_ID=<from .env>
SERVICE_OIDC_CLIENT_SECRET=<from .env>
SERVICE_OIDC_ISSUER=https://auth.${DOMAIN}
```

### Option B: ForwardAuth (services without OIDC)

Add to any service's Traefik labels:

```yaml
traefik.http.routers.<name>.middlewares: authentik@file
```

Authentik will intercept unauthenticated requests and redirect to the login page at `https://auth.DOMAIN`.

### Adding Nextcloud OIDC

After running `setup-authentik.sh`, configure Nextcloud:

```bash
# Install oidc_login app and configure
../../scripts/nextcloud-oidc-setup.sh

# Then add to stacks/storage/.env:
NEXTCLOUD_OIDC_CLIENT_ID=<from SSO .env>
NEXTCLOUD_OIDC_CLIENT_SECRET=<from SSO .env>
AUTHENTIK_DOMAIN=auth.yourdomain.com
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
| User group missing | Run `setup-authentik.sh` again to create groups |
