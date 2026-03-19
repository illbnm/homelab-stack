# 💼 Productivity Stack

> Self-hosted Git, knowledge management, and team wikis.

**Services:** Gitea · Vaultwarden · Outline · BookStack  
**Bounty:** $170 USDT ([#4](https://github.com/illbnm/homelab-stack/issues/4))

---

## 🏗️ Architecture

```
User (Browser)
    │
    ├──► https://git.${DOMAIN}   →  Gitea (Git repos, PRs, issues)
    │                                Auth: Gitea native or OAuth2
    │
    ├──► https://vault.${DOMAIN} →  Vaultwarden (password manager)
    │                                Auth: Master password
    │
    ├──► https://docs.${DOMAIN}  →  Outline (team wiki, Notion alternative)
    │                                Auth: Authentik SSO (OIDC)
    │
    └──► https://wiki.${DOMAIN}  →  BookStack (book/document wiki)
                                     Auth: Standard or OIDC

Shared: PostgreSQL (homelab-postgres), Redis (homelab-redis)
```

**Gitea** is a lightweight Git service (GitHub alternative).  
**Vaultwarden** is a self-hosted Bitwarden server for passwords and secrets.  
**Outline** is a team wiki for collaborative documentation.  
**BookStack** is a simple book-based wiki for SOPs and guides.

---

## 🚀 Quick Start

### 1. Prerequisites

```bash
# Base infrastructure must be running first
docker network create proxy 2>/dev/null || true
docker network create databases 2>/dev/null || true

# Shared databases must exist
# See stacks/databases/docker-compose.yml or homelab.md for database setup
```

### 2. Configure environment

```bash
cd stacks/productivity
cp .env.example .env
nano .env
```

Required `.env` variables:

```env
DOMAIN=yourdomain.com
TZ=Asia/Shanghai

# Gitea
GITEA_DB_PASSWORD=<generate-secure-password>
GITEA_OAUTH2_JWT_SECRET=<generate-secure-password>

# Vaultwarden
VAULTWARDEN_ADMIN_TOKEN=<generate-secure-password>
VAULTWARDEN_DB_PASSWORD=<generate-secure-password>

# Outline
OUTLINE_SECRET_KEY=<generate-32-char-secret>
OUTLINE_UTILS_SECRET=<generate-32-char-secret>
OUTLINE_DB_PASSWORD=<generate-secure-password>
REDIS_PASSWORD=<generate-secure-password>
OUTLINE_OAUTH_CLIENT_ID=<from Authentik>
OUTLINE_OAUTH_CLIENT_SECRET=<from Authentik>
AUTHENTIK_DOMAIN=auth.yourdomain.com

# BookStack
BOOKSTACK_APP_KEY=<generate-32-char-secret>
BOOKSTACK_DB_PASSWORD=<generate-secure-password>
BOOKSTACK_OIDC_CLIENT_ID=<from Authentik>
BOOKSTACK_OIDC_CLIENT_SECRET=<from Authentik>
```

### 3. Run Authentik setup (required for Outline + BookStack OIDC)

```bash
./scripts/setup-authentik.sh
```

This script creates OIDC applications for Outline and BookStack in Authentik and prints the client credentials for your `.env`.

### 4. Start services

```bash
docker compose up -d
```

### 5. Initial setup per service

#### Gitea — first-run wizard

1. Visit `https://git.${DOMAIN}`
2. Database: PostgreSQL, Host: `homelab-postgres`, Name: `gitea`, User: `gitea`
3. Domain: `git.${DOMAIN}`, URL: `https://git.${DOMAIN}`
4. Create admin account
5. (Optional) Enable OAuth2 in Settings → Authentication → Add OAuth2

#### Vaultwarden — create first account

1. Visit `https://vault.${DOMAIN}`
2. Create master password (write it down — no recovery!)
3. Download the Bitwarden browser extension and connect to `https://vault.${DOMAIN}`

#### Outline — initial admin

1. Visit `https://docs.${DOMAIN}`
2. Sign in with Authentik SSO
3. First user becomes admin automatically

#### BookStack — create admin

1. Visit `https://wiki.${DOMAIN}`
2. Create admin account (or sign in via OIDC if configured)

---

## 🌐 Service URLs (after DNS + Traefik)

| Service | URL | Auth Method |
|---------|-----|-------------|
| Gitea | `https://git.${DOMAIN}` | Native (or OAuth2) |
| Vaultwarden | `https://vault.${DOMAIN}` | Master password |
| Outline | `https://docs.${DOMAIN}` | Authentik OIDC |
| BookStack | `https://wiki.${DOMAIN}` | Standard or OIDC |

---

## 🔐 SSO / Authentik Integration

### Outline — OIDC setup

Authentik creates the OIDC application automatically via `scripts/setup-authentik.sh`. The `.env` values `OUTLINE_OAUTH_CLIENT_ID` and `OUTLINE_OAUTH_CLIENT_SECRET` are set automatically.

After starting:
1. Visit `https://docs.${DOMAIN}`
2. Click "Sign in with Authentik"
3. Your Authentik account creates the first Outline account automatically

### BookStack — OIDC setup

BookStack also gets OIDC credentials from `scripts/setup-authentik.sh`. Set in `.env`:
- `BOOKSTACK_AUTH_METHOD=oidc`
- `BOOKSTACK_OIDC_CLIENT_ID`
- `BOOKSTACK_OIDC_CLIENT_SECRET`

### Gitea — OAuth2 setup

Gitea can act as an OAuth2 client to Authentik:
1. Gitea → Settings → Authentication → Add OAuth2 Source
2. In Authentik: create an OIDC application for Gitea
3. Client ID + Secret → paste into Gitea

---

## 📁 File Structure

```
stacks/productivity/
├── docker-compose.yml
├── .env
└── data/

Docker volumes:
  gitea-data       → /data (repos, issues, wiki)
  vaultwarden-data → /data (encrypted vault)
  outline-data     → /var/lib/outline/data (attachments, search index)
  bookstack-data   → /config (uploads, config)

Shared networks:
  proxy      → Traefik access
  databases  → PostgreSQL + Redis
```

---

## 🔧 Common Tasks

### Backup Gitea repositories

```bash
# Full backup (includes repos, database, settings)
docker exec -it gitea gitea dump -c /data/gitea/conf/app.ini

# Backup lands in /data/gitea/ directory — copy it off:
docker cp gitea:/data/gitea/gitea-dump-*.zip ./backups/
```

### Restore a Gitea backup

```bash
# Stop Gitea
docker compose stop gitea

# Extract backup
docker exec -it gitea rm -rf /data/gitea
docker exec -it gitea mkdir -p /data/gitea
docker cp gitea-dump-*.zip gitea:/data/gitea/
docker exec -it gitea unzip /data/gitea/gitea-dump-*.zip -d /data/gitea

# Restart
docker compose start gitea
```

### Add a Vaultwarden organization

1. Vaultwarden → Organization → Create
2. Invite users, create collections (e.g. "Work", "Personal")
3. Share passwords from personal vault to collections

### Import passwords into Vaultwarden

1. Vaultwarden → Tools → Import
2. Select format (Bitwarden CSV, LastPass CSV, 1Password CSV, etc.)
3. Upload file

### Connect Outline to Slack (optional)

1. Outline → Settings → Integrations → Slack
2. Paste Slack webhook URL
3. Get notified when docs are updated

### Migrate BookStack content

```bash
# Export
docker exec -it bookstack php /app/artisan books:export-all

# Import
docker exec -it bookstack php /app/artisan books:import <file>
```

---

## 🏳️ Service Limitations

- **Vaultwarden** — invite-only (no public signups): `SIGNUPS_ALLOWED=false` in compose
- **Gitea** — needs the database `gitea` created in PostgreSQL first
- **Outline** — requires Redis for caching and background jobs
- **BookStack** — needs MariaDB running (see `homelab-postgres` or dedicated `homelab-mariadb`)

---

## 🐛 Troubleshooting

### Gitea shows "Database connection failed"

1. Verify PostgreSQL is running: `docker compose ps`
2. Create the `gitea` database:
   ```bash
   docker exec -it homelab-postgres psql -U postgres -c "CREATE DATABASE gitea;"
   ```
3. Check connection from Gitea container:
   ```bash
   docker exec -it gitea nc -zv homelab-postgres 5432
   ```

### Outline is very slow

- Redis is required for Outline performance. Verify Redis is running:
  ```bash
  docker exec -it homelab-redis redis-cli ping
  ```
- Check Outline logs for search indexing issues:
  ```bash
  docker compose logs outline | tail -30
  ```

### BookStack OIDC login not working

1. Verify `BOOKSTACK_AUTH_METHOD=oidc` in `.env`
2. Check BookStack logs: `docker compose logs bookstack | grep -i oidc`
3. Verify callback URL in Authentik matches: `https://wiki.${DOMAIN}/oidc/authentik/callback`

### Vaultwarden cannot send emails (for 2FA reset)

Vaultwarden email is disabled in the compose (`mailer__ENABLED=false`). For password recovery:
- Set a strong master password you won't forget
- Or enable email in Vaultwarden config with an SMTP server

### All services — check database connectivity

```bash
# PostgreSQL (Gitea, Outline, Vaultwarden)
docker exec -it homelab-postgres psql -U postgres -l

# Redis (Outline)
docker exec -it homelab-redis redis-cli ping
```

---

## 🔄 Update services

```bash
cd stacks/productivity
docker compose pull
docker compose up -d
```

To update a specific service:
```bash
docker compose pull gitea && docker compose up -d gitea
```

---

## 🗑️ Tear down

```bash
cd stacks/productivity
docker compose down        # keeps volumes
docker compose down -v    # removes volumes (loses all data!)
```

---

## 📋 Acceptance Criteria

- [x] All 4 services start with health checks
- [x] Gitea runs with PostgreSQL, OAuth2 JWT configured
- [x] Vaultwarden runs with invite-only mode
- [x] Outline OIDC configured via Authentik
- [x] BookStack OIDC configured via Authentik
- [x] All services behind Traefik reverse proxy
- [x] Image tags are pinned versions
- [x] README documents full setup, SSO integration, and common tasks
