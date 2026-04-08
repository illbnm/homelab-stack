# SSO Stack — Authentik Unified Identity Provider

[Authentik](https://goauthentik.io/) is an open-source Identity Provider supporting OIDC, SAML, and LDAP. This stack provides centralized authentication for all HomeLab services.

## Architecture Overview

```
                                   ┌─────────────────────┐
                                   │   Browser Client    │
                                   └──────────┬──────────┘
                                              │
                                   ┌──────────▼──────────┐
                                   │   Traefik (443)     │
                                   │  Reverse Proxy      │
                                   └──────────┬──────────┘
                                              │
                    ┌─────────────────────────┼─────────────────────────┐
                    │                         │                         │
         ┌──────────▼──────────┐  ┌──────────▼──────────┐  ┌──────────▼──────────┐
         │ auth.DOMAIN         │  │ Protected Services  │  │ OIDC Services       │
         │ (Authentik UI)      │  │ (ForwardAuth)       │  │ (Native OIDC)       │
         └─────────────────────┘  └─────────────────────┘  └─────────────────────┘
                    │                         │                         │
                    │                    Middleware               Service Config
                    │                 authentik@file                    │
                    │                         │                         │
         ┌──────────▼──────────────────────────▼─────────────────────────▼──────────┐
         │                        Authentik Stack                                    │
         │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
         │  │ Server (9000)│  │ Worker       │  │ PostgreSQL   │  │ Redis        │  │
         │  │ API + UI     │  │ Background   │  │ Database     │  │ Cache/Queue  │  │
         │  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘  │
         └───────────────────────────────────────────────────────────────────────────┘
```

## Services Included

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| **authentik-server** | `ghcr.io/goauthentik/server:2024.8.3` | 9000/9443 | Web UI + API + OIDC endpoints |
| **authentik-worker** | `ghcr.io/goauthentik/server:2024.8.3` | — | Background tasks (email, notifications) |
| **postgresql** | `postgres:16-alpine` | 5432 (internal) | Authentik database |
| **redis** | `redis:7-alpine` | 6379 (internal) | Session cache + task queue |

## Prerequisites

1. **Base stack running** (`stacks/base/` — Traefik + proxy network)
2. **Domain with DNS** pointing to your server
3. **Ports 80 + 443** open
4. **Dependencies installed**: `curl`, `jq`, `openssl`

## Quick Start

### Step 1: Generate Secrets

```bash
cd /path/to/homelab-stack/stacks/sso

# Generate all required secrets
export AUTHENTIK_SECRET_KEY=$(openssl rand -base64 32)
export AUTHENTIK_POSTGRES_PASSWORD=$(openssl rand -hex 16)
export AUTHENTIK_REDIS_PASSWORD=$(openssl rand -hex 16)
export AUTHENTIK_BOOTSTRAP_TOKEN=$(openssl rand -hex 32)

# Update .env file
cp .env.example .env
sed -i "s|^AUTHENTIK_SECRET_KEY=.*|AUTHENTIK_SECRET_KEY=$AUTHENTIK_SECRET_KEY|" .env
sed -i "s|^AUTHENTIK_POSTGRES_PASSWORD=.*|AUTHENTIK_POSTGRES_PASSWORD=$AUTHENTIK_POSTGRES_PASSWORD|" .env
sed -i "s|^AUTHENTIK_REDIS_PASSWORD=.*|AUTHENTIK_REDIS_PASSWORD=$AUTHENTIK_REDIS_PASSWORD|" .env
sed -i "s|^AUTHENTIK_BOOTSTRAP_TOKEN=.*|AUTHENTIK_BOOTSTRAP_TOKEN=$AUTHENTIK_BOOTSTRAP_TOKEN|" .env
```

### Step 2: Configure Admin Account

```bash
# Set admin email and password
nano .env
# Fill in:
# - AUTHENTIK_BOOTSTRAP_EMAIL=admin@yourdomain.com
# - AUTHENTIK_BOOTSTRAP_PASSWORD=<strong-password>
```

### Step 3: Start the Stack

```bash
docker compose up -d

# Wait for services to be healthy (~60s on first run)
docker compose ps
docker compose logs -f authentik-server
```

### Step 4: Create OIDC Providers

```bash
# Run the setup script to create providers for all services
cd ../..
./scripts/authentik-setup.sh

# For dry-run (test without making changes):
./scripts/authentik-setup.sh --dry-run
```

## Environment Variables

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `AUTHENTIK_SECRET_KEY` | Random secret for encryption | `openssl rand -base64 32` |
| `AUTHENTIK_POSTGRES_PASSWORD` | PostgreSQL password | `openssl rand -hex 16` |
| `AUTHENTIK_REDIS_PASSWORD` | Redis password | `openssl rand -hex 16` |
| `AUTHENTIK_BOOTSTRAP_EMAIL` | Initial admin email | `admin@example.com` |
| `AUTHENTIK_BOOTSTRAP_PASSWORD` | Initial admin password | `Str0ngP@ssw0rd!` |
| `AUTHENTIK_BOOTSTRAP_TOKEN` | API token for setup script | `openssl rand -hex 32` |
| `AUTHENTIK_DOMAIN` | Authentik domain | `auth.yourdomain.com` |

### OAuth Client Variables (auto-filled by setup script)

These are created automatically by `authentik-setup.sh`:

- `GRAFANA_OAUTH_CLIENT_ID` / `GRAFANA_OAUTH_CLIENT_SECRET`
- `GITEA_OAUTH_CLIENT_ID` / `GITEA_OAUTH_CLIENT_SECRET`
- `NEXTCLOUD_OAUTH_CLIENT_ID` / `NEXTCLOUD_OAUTH_CLIENT_SECRET`
- `OUTLINE_OAUTH_CLIENT_ID` / `OUTLINE_OAUTH_CLIENT_SECRET`
- `OPENWEBUI_OAUTH_CLIENT_ID` / `OPENWEBUI_OAUTH_CLIENT_SECRET`
- `PORTAINER_OAUTH_CLIENT_ID` / `PORTAINER_OAUTH_CLIENT_SECRET`

## Integration Methods

### Option A: Native OIDC (Recommended)

For services with built-in OAuth2/OIDC support, configure them directly:

#### Grafana
✅ Already configured in `stacks/monitoring/docker-compose.yml`

Environment variables:
```yaml
GF_AUTH_GENERIC_OAUTH_ENABLED=true
GF_AUTH_GENERIC_OAUTH_CLIENT_ID=${GRAFANA_OAUTH_CLIENT_ID}
GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET=${GRAFANA_OAUTH_CLIENT_SECRET}
GF_AUTH_GENERIC_OAUTH_AUTH_URL=https://${AUTHENTIK_DOMAIN}/application/o/authorize/
GF_AUTH_GENERIC_OAUTH_TOKEN_URL=https://${AUTHENTIK_DOMAIN}/application/o/token/
GF_AUTH_GENERIC_OAUTH_API_URL=https://${AUTHENTIK_DOMAIN}/application/o/userinfo/
```

#### Gitea
✅ Already configured in `stacks/productivity/docker-compose.yml`

Environment variables:
```yaml
GITEA__openid__ENABLE_OPENID_SIGNIN=true
GITEA__openid__ENABLE_OPENID_SIGNUP=true
GITEA__oauth2_client__ENABLE_AUTO_REGISTRATION=true
```

#### Outline
✅ Already configured in `stacks/productivity/docker-compose.yml`

Environment variables:
```yaml
OIDC_CLIENT_ID=${OUTLINE_OAUTH_CLIENT_ID}
OIDC_CLIENT_SECRET=${OUTLINE_OAUTH_CLIENT_SECRET}
OIDC_AUTH_URI=https://${AUTHENTIK_DOMAIN}/application/o/authorize/
OIDC_TOKEN_URI=https://${AUTHENTIK_DOMAIN}/application/o/token/
OIDC_USERINFO_URI=https://${AUTHENTIK_DOMAIN}/application/o/userinfo/
```

#### Open WebUI
✅ Already configured in `stacks/ai/docker-compose.yml`

Environment variables:
```yaml
ENABLE_OAUTH_SIGNUP=true
OAUTH_CLIENT_ID=${OPENWEBUI_OAUTH_CLIENT_ID}
OAUTH_CLIENT_SECRET=${OPENWEBUI_OAUTH_CLIENT_SECRET}
OPENID_PROVIDER_URL=https://${AUTHENTIK_DOMAIN}/application/o/open-webui/
```

#### Portainer
⚠️ Portainer CE requires ForwardAuth (see Option B)
Business Edition supports native OAuth

#### Nextcloud
✅ Configuration added, requires Social Login app installation

First-time setup:
```bash
docker exec -it nextcloud occ app:install sociallogin
docker exec -it nextcloud occ config:app:set sociallogin prevent_create_user --value=0
docker exec -it nextcloud occ config:app:set sociallogin allow_create_user --value=1
```

Then configure via Nextcloud admin UI → Settings → Social Login

### Option B: Traefik ForwardAuth (For Services Without OIDC)

For services without OAuth2 support, use Traefik middleware:

```yaml
labels:
  - "traefik.http.routers.<service>.middlewares=authentik@file"
```

**Example services:**
- Prometheus (`stacks/monitoring/docker-compose.yml`)
- Grafana OnCall (`stacks/monitoring/docker-compose.yml`)
- Portainer CE (`stacks/base/docker-compose.yml`)

When accessing these services, unauthenticated requests are redirected to `https://auth.DOMAIN` for login.

## User Groups

The setup script creates three default groups:

| Group | Purpose | Permissions |
|-------|---------|-------------|
| `homelab-admins` | Full access to all services | Admin role in all apps |
| `homelab-users` | Regular users | Standard access |
| `media-users` | Media services only | Access to Jellyfin, Sonarr, etc. |

### Assigning Groups

1. Navigate to `https://auth.DOMAIN/if/admin/`
2. Go to **Directory → Users**
3. Click on a user → **Groups** tab
4. Add to appropriate groups

### Group-Based Authorization

Some services support role mapping based on groups:

**Grafana:**
```yaml
GF_AUTH_GENERIC_OAUTH_ROLE_ATTRIBUTE_PATH=contains(groups, 'Grafana Admins') && 'Admin' || contains(groups, 'Grafana Editors') && 'Editor' || 'Viewer'
```

## Authentication Flows

### OIDC Flow (Native OAuth2)

```
1. User visits https://grafana.DOMAIN
2. Grafana redirects to https://auth.DOMAIN/application/o/authorize/
3. User logs in at Authentik
4. Authentik redirects back with authorization code
5. Grafana exchanges code for tokens
6. User authenticated
```

### ForwardAuth Flow (Traefik Middleware)

```
1. User visits https://prometheus.DOMAIN
2. Traefik middleware intercepts request
3. Middleware calls http://authentik-server:9000/outpost.goauthentik.io/auth/traefik
4. If not authenticated → redirect to https://auth.DOMAIN
5. User logs in
6. Authentik sets session cookie
7. Redirect back to original URL
8. User authenticated
```

## Health Checks

```bash
# All containers healthy
docker compose ps

# Authentik API responding
curl -sf https://auth.DOMAIN/-/health/ready/ && echo "OK"

# Admin UI accessible
curl -sf https://auth.DOMAIN/if/admin/ -o /dev/null && echo "OK"

# OIDC discovery endpoint
curl -sf https://auth.DOMAIN/application/o/.well-known/openid-configuration | jq .
```

## Troubleshooting

### Common Issues

| Symptom | Fix |
|---------|-----|
| Container exits immediately | Check `AUTHENTIK_SECRET_KEY` is set and non-empty |
| DB connection refused | Wait 30s for PostgreSQL; check `AUTHENTIK_POSTGRES_PASSWORD` matches |
| OIDC redirect mismatch | Ensure `redirect_uris` in Authentik matches exact callback URL |
| ForwardAuth loop | Use internal hostname `authentik-server:9000` not public domain |
| `ghcr.io` pull timeout | Use CN mirror (uncomment in docker-compose.yml) |
| Setup script fails | Verify `AUTHENTIK_BOOTSTRAP_TOKEN` is correct |
| Can't login after setup | Check admin password in `.env` |

### Debug Logs

```bash
# Authentik server logs
docker compose logs -f authentik-server

# Worker logs
docker compose logs -f authentik-worker

# PostgreSQL logs
docker compose logs -f postgresql

# Redis logs
docker compose logs -f redis

# Enable debug logging
# Add to .env:
AUTHENTIK_LOG_LEVEL=debug
```

### Reset Authentik

⚠️ **Warning:** This deletes all users, groups, and applications

```bash
docker compose down -v
rm -rf postgresql_data redis_data authentik_media authentik_templates
docker compose up -d
# Wait 60s, then run setup script again
```

## CN Mirror Configuration

If `ghcr.io` is inaccessible, uncomment the CN mirror in `docker-compose.yml`:

```yaml
image: swr.cn-north-4.myhuaweicloud.com/ddn-k8s/ghcr.io/goauthentik/server:2024.8.3
```

## Adding New Services

### With Native OIDC Support

1. Add service to appropriate stack
2. Add environment variables to service's `docker-compose.yml`:
   ```yaml
   OAUTH_CLIENT_ID=${NEW_SERVICE_OAUTH_CLIENT_ID}
   OAUTH_CLIENT_SECRET=${NEW_SERVICE_OAUTH_CLIENT_SECRET}
   ```
3. Add variables to root `.env`:
   ```bash
   NEW_SERVICE_OAUTH_CLIENT_ID=
   NEW_SERVICE_OAUTH_CLIENT_SECRET=
   ```
4. Update `scripts/authentik-setup.sh` to create the provider
5. Run setup script

### Without OIDC Support

1. Add service to appropriate stack
2. Add ForwardAuth middleware to Traefik labels:
   ```yaml
   labels:
     - "traefik.http.routers.<name>.middlewares=authentik@file"
   ```
3. Restart the service

## Security Best Practices

1. **Strong secrets**: Use `openssl rand -hex 16` or better
2. **HTTPS only**: All services use TLS via Traefik
3. **Secure cookies**: Authentik sets `Secure; HttpOnly; SameSite`
4. **Token expiration**: Default access tokens expire in 1 hour
5. **Rate limiting**: Configure in Authentik policies
6. **MFA**: Enable in Authentik for admin accounts
7. **Regular backups**: Backup PostgreSQL volume regularly

## Backup and Restore

### Backup

```bash
# Backup PostgreSQL
docker exec authentik-postgres pg_dump -U authentik authentik > authentik-backup-$(date +%Y%m%d).sql

# Backup volumes
tar -czf authentik-volumes-$(date +%Y%m%d).tar.gz \
  /var/lib/docker/volumes/sso_postgresql_data \
  /var/lib/docker/volumes/sso_redis_data
```

### Restore

```bash
# Restore PostgreSQL
cat authentik-backup-20240101.sql | docker exec -i authentik-postgres psql -U authentik authentik

# Restart services
docker compose restart authentik-server authentik-worker
```

## Additional Resources

- [Authentik Documentation](https://docs.goauthentik.io/)
- [OIDC Specification](https://openid.net/connect/)
- [Traefik ForwardAuth](https://doc.traefik.io/traefik/middlewares/http/forwardauth/)
- [HomeLab Stack Documentation](../../README.md)

## Support

- GitHub Issues: [HomeLab Stack](https://github.com/yourusername/homelab-stack/issues)
- Authentik Discord: [Join](https://goauthentik.io/discord)
