# Productivity Stack

Self-hosted productivity suite: Git code hosting, password management, team wiki, and documentation.

## Services

| Service | Domain | Description |
|---------|--------|-------------|
| **Gitea** | `git.{domain}` | Lightweight Git server with SSH & HTTP access |
| **Vaultwarden** | `vault.{domain}` | Self-hosted password manager (Bitwarden-compatible) |
| **Outline** | `docs.{domain}` | Wiki & knowledge base for teams |
| **BookStack** | `wiki.{domain}` | Documentation platform with MySQL backend |

## Architecture

```
                        Traefik (HTTPS reverse proxy)
                              |
        +----------+----------+----------+--------+
        |          |          |          |        |
     Gitea    Vaultwarden   Outline  BookStack    |
        |          |          |          |        |
        +----------+----------+----------+--------+
                              |
              +---------------+---------------+
              |               |               |
           Postgres          Redis         MariaDB
        (Gitea, Vault,   (Outline       (BookStack)
         Outline DB)      cache)
```

## Prerequisites

1. **Networks**: `proxy` and `databases` networks must exist:
   ```bash
   docker network create proxy 2>/dev/null
   docker network create databases 2>/dev/null
   ```

2. **Databases stack**: Start the databases first:
   ```bash
   cd ../databases && docker compose up -d
   ```

3. **SSO/Auth**: Configure Authentik (see [SSO stack](../sso/)) for OAuth2/OIDC.

4. **Environment**: Copy `.env.example` to `.env` and fill all values:
   ```bash
   cp .env.example .env
   ```

## Quick Start

```bash
# Generate secrets
openssl rand -hex 32           # OUTLINE_SECRET_KEY, OUTLINE_UTILS_SECRET
openssl rand -base64 48        # VAULTWARDEN_ADMIN_TOKEN
openssl rand -base64 32        # GITEA_OAUTH2_JWT_SECRET
echo "base64:$(openssl rand -base64 32)"  # BOOKSTACK_APP_KEY

# Start services
docker compose up -d

# Initial setup
# - Gitea: visit git.yourdomain.com (first user = admin)
# - Vaultwarden: visit vault.yourdomain.com/admin
# - Outline: visit docs.yourdomain.com (SSO via Authentik)
# - BookStack: visit wiki.yourdomain.com (SSO via Authentik)
```

## Service Details

### Gitea
- **Image**: `gitea/gitea:1.22.3`
- **Database**: PostgreSQL
- **SSH**: Configurable port (default 22 inside container)
- **Features**: Git hosting, pull requests, issues, OAuth2, Actions runner
- **First-run**: Create admin account on first visit to git.yourdomain.com

### Vaultwarden
- **Image**: `vaultwarden/server:1.32.0`
- **Database**: PostgreSQL
- **Admin token**: Set `VAULTWARDEN_ADMIN_TOKEN` (`openssl rand -base64 48`)
- **Signups**: Disabled by default (`SIGNUPS_ALLOWED=false`)
- **SMTP**: Configure for invite/password reset flows
- **Compatibility**: Bitwarden desktop/mobile apps compatible

### Outline
- **Image**: `outlinewiki/outline:0.80.2`
- **Database**: PostgreSQL
- **Cache**: Redis
- **Storage**: Local filesystem (`outline-data` volume)
- **Auth**: OIDC via Authentik (configure client in Authentik first)
- **Features**: Rich text editing, Slack integration, version history

### BookStack
- **Image**: `lscr.io/linuxserver/bookstack:24.10.20241031`
- **Database**: MariaDB
- **Auth**: Standard (local) or OIDC via Authentik
- **APP_KEY**: Generate with `echo "base64:$(openssl rand -base64 32)"`
- **Features**: Books, chapters, pages, shelf organization

## Environment Variables

| Variable | Description | Generate |
|----------|-------------|----------|
| `DOMAIN` | Your root domain | - |
| `TZ` | Timezone | - |
| `AUTHENTIK_DOMAIN` | Authentik domain | - |
| `GITEA_DB_PASSWORD` | PostgreSQL password for Gitea | - |
| `VAULTWARDEN_DB_PASSWORD` | PostgreSQL password for Vaultwarden | - |
| `OUTLINE_DB_PASSWORD` | PostgreSQL password for Outline | - |
| `BOOKSTACK_DB_PASSWORD` | MariaDB password for BookStack | - |
| `REDIS_PASSWORD` | Redis password | - |
| `VAULTWARDEN_ADMIN_TOKEN` | Vaultwarden admin token | `openssl rand -base64 48` |
| `OUTLINE_SECRET_KEY` | Outline secret key | `openssl rand -hex 32` |
| `OUTLINE_UTILS_SECRET` | Outline utils secret | `openssl rand -hex 32` |
| `GITEA_OAUTH2_JWT_SECRET` | Gitea OAuth2 JWT secret | `openssl rand -base64 32` |
| `BOOKSTACK_APP_KEY` | BookStack app key | `echo "base64:$(openssl rand -base64 32)"` |
| `OUTLINE_OAUTH_CLIENT_ID` | Authentik client ID for Outline | (from Authentik) |
| `OUTLINE_OAUTH_CLIENT_SECRET` | Authentik client secret for Outline | (from Authentik) |
| `BOOKSTACK_OIDC_CLIENT_ID` | Authentik client ID for BookStack | (from Authentik) |
| `BOOKSTACK_OIDC_CLIENT_SECRET` | Authentik client secret for BookStack | (from Authentik) |

## Traefik Routing

| Service | Subdomain | Router Name |
|---------|-----------|-------------|
| Gitea | `git.{DOMAIN}` | `gitea` |
| Vaultwarden | `vault.{DOMAIN}` | `vaultwarden` |
| Outline | `docs.{DOMAIN}` | `outline` |
| BookStack | `wiki.{DOMAIN}` | `bookstack` |

All routes use HTTPS (websecure entrypoint) with TLS enabled.

## Startup Order

Services use `depends_on` with health conditions:
- **Outline** waits for `homelab-postgres` and `homelab-redis` to be healthy
- **BookStack** waits for `homelab-mariadb` to be healthy
- **Databases** must be started from the `databases` stack first

## Volumes

| Volume | Description |
|--------|-------------|
| `gitea-data` | Gitea Git data, config, and repositories |
| `vaultwarden-data` | Vaultwarden SQLite DB and attachments |
| `outline-data` | Outline uploaded files and attachments |
| `bookstack-data` | BookStack config, uploads, and backups |

## Healthchecks

All services include healthchecks:
- Gitea: `curl http://localhost:3000/`
- Vaultwarden: `wget -qO- http://localhost:80/alive`
- Outline: `curl http://localhost:3000/_health`
- BookStack: `curl http://localhost:80/login`

## Maintenance

```bash
# View logs
docker compose logs -f gitea
docker compose logs -f vaultwarden
docker compose logs -f outline
docker compose logs -f bookstack

# Restart a service
docker compose restart gitea

# Rebuild after config changes
docker compose up -d --force-recreate

# Backup volumes (from homelab root)
docker run --rm -v homelab-stack_gitea-data:/data -v $(pwd)/backups:/backups alpine \
  tar czf /backups/gitea-data.tar.gz -C /data .
```

## Cost Estimate

| Service | Est. RAM | Notes |
|---------|----------|-------|
| Gitea | ~500MB | Lightweight Git |
| Vaultwarden | ~300MB | Bitwarden Rust implementation |
| Outline | ~800MB | Node.js application |
| BookStack | ~400MB | PHP/Laravel |
| **Total** | **~2GB** | Fits $5-10/month VPS |

For ~$170/month budget, this stack runs comfortably on a $10-20 VPS with room for other services.
