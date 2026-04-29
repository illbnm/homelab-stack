# Productivity Stack

Self-hosted productivity suite: Git hosting, password management, knowledge base, documentation, PDF tools, and online whiteboard.

## What's Included

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| Gitea | 1.22.2 | `git.<DOMAIN>` | Self-hosted Git service |
| Gitea Act Runner | 0.2.11 | *(internal)* | CI/CD runner for Gitea Actions |
| Vaultwarden | 1.32.0 | `vault.<DOMAIN>` | Bitwarden-compatible password manager |
| Outline | 0.80.2 | `docs.<DOMAIN>` | Team knowledge base / wiki |
| BookStack | 24.10 | `wiki.<DOMAIN>` | Documentation platform |
| Stirling PDF | 0.30.2 | `pdf.<DOMAIN>` | PDF processing toolkit |
| Excalidraw | latest | `draw.<DOMAIN>` | Online collaborative whiteboard |

## Architecture

```
Internet
    │
    ▼
[Traefik :443]
    │
    ├──► git.<DOMAIN>    ──► [Gitea :3000] ──► [PostgreSQL]
    │                       [Gitea Runner]    (databases network)
    │
    ├──► vault.<DOMAIN>  ──► [Vaultwarden :80 + :3012 WS] ──► [PostgreSQL]
    │
    ├──► docs.<DOMAIN>   ──► [Outline :3000] ──► [PostgreSQL + Redis]
    │
    ├──► wiki.<DOMAIN>   ──► [BookStack :80] ──► [MariaDB]
    │
    ├──► pdf.<DOMAIN>    ──► [Stirling PDF :8080]
    │
    └──► draw.<DOMAIN>   ──► [Excalidraw :80]
```

## Prerequisites

- Base stack running (Traefik on `proxy` network)
- **Databases stack running** (PostgreSQL + Redis + MariaDB on `databases` network)
- SMTP server for Vaultwarden (required for 2FA)

## Quick Start

```bash
cd stacks/productivity
cp .env.example .env
vim .env  # Fill in all required values

# Generate secrets
openssl rand -hex 32  # for GITEA_SECRET_KEY, GITEA_OAUTH2_JWT_SECRET, OUTLINE_SECRET_KEY, OUTLINE_UTILS_SECRET
openssl rand -base64 48  # for VAULTWARDEN_ADMIN_TOKEN
echo "base64:$(openssl rand -base64 32)"  # for BOOKSTACK_APP_KEY

# Symlink shared .env (or use local)
# ln -sf ../../.env .env

docker compose up -d
```

## Configuration

### Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `DOMAIN` | ✅ | Base domain |
| `TZ` | ✅ | Timezone |
| `PUID`/`PGID` | ✅ | User/Group IDs |
| `GITEA_DB_PASSWORD` | ✅ | PostgreSQL password for Gitea |
| `GITEA_SECRET_KEY` | ✅ | Gitea internal secret |
| `GITEA_OAUTH2_JWT_SECRET` | ✅ | JWT signing key |
| `VAULTWARDEN_ADMIN_TOKEN` | ✅ | Admin panel access token |
| `OUTLINE_SECRET_KEY` | ✅ | Outline encryption key |
| `OUTLINE_UTILS_SECRET` | ✅ | Outline utility secret |
| `BOOKSTACK_APP_KEY` | ✅ | Laravel app key (format: `base64:...`) |
| `REDIS_PASSWORD` | ✅ | Must match databases stack |
| `SMTP_*` | ✅ | SMTP settings for Vaultwarden |

### Service URLs

| Service | URL |
|---------|-----|
| Gitea | `https://git.<DOMAIN>` |
| Vaultwarden | `https://vault.<DOMAIN>` |
| Outline | `https://docs.<DOMAIN>` |
| BookStack | `https://wiki.<DOMAIN>` |
| Stirling PDF | `https://pdf.<DOMAIN>` |
| Excalidraw | `https://draw.<DOMAIN>` |

## Post-Deploy Setup

### 1. Gitea — First Admin Account

1. Open `https://git.<DOMAIN>`
2. First registered user becomes admin (registration is **disabled** after first user)
3. To create additional users: login as admin → **Site Administration → User Accounts → Create**

### 2. Gitea — Enable Actions / Add Runner

1. Login as admin → **Site Administration → Actions → Runners**
2. Click **New Runner** → copy the registration token
3. Set `GITEA_RUNNER_TOKEN` in `.env`
4. Restart runner: `docker compose restart gitea-runner`

### 3. Gitea — Authentik OIDC (Optional)

1. In Authentik, create an OAuth2/OpenID Provider for Gitea
2. Set redirect URI: `https://git.<DOMAIN>/user/oauth2/Authentik/callback`
3. In Gitea: **Site Administration → Authentication Sources → Add → OAuth2**
   - Provider: Custom
   - Client ID/Secret: from Authentik
   - Authorization/Token/User Info endpoints: from Authentik provider

### 4. Vaultwarden — Admin Panel

1. Open `https://vault.<DOMAIN>/admin`
2. Enter `VAULTWARDEN_ADMIN_TOKEN` to access
3. Verify SMTP settings under **SMTP Email Settings**
4. Under **General Settings**:
   - `Signups Allowed`: false (already set)
   - `Invitations Allowed`: true
5. To invite users: Admin panel → **Users → Invite**

### 5. Vaultwarden — Browser Extension

1. Install Bitwarden browser extension
2. Settings → Self-hosted → Server URL: `https://vault.<DOMAIN>`
3. Login with your account

### 6. Outline — Authentik OIDC Setup

Outline **requires** OIDC for authentication. Set up Authentik:

1. In Authentik, create OAuth2/OpenID Provider for Outline
   - Redirect URI: `https://docs.<DOMAIN>/auth/oidc.callback`
   - Post-logout redirect: `https://docs.<DOMAIN>`
2. Set `OUTLINE_OAUTH_CLIENT_ID` and `OUTLINE_OAUTH_CLIENT_SECRET` in `.env`
3. Restart: `docker compose restart outline`

### 7. BookStack — Authentik OIDC (Optional)

1. Set `BOOKSTACK_AUTH_METHOD=oidc` in `.env`
2. In Authentik, create OAuth2/OpenID Provider for BookStack
   - Redirect URI: `https://wiki.<DOMAIN>/oidc/callback`
3. Set `BOOKSTACK_OIDC_CLIENT_ID` and `BOOKSTACK_OIDC_CLIENT_SECRET` in `.env`
4. Restart: `docker compose restart bookstack`

### 8. Stirling PDF

1. Open `https://pdf.<DOMAIN>`
2. All tools are available immediately — no login required
3. To enable security (login): set `DOCKER_ENABLE_SECURITY=true` and add user accounts in `/configs/settings.yml`

## Startup Order

```
[gitea] (healthy) ──► [gitea-runner]
[vaultwarden] — independent
[outline] — independent (requires DB + Redis)
[bookstack] — independent (requires MariaDB)
[stirling-pdf] — independent
[excalidraw] — independent
```

## Database Connection Strings

For reference when connecting other services:

| Service | Database | Connection String |
|---------|----------|-------------------|
| Gitea | PostgreSQL | `postgres://gitea:<pwd>@homelab-postgres:5432/gitea` |
| Vaultwarden | PostgreSQL | `postgresql://vaultwarden:<pwd>@homelab-postgres:5432/vaultwarden` |
| Outline | PostgreSQL | `postgres://outline:<pwd>@homelab-postgres:5432/outline` |
| Outline | Redis | `redis://:<pwd>@homelab-redis:6379?db=1` |
| BookStack | MariaDB | `mysql://bookstack:<pwd>@homelab-mariadb:3306/bookstack` |

## CN Network Adaptation

The `lscr.io` image (BookStack) may be slow in China. Run from repo root:
```bash
./scripts/setup-cn-mirrors.sh
```

## Troubleshooting

### Gitea: "Registration is disabled"
- First user becomes admin — if you can't register, check `INSTALL_LOCK=true`
- Emergency admin creation: `docker exec gitea gitea admin user create --admin --username root --password <pwd> --email root@example.com`

### Vaultwarden: Browser extension can't connect
- Must use **HTTPS** — Traefik handles this automatically
- Verify domain matches: `DOMAIN=https://vault.<DOMAIN>` in env

### Outline: "OIDC authentication failed"
- Check `OUTLINE_OAUTH_CLIENT_ID` and `OUTLINE_OAUTH_CLIENT_SECRET` match Authentik
- Verify `AUTHENTIK_DOMAIN` is set correctly
- Check redirect URI in Authentik: `https://docs.<DOMAIN>/auth/oidc.callback`

### BookStack: blank page / 500 error
- Verify `BOOKSTACK_APP_KEY` format: `base64:...`
- Check MariaDB is running: `docker compose -f ../databases/docker-compose.yml ps`
