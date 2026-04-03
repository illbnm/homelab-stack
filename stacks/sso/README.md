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
  ├── outline.DOMAIN   → Outline (OIDC)
  ├── nc.DOMAIN        → Nextcloud (OIDC + Social Login)
  ├── ai.DOMAIN        → Open WebUI (OIDC)
  └── portainer.DOMAIN → Portainer (OIDC)

Internal:
  authentik-server ─┐
                    ├── postgresql:5432
  authentik-worker ─┘
                    └── redis:6379
```

## Privacy: Geo-IP Tracking Disabled

Geo-IP lookups are **disabled by default** (\`AUTHENTIK_GEOIP__ENABLED=false\`) to protect user privacy. Re-enable via the Authentik admin UI under **System → GeoIP** if needed.

## Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| authentik-server | \`ghcr.io/goauthentik/server:2024.8.3\` | 9000/9443 | Web UI + API + OIDC endpoints |
| authentik-worker | \`ghcr.io/goauthentik/server:2024.8.3\` | — | Background tasks (email, notifications) |
| postgresql | \`postgres:16-alpine\` | 5432 (internal) | Authentik database |
| redis | \`redis:7-alpine\` | 6379 (internal) | Session cache + task queue |

## User Groups Design

Three groups provide role-based access across all services:

| Group | Description | Typical Members | Access |
|-------|-------------|-----------------|--------|
| \`admins\` | Full administrative access | Owner, sysadmin | All services + Authentik admin UI |
| \`users\` | Regular authenticated users | Family, team members | All user-facing services |
| \`media\` | Media-only access | Guests, restricted users | Media services (Nextcloud files, Jellyfin, etc.) |

### Authentik Group Setup

After first boot, create groups manually in **Authentik Admin UI**:

1. Go to **Directory → Groups → Create**
2. Create: \`admins\`, \`users\`, \`media\`
3. Assign users to groups under **Directory → Users → [user] → Groups**

Group membership is propagated to all integrated services via OIDC claims in the \`X-authentik-groups\` header (ForwardAuth) or JWT token scope.

## Prerequisites

- Base stack running (\`stacks/base/\` — Traefik + proxy network)
- Domain with DNS pointing to your server
- Ports 80 + 443 open

## Quick Start

\`\`\`bash
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
\`\`\`

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| \`AUTHENTIK_SECRET_KEY\` | YES | Random secret — \`openssl rand -base64 32\` |
| \`AUTHENTIK_POSTGRES_PASSWORD\` | YES | PostgreSQL password |
| \`AUTHENTIK_REDIS_PASSWORD\` | YES | Redis password |
| \`AUTHENTIK_ADMIN_EMAIL\` | YES | Initial admin email |
| \`AUTHENTIK_ADMIN_PASSWORD\` | YES | Initial admin password |
| \`AUTHENTIK_BOOTSTRAP_TOKEN\` | YES | API token for setup script |
| \`AUTHENTIK_DOMAIN\` | YES | e.g. \`auth.yourdomain.com\` |

## Integrating Other Services

### Option A: OIDC (recommended for services with native OAuth2 support)

Run \`../../scripts/setup-authentik.sh\` — it automatically creates providers and writes credentials to \`.env\`.

Services with native OIDC support: **Grafana**, **Gitea**, **Outline**, **Nextcloud**, **Open WebUI**, **Portainer**.

### Option B: ForwardAuth (for services without OAuth2)

Add to any service's Traefik labels:

\`\`\`yaml
traefik.http.routers.<name>.middlewares: authentik@file
\`\`\`

Authentik will intercept unauthenticated requests and redirect to the login page at \`https://auth.DOMAIN\`.

## Service Integration Guide

### Nextcloud — OIDC + Social Login (Dual Auth)

Nextcloud supports both native OIDC and social login. This enables:
- SSO via OIDC (password-less, recommended)
- Traditional password login still available for local accounts
- Social login via Authentik as an identity broker

1. Install the **OpenID Connect Login** app in Nextcloud:
   \`\`\`bash
   docker exec nextcloud occ app:install oidc_login
   \`\`\`

2. The OIDC config file is automatically mounted via \`stacks/storage/nextcloud-oidc.config.php\`

3. Configure the provider in Nextcloud Admin UI → **OpenID Connect Login**:
   - Issuer URL: \`https://auth.DOMAIN/application/o/nextcloud/\`
   - Client ID: from \`.env\` → \`NEXTCLOUD_OAUTH_CLIENT_ID\`
   - Client Secret: from \`.env\` → \`NEXTCLOUD_OAUTH_CLIENT_SECRET\`
   - Scope: \`openid profile email groups\`
   - Enable **Auto-create accounts**

### Portainer — OAuth Authentication

Portainer's OAuth2 setup requires:

| Field | Value |
|-------|-------|
| Provider | Custom |
| Client ID | \`PORTAINER_OAUTH_CLIENT_ID\` (from \`.env\`) |
| Client Secret | \`PORTAINER_OAUTH_CLIENT_SECRET\` (from \`.env\`) |
| Authorization URL | \`https://auth.DOMAIN/application/o/authorize/\` |
| Access Token URL | \`https://auth.DOMAIN/application/o/token/\` |
| User Info URL | \`https://auth.DOMAIN/application/o/userinfo/\` |
| Logout URL | \`https://auth.DOMAIN/application/o/portainer/end-session/\` |
| Scopes | \`openid profile email groups\` |
| Auto-create users | \`true\` |
| Default OIDC username | \`preferred_username\` or \`email\` |

Update \`stacks/base/docker-compose.yml\` Portainer service with these labels:

\`\`\`yaml
- "traefik.http.routers.portainer.middlewares=authentik@file,security-headers@file"
\`\`\`

### Open WebUI — OIDC Authentication

Open WebUI uses Authentik as its OIDC provider. Configure via environment variables:

\`\`\`yaml
WEBUI_OAUTH_ENABLED=true
WEBUI_OAUTH_CLIENT_ID=${OPEN_WEBUI_OAUTH_CLIENT_ID}
WEBUI_OAUTH_CLIENT_SECRET=${OPEN_WEBUI_OAUTH_CLIENT_SECRET}
WEBUI_OAUTH_ISSUER=https://${AUTHENTIK_DOMAIN}/application/o/openwebui/
WEBUI_OAUTH_CALLBACK_URL=https://ai.${DOMAIN}/auth/oidc/Authentik/callback
WEBUI_OAUTH_SCOPES=openid profile email
\`\`\`

### Traefik ForwardAuth Middleware

The ForwardAuth middleware (\`config/traefik/dynamic/middlewares.yml\`) protects services without native OIDC:

\`\`\`yaml
# In your service's docker-compose labels:
traefik.http.routers.<name>.middlewares=authentik@file
\`\`\`

ForwardAuth passes user info via headers to the upstream service:

| Header | Description |
|--------|-------------|
| \`X-authentik-username\` | Display name |
| \`X-authentik-email\` | Email address |
| \`X-authentik-groups\` | Comma-separated group list |
| \`X-authentik-uid\` | Unique user ID |

## Health Check

\`\`\`bash
# All containers healthy
docker compose ps

# Authentik API responding
curl -sf https://auth.DOMAIN/-/health/ready/ && echo OK

# Check admin UI accessible
curl -sf https://auth.DOMAIN/if/admin/ -o /dev/null && echo OK
\`\`\`

## CN Mirror

If \`ghcr.io\` is inaccessible, edit \`docker-compose.yml\` and uncomment the CN mirror lines:

\`\`\`yaml
# image: swr.cn-north-4.myhuaweicloud.com/ddn-k8s/ghcr.io/goauthentik/server:2024.8.3
\`\`\`

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Container exits immediately | Check \`AUTHENTIK_SECRET_KEY\` is set and non-empty |
| DB connection refused | Wait 30s for PostgreSQL to initialize; check \`AUTHENTIK_POSTGRES_PASSWORD\` matches |
| OIDC redirect mismatch | Ensure \`redirect_uris\` in Authentik provider matches exact callback URL |
| ForwardAuth loop | Ensure authentik outpost URL uses internal hostname \`authentik-server:9000\` not public domain |
| \`ghcr.io\` pull timeout | Switch to CN mirror in docker-compose.yml |
| Nextcloud OIDC login fails | Install **OpenID Connect Login** app; verify issuer URL ends with \`/\` |
| Portainer OAuth 400 error | Check redirect_uri in Authentik Portainer provider is exactly \`https://portainer.DOMAIN/api/ldap/oidc/callback\` |
