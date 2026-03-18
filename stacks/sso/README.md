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
  ├── auth.DOMAIN      → Authentik UI (login, admin, user portal)
  ├── grafana.DOMAIN   → Grafana (OIDC)
  ├── git.DOMAIN       → Gitea (OIDC)
  ├── nextcloud.DOMAIN → Nextcloud (OIDC)
  ├── outline.DOMAIN   → Outline (OIDC)
  ├── chat.DOMAIN      → OpenWebUI (OIDC)
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

sed -i "s|^AUTHENTIK_SECRET_KEY=.*|AUTHENTIK_SECRET_KEY=$AUTHENTIK_SECRET_KEY|" .env
sed -i "s|^AUTHENTIK_POSTGRES_PASSWORD=.*|AUTHENTIK_POSTGRES_PASSWORD=$AUTHENTIK_POSTGRES_PASSWORD|" .env
sed -i "s|^AUTHENTIK_REDIS_PASSWORD=.*|AUTHENTIK_REDIS_PASSWORD=$AUTHENTIK_REDIS_PASSWORD|" .env
sed -i "s|^AUTHENTIK_BOOTSTRAP_TOKEN=.*|AUTHENTIK_BOOTSTRAP_TOKEN=$AUTHENTIK_BOOTSTRAP_TOKEN|" .env

# 3. Start the stack
docker compose up -d

# 4. Wait for healthy (~60s on first run), then set up providers
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

## User Group Design

The setup script automatically creates these groups:

| Group | Purpose | Access |
|-------|---------|--------|
| `admins` | Full admin access to all services | Authentik admin UI, Portainer, Grafana admin |
| `users` | Standard users — access to general services | Gitea, Outline, OpenWebUI, Nextcloud |
| `media-users` | Media consumption only | Jellyfin, Sonarr, Radarr (if deployed) |

### Assigning users to groups

After initial setup via Authentik admin UI (`https://auth.DOMAIN/if/admin/`):

1. Go to **Directory → Users** → click user
2. Go to **Groups** tab → add to desired groups
3. Policies in Authentik can enforce group-based access per application

### Group-based access policy (example)

In Authentik admin → **Flows & Stages** → create a group membership check:

```
Expression Policy: return ak_user_group(request.user).name == "admins"
```

Attach this policy to an application's binding to restrict access.

## OIDC Integration Tutorial

### Automated: For supported services

Run the setup script — it creates all providers at once:

```bash
# Preview what will be created (no changes)
../../scripts/setup-authentik.sh --dry-run

# Actually create providers
../../scripts/setup-authentik.sh
```

This creates OIDC providers + applications for: **Grafana, Gitea, Outline, Portainer, Nextcloud, OpenWebUI**.

Client IDs and secrets are automatically written to `.env`.

### Manual: Adding a new service

1. **In Authentik Admin** → **Applications → Providers** → **Create**:
   - Type: `OAuth2/OpenID Provider`
   - Name: `My Service Provider`
   - Authorization flow: `default-provider-authorization-implicit-consent`
   - Client type: `Confidential`
   - Redirect URIs: `https://myservice.DOMAIN/callback`
   - Signing key: (select the default)

2. **Save** → copy the **Client ID** and **Client Secret**

3. **Create Application** → **Applications → Create**:
   - Name: `My Service`
   - Slug: `my-service`
   - Provider: `My Service Provider`

4. **Configure the service** to use OIDC with:
   - Issuer URL: `https://auth.DOMAIN/application/o/my-service/`
   - Client ID / Secret from step 2
   - Scopes: `openid email profile`

### Nextcloud specific

Nextcloud requires the `user_oidc` app. After running the setup script:

```bash
../../scripts/nextcloud-oidc-setup.sh --install-app
```

See [scripts/nextcloud-oidc-setup.sh](../../scripts/nextcloud-oidc-setup.sh) for details.

## ForwardAuth

For services without native OAuth2 support, use Traefik's ForwardAuth middleware.

### How it works

```
User request → Traefik → ForwardAuth check → Authentik Outpost
                                      ↓ (authenticated)
                                 Forward to service with user headers
                                      ↓ (not authenticated)
                                 Redirect to login page
```

Authentik's embedded outpost handles the auth check at `/outpost.goauthentik.io/auth/traefik`.

### Usage

Add to any service's Traefik labels:

```yaml
labels:
  - "traefik.http.routers.myapp.middlewares=authentik@file"
```

The middleware is defined in `config/traefik/dynamic/middlewares.yml` and adds these headers to authenticated requests:

| Header | Content |
|--------|---------|
| `X-authentik-username` | Username |
| `X-authentik-groups` | Group list |
| `X-authentik-email` | Email address |
| `X-authentik-uid` | User UUID |
| `X-authentik-jwt` | JWT token with claims |

### Group-based access with ForwardAuth

Combine with Traefik's `ipAllowList`-style middlewares or use Authentik's access policies to restrict which groups can access which services via ForwardAuth.

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
| DB connection refused | Wait 30s for PostgreSQL; check password matches |
| OIDC redirect mismatch | Ensure redirect_uris matches exact callback URL |
| ForwardAuth loop | Ensure outpost URL uses internal hostname not public domain |
| `ghcr.io` pull timeout | Switch to CN mirror in docker-compose.yml |
| user_oidc app not found | Run `occ app:enable user_oidc` or `occ app:install user_oidc` |
