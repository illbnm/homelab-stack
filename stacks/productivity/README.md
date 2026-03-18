# Productivity Stack

Self-hosted productivity tools for your homelab: Git hosting, password management, knowledge base, PDF tools, and whiteboard.

## Services

| Service | URL | Description |
|---------|-----|-------------|
| Gitea | `https://git.${DOMAIN}` | Lightweight Git hosting |
| Gitea Runner | - | CI/CD runner for Gitea Actions |
| Vaultwarden | `https://vault.${DOMAIN}` | Bitwarden-compatible password manager |
| Outline | `https://docs.${DOMAIN}` | Team knowledge base (requires OIDC) |
| BookStack | `https://wiki.${DOMAIN}` | Documentation platform / Wiki |
| Stirling-PDF | `https://pdf.${DOMAIN}` | PDF manipulation tools |
| Excalidraw | `https://draw.${DOMAIN}` | Virtual whiteboard |

## Prerequisites

1. **Base Stack** running (Traefik)
2. **Databases Stack** running (PostgreSQL, Redis, MariaDB)
3. **SSO Stack** running (Authentik) - optional but recommended for Outline

## Quick Start

```bash
# 1. Copy and configure environment
cp .env.example .env
nano .env

# 2. Generate required secrets
# Gitea secrets
openssl rand -hex 32  # GITEA_SECRET_KEY
openssl rand -hex 32  # GITEA_INTERNAL_TOKEN
openssl rand -hex 32  # GITEA_OAUTH2_JWT_SECRET

# Vaultwarden admin token
openssl rand -base64 48  # VAULTWARDEN_ADMIN_TOKEN

# Outline secrets
openssl rand -hex 32  # OUTLINE_SECRET_KEY
openssl rand -hex 32  # OUTLINE_UTILS_SECRET

# BookStack APP_KEY
echo "base64:$(openssl rand -base64 32)"  # BOOKSTACK_APP_KEY

# 3. Start the stack
docker compose up -d

# 4. Check logs
docker compose logs -f
```

## Configuration

### Gitea

1. First access creates admin account
2. Get runner token: **Site Administration → Actions → Runners → Create new Runner token**
3. Add token to `.env` as `GITEA_RUNNER_TOKEN`
4. Restart runner: `docker compose restart gitea-runner`

**OIDC Setup (Authentik):**
1. In Authentik, create OAuth2 provider for Gitea
2. Set redirect URI: `https://git.${DOMAIN}/user/oauth2/authentik/callback`
3. Copy client ID/secret to `.env`

### Vaultwarden

1. Access admin panel: `https://vault.${DOMAIN}/admin`
2. Login with `VAULTWARDEN_ADMIN_TOKEN`
3. Invite users (if `INVITATIONS_ALLOWED=true`)
4. Browser extension: Use `https://vault.${DOMAIN}` as server URL

**Important:** HTTPS is required for browser extensions to work.

### Outline

**Requires OIDC authentication** (Authentik recommended):

1. Create OAuth2 provider in Authentik for Outline
2. Set redirect URIs:
   - `https://docs.${DOMAIN}/auth/oidc.callback`
3. Copy client ID/secret to `.env`

### BookStack

1. First login: `admin@admin.com` / `password`
2. Change default credentials immediately
3. OIDC optional - set `BOOKSTACK_AUTH_METHOD=oidc` to enable

### Stirling-PDF

- No setup required
- Optional authentication via `STIRLING_SECURITY_ENABLED=true`

### Excalidraw

- No setup required
- Drawings stored in browser localStorage
- Share via export or live collaboration (requires additional setup)

## Environment Variables

See `.env.example` for all available options.

### Required Variables

| Variable | Description |
|----------|-------------|
| `DOMAIN` | Your domain name |
| `GITEA_DB_PASSWORD` | PostgreSQL password for Gitea |
| `VAULTWARDEN_ADMIN_TOKEN` | Admin access token |
| `VAULTWARDEN_DB_PASSWORD` | PostgreSQL password for Vaultwarden |
| `OUTLINE_SECRET_KEY` | Outline encryption key |
| `OUTLINE_UTILS_SECRET` | Outline utility secret |
| `OUTLINE_DB_PASSWORD` | PostgreSQL password for Outline |
| `BOOKSTACK_APP_KEY` | Laravel APP_KEY |
| `BOOKSTACK_DB_PASSWORD` | MariaDB password for BookStack |
| `REDIS_PASSWORD` | Redis password (from databases stack) |

## Health Checks

All services include health checks. Verify status:

```bash
docker compose ps
```

## Troubleshooting

### Gitea Actions not working
- Check runner token is valid
- Verify runner is registered: `docker compose logs gitea-runner`

### Vaultwarden browser extension won't connect
- Ensure HTTPS is working
- Check `DOMAIN` is set correctly
- Verify certificate is valid

### Outline shows "Authentication required"
- OIDC must be configured with Authentik
- Check OAuth client credentials in `.env`

### Database connection errors
- Verify databases stack is running
- Check passwords match between stacks
- Ensure `databases` network exists: `docker network ls`

## Security Notes

- All services use HTTPS via Traefik
- Registrations disabled by default (enable per service if needed)
- Admin tokens should be strong random strings
- Consider enabling 2FA on Authentik for production

## Backup

```bash
# Backup volumes
docker compose down
tar -czf productivity-backup-$(date +%Y%m%d).tar.gz \
  /var/lib/docker/volumes/gitea-data \
  /var/lib/docker/volumes/vaultwarden-data \
  /var/lib/docker/volumes/outline-data \
  /var/lib/docker/volumes/bookstack-data

docker compose up -d
```
