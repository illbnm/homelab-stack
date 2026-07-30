# SSO Stack — Authentik Unified Identity Authentication

Centralized single sign-on (SSO) for all homelab services using Authentik as OIDC/SAML provider.

## Services

| Service | Image | Port | URL |
|---------|-------|------|-----|
| Authentik Server | `ghcr.io/goauthentik/server:2024.8.3` | 9000/9443 | `https://auth.${DOMAIN}` |
| Authentik Worker | `ghcr.io/goauthentik/server:2024.8.3` | — | Background tasks |
| PostgreSQL | `postgres:16.4-alpine` | — | Authentik database |
| Redis | `redis:7.4.0-alpine` | — | Cache + message queue |

## Architecture

```
                    ┌──────────────────┐
                    │   Traefik (HTTPS) │
                    └────────┬─────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
     ForwardAuth         Direct OIDC    Direct OIDC
              │              │              │
    ┌─────────▼──────┐  ┌───▼────┐  ┌──────▼─────┐
    │ Authentik       │  │Grafana │  │  Gitea     │
    │ Server (9000)   │  │        │  │            │
    └────────┬────────┘  └────────┘  └────────────┘
             │
    ┌────────┼────────┐
    │        │        │
    ▼        ▼        ▼
 PostgreSQL  Redis  Worker
```

## Quick Start

```bash
cp .env.example .env
# Generate secure keys:
openssl rand -base64 60  # AUTHENTIK_SECRET_KEY
openssl rand -hex 24     # AUTHENTIK_PG_PASS

nano .env  # Fill in all values
docker compose up -d
```

Wait for services to be healthy:
```bash
docker compose ps  # All should show "healthy"
```

### First Login

1. Visit `https://auth.${DOMAIN}/if/flow/initial-setup/`
2. Create admin account
3. Generate API token: Admin → Settings → Tokens → Create
4. Export token: `export AUTHENTIK_TOKEN=your-token`

### Provision OIDC Providers

```bash
# Preview what will be created
./scripts/authentik-setup.sh --dry-run

# Create all providers + applications
./scripts/authentik-setup.sh
```

Output:
```
[OK] Created provider: Grafana
     Client ID: xxxxx
     Client Secret: xxxxx
     Redirect URI: https://grafana.example.com/login/generic_oauth
[OK] Created provider: Gitea
     ...
```

## OIDC Integrations

### Grafana

Config in `config/grafana/grafana.ini`:
```ini
[auth.generic_oauth]
enabled = true
client_id = ${GRAFANA_OIDC_CLIENT_ID}
client_secret = ${GRAFANA_OIDC_CLIENT_SECRET}
auth_url = https://auth.${DOMAIN}/application/o/authorize/
token_url = https://auth.${DOMAIN}/application/o/token/
api_url = https://auth.${DOMAIN}/application/o/userinfo/
role_attribute_path = contains(groups[*], 'homelab-admins') && 'Admin' || 'Viewer'
```

### Gitea

Add to `stacks/productivity/.env`:
```env
GITEA_OIDC_CLIENT_ID=<from setup script>
GITEA_OIDC_CLIENT_SECRET=<from setup script>
```

Gitea config (`/data/gitea/gitea/conf/app.ini`):
```ini
[oauth2_client]
ENABLE_AUTO_REGISTRATION = true
OPENID_CONNECT_SCOPES = openid profile email groups
```

### Nextcloud

```bash
./scripts/nextcloud-oidc-setup.sh
```

### Outline

Add to `stacks/productivity/.env`:
```env
OUTLINE_OIDC_CLIENT_ID=<from setup script>
OUTLINE_OIDC_CLIENT_SECRET=<from setup script>
OUTLINE_OIDC_AUTH_URI=https://auth.${DOMAIN}/application/o/authorize/
OUTLINE_OIDC_TOKEN_URI=https://auth.${DOMAIN}/application/o/token/
OUTLINE_OIDC_USERINFO_URI=https://auth.${DOMAIN}/application/o/userinfo/
```

### Open WebUI

Add to `stacks/ai/.env`:
```env
OPENWEBUI_OIDC_CLIENT_ID=<from setup script>
OPENWEBUI_OIDC_CLIENT_SECRET=<from setup script>
OPENID_PROVIDER_URL=https://auth.${DOMAIN}/application/o/openwebui/
```

### Portainer

Add to `stacks/base/.env`:
```env
PORTAINER_OAUTH_CLIENT_ID=<from setup script>
PORTAINER_OAUTH_CLIENT_SECRET=<from setup script>
```

Portainer Settings → Authentication → OAuth:
- Authorization URL: `https://auth.${DOMAIN}/application/o/authorize/`
- Token URL: `https://auth.${DOMAIN}/application/o/token/`
- Resource URL: `https://auth.${DOMAIN}/application/o/userinfo/`
- Redirect URL: `https://portainer.${DOMAIN}/`

## Traefik ForwardAuth

For services that don't natively support OIDC, use the ForwardAuth middleware:

```yaml
# In service's docker-compose labels:
- "traefik.http.routers.MYSERVICE.middlewares=authentik@file"
```

This protects any service behind Authentik login without requiring native OIDC support.

## User Groups

| Group | Access Level |
|-------|-------------|
| `homelab-admins` | Full admin access to all services |
| `homelab-users` | Standard user access |
| `homelab-media` | Access to media services (Jellyfin, Jellyseerr) |
| `homelab-dev` | Access to development tools (Gitea, Outline) |

## Health Checks

All services have healthchecks with proper `start_period`:
- PostgreSQL: `pg_isready` (20s start)
- Redis: `redis-cli ping` (10s start)
- Authentik Server: `/-/health/live/` (60s start)
- Authentik Worker: `celery inspect ping` (60s start)

Worker depends on Server being healthy before starting.

## Backup

Authentik data is in Docker volumes:
```bash
# Backup
docker run --rm -v authentik_db:/data -v $(pwd):/backup alpine tar czf /backup/authentik-db.tar.gz -C /data .

# Restore
docker run --rm -v authentik_db:/data -v $(pwd):/backup alpine tar xzf /backup/authentik-db.tar.gz -C /data
```

## DNS Records

| Hostname | Service |
|----------|---------|
| `auth.${DOMAIN}` | Authentik Server |