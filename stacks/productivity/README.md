# Productivity Stack

> Self-hosted productivity suite: Git hosting, password management, team wiki, PDF tools, and documentation platform.

**Bounty:** [#5 — Productivity Stack — $160 USDT](https://github.com/illbnm/homelab-stack/issues/5)

## Services

| Service | URL | Port | Purpose |
|---------|-----|------|---------|
| Gitea | `https://git.${DOMAIN}` | 3000 | Git code hosting |
| Vaultwarden | `https://vault.${DOMAIN}` | 80 | Password manager (Bitwarden-compatible) |
| Outline | `https://docs.${DOMAIN}` | 3000 | Team knowledge base |
| Stirling PDF | `https://pdf.${DOMAIN}` | 8080 | PDF manipulation tool |
| BookStack | `https://wiki.${DOMAIN}` | 80 | Documentation wiki |

## Architecture

```
Internet
  │
  ▼
Traefik (TLS termination, reverse proxy)
  │
  ├──► git.${DOMAIN} ──────► Gitea (Git repositories)
  ├──► vault.${DOMAIN} ────► Vaultwarden (Password manager)
  ├──► docs.${DOMAIN} ─────► Outline (Knowledge base)
  ├──► pdf.${DOMAIN} ──────► Stirling PDF (PDF tools)
  └──► wiki.${DOMAIN} ─────► BookStack (Documentation)

Shared Infrastructure:
  ├── PostgreSQL (homelab-postgres) — Gitea, Vaultwarden, Outline
  ├── Redis (homelab-redis) — Outline
  └── MariaDB (homelab-mariadb) — BookStack
```

## Prerequisites

1. **Base stack deployed** — `./install.sh` from repo root
2. **Databases stack deployed** — `stacks/databases/docker-compose.yml`
3. **Authentik SSO deployed** — `stacks/sso/docker-compose.yml` (required for OIDC)
4. **Docker networks created:**
   ```bash
   docker network create proxy
   docker network create databases
   ```

## Quick Start

```bash
# 1. Link root .env
ln -sf ../../.env .env

# 2. Generate required secrets
export VAULTWARDEN_ADMIN_TOKEN=$(openssl rand -base64 48)
export GITEA_OAUTH2_JWT_SECRET=$(openssl rand -hex 32)
export OUTLINE_SECRET_KEY=$(openssl rand -hex 32)
export OUTLINE_UTILS_SECRET=$(openssl rand -hex 32)
export BOOKSTACK_APP_KEY="base64:$(openssl rand -base64 32)"

# Add these to your .env file

# 3. Run database migrations (first time only)
# Gitea:
docker compose run --rm gitea bash -c "gitea admin user create --admin --username admin --email admin@${DOMAIN} --password \${ADMIN_PASSWORD} --must-change-password=false" || true

# BookStack:
docker compose run --rm bookstack php artisan key:generate || true

# 4. Start services
docker compose up -d

# 5. Verify health
docker compose ps
```

## Configuration

### Gitea

**Initial Setup:**
1. Visit `https://git.${DOMAIN}`
2. First visit redirects to setup wizard
3. Database: select PostgreSQL, host `homelab-postgres`, database `gitea`
4. Domain: `git.${DOMAIN}`, URL: `https://git.${DOMAIN}`
5. Disable registration after admin account creation

**Authentik OIDC Setup (after Authentik is running):**
```bash
# Run the Authentik setup script
./scripts/setup-authentik.sh
```

This creates an OAuth2 application in Authentik for Gitea.

**Key Settings:**
- `GITEA__server__ROOT_URL=https://git.${DOMAIN}`
- `GITEA__oauth2__ENABLE=true`
- Register new OAuth2 app in Authentik with redirect URI: `https://git.${DOMAIN}/user/oauth2/Authentik/callback`

### Vaultwarden

**Admin Panel:**
- URL: `https://vault.${DOMAIN}/admin`
- Token: `VAULTWARDEN_ADMIN_TOKEN` from `.env`

**Disable Registration:**
```bash
# Already set: SIGNUPS_ALLOWED=false
# Only admin can create invitations
```

**Browser Extension:**
- Install Bitwarden browser extension
- Self-host config: `https://vault.${DOMAIN}`
- Login with your vault credentials

**Environment Variables:**
```bash
DOMAIN=https://vault.${DOMAIN}
SIGNUPS_ALLOWED=false
ADMIN_TOKEN=${VAULTWARDEN_ADMIN_TOKEN}
DATABASE_URL=postgresql://vaultwarden:${VAULTWARDEN_DB_PASSWORD}@homelab-postgres:5432/vaultwarden
```

### Outline

**Authentik OIDC Setup:**
1. Create OAuth2 application in Authentik:
   - Name: `Outline`
   - Redirect URI: `https://docs.${DOMAIN}/auth/oidc.callback`
   - Scopes: `openid profile email`
2. Copy Client ID and Secret to `.env`
3. Restart Outline container

**Outline Environment Variables:**
```bash
SECRET_KEY=${OUTLINE_SECRET_KEY}
DATABASE_URL=postgres://outline:${OUTLINE_DB_PASSWORD}@homelab-postgres:5432/outline?sslmode=disable
REDIS_URL=redis://:${REDIS_PASSWORD}@homelab-redis:6379
URL=https://docs.${DOMAIN}
```

**File Storage:**
- Local storage configured: `/var/lib/outline/data`
- To use MinIO: set `FILE_STORAGE=s3` and configure S3 credentials

### Stirling PDF

**Features:**
- Merge, split, rotate PDF files
- Convert between PDF and images, Word, Excel
- OCR (optical character recognition)
- Watermark, stamp, sign PDF
- Compress, repair, compare PDF
- Dark mode supported

**Usage:**
1. Visit `https://pdf.${DOMAIN}`
2. Select desired operation from sidebar
3. Upload PDF file
4. Configure options
5. Download processed file

**Security Note:**
- Default: `DOCKER_ENABLE_SECURITY=false` (open access)
- For security mode, set `DOCKER_ENABLE_SECURITY=true` and configure users

### BookStack

**Admin Panel:**
- URL: `https://wiki.${DOMAIN}/admin`
- First user becomes admin (register at `/register` or via admin invite)

**Authentik OIDC Setup:**
1. Create OAuth2 application in Authentik:
   - Name: `BookStack`
   - Redirect URI: `https://wiki.${DOMAIN}/oidc/provider/Authentik/callback`
   - Scopes: `openid profile email`
2. Set `BOOKSTACK_AUTH_METHOD=oidc`
3. Configure OIDC vars from Authentik setup

**Permissions:**
- Libraries → Shelf → Books → Chapters → Pages
- Roles: Admin, Editor, Viewer, Public
- Create custom roles for team access control

## Service Health Endpoints

| Service | Health Check |
|---------|-------------|
| Gitea | `curl -sf http://localhost:3000/` → 200 |
| Vaultwarden | `curl -sf http://localhost:80/alive` → OK |
| Outline | `curl -sf http://localhost:3000/_health` → JSON |
| Stirling PDF | `curl -sf http://localhost:8080/api/v1/info/health` → JSON |
| BookStack | `curl -sf http://localhost:80` → 200 |

## Environment Variables Reference

| Variable | Required | Description |
|----------|----------|-------------|
| `DOMAIN` | Yes | Base domain, e.g. `home.example.com` |
| `TZ` | Yes | Timezone, e.g. `Asia/Shanghai` |
| `AUTHENTIK_DOMAIN` | Yes | Authentik domain, e.g. `auth.home.example.com` |
| `POSTGRES_PASSWORD` | Yes | PostgreSQL master password |
| `REDIS_PASSWORD` | Yes | Redis password |
| `MARIADB_ROOT_PASSWORD` | Yes | MariaDB root password |
| `GITEA_DB_PASSWORD` | Yes | Gitea database password |
| `VAULTWARDEN_DB_PASSWORD` | Yes | Vaultwarden database password |
| `VAULTWARDEN_ADMIN_TOKEN` | Yes | Vaultwarden admin panel token |
| `OUTLINE_DB_PASSWORD` | Yes | Outline database password |
| `OUTLINE_SECRET_KEY` | Yes | Outline JWT secret |
| `OUTLINE_UTILS_SECRET` | Yes | Outline utility secret |
| `BOOKSTACK_DB_PASSWORD` | Yes | BookStack database password |
| `BOOKSTACK_APP_KEY` | Yes | BookStack app key |
| `GITEA_OAUTH_CLIENT_ID` | No | Filled by `setup-authentik.sh` |
| `OUTLINE_OAUTH_CLIENT_ID` | No | Filled by `setup-authentik.sh` |
| `BOOKSTACK_OIDC_CLIENT_ID` | No | Filled by `setup-authentik.sh` |

## Common Problems

### Gitea 502 after restart
- Wait 60s for health check to pass
- Check: `docker logs gitea`

### Vaultwarden slow performance
- Database query: ensure PostgreSQL index on `ciphers.user_id`
- Increase `BCRYPT_ROUNDS` if CPU allows

### Outline won't send emails
- Configure SMTP in Authentik or use built-in SMTP
- Check `outline` container logs: `docker logs outline`

### Stirling PDF file upload fails
- Check `stirling-pdf-data` volume is mounted correctly
- Default max upload: 100MB (configured in java args)

### BookStack 500 error
- Check `.env` APP_KEY is set correctly
- Run: `docker compose exec bookstack php artisan cache:clear`

## Backup

Add to `scripts/backup.sh` targets:
```bash
--target productivity)
  docker run --rm \
    -v homelab-stirling-pdf_data:/data \
    -v $(pwd)/backups:/backups \
    alpine tar czf /backups/productivity-$(date +%Y%m%d).tar.gz /data
  ;;
```

## Networks

| Network | Purpose |
|---------|---------|
| `proxy` | Traefik reverse proxy access |
| `databases` | Shared PostgreSQL, Redis, MariaDB |
