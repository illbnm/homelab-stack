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

## Integrating Other Services

### Services with Native OIDC Support

Run `../../scripts/setup-authentik.sh` — it automatically creates providers and writes credentials to `.env`.

**✅ Already configured:**
- Grafana (monitoring stack)
- Gitea (productivity stack)
- Outline (productivity stack)
- Bookstack (productivity stack)

**⚠️ Requires additional setup:**
- **Nextcloud**: Run `../../scripts/nextcloud-oidc-setup.sh` after starting the container
- **Portainer**: Configure OAuth in admin UI (requires manual setup)
- **Open WebUI**: Environment variables configured (restart required)

### Option A: OIDC (Native Support)

For services with built-in OAuth2/OIDC support:

1. Add service configuration to `scripts/setup-authentik.sh`
2. Run the script to create provider
3. Update service's environment variables
4. Restart service container

### Option B: ForwardAuth (No OAuth2 Support)

For services without native OAuth2 support:

1. Add to Traefik labels:
   ```yaml
   traefik.http.routers.<name>.middlewares: authentik@file
   ```
2. Authentik will intercept requests and redirect to login

### Adding a New Service

To integrate a new service with Authentik:

1. **Create OIDC Provider**:
   ```bash
   ./scripts/setup-authentik.sh
   ```
   (Update the script with your service details)

2. **Update .env**:
   ```bash
   # Add to stacks/sso/.env
   YOURSERVICE_OAUTH_CLIENT_ID=<from-script-output>
   YOURSERVICE_OAUTH_CLIENT_SECRET=<from-script-output>
   ```

3. **Update service config**:
   - Add OIDC environment variables to service's docker-compose.yml
   - Common variables:
     - `OAUTH_CLIENT_ID`
     - `OAUTH_CLIENT_SECRET`
     - `OAUTH_AUTH_URL=https://${AUTHENTIK_DOMAIN}/application/o/authorize/`
     - `OAUTH_TOKEN_URL=https://${AUTHENTIK_DOMAIN}/application/o/token/`
     - `OAUTH_USERINFO_URL=https://${AUTHENTIK_DOMAIN}/application/o/userinfo/`

4. **Restart service**:
   ```bash
   docker compose -f stacks/<stack>/docker-compose.yml restart <service>
   ```

5. **Test login**:
   - Visit service URL
   - Click "Login with Authentik"
   - Verify user groups and permissions

### User Groups

Default groups (configure in Authentik admin UI):

- **homelab-admins**: Full access to all services
- **homelab-users**: Access to standard services (Grafana, Gitea, etc.)
- **media-users**: Limited to media services (Jellyfin, Jellyseerr)

To assign groups to services:

1. In Authentik admin UI, navigate to Applications > [Service Name]
2. Edit "Policy" > "Group bindings"
3. Add group restrictions as needed

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
