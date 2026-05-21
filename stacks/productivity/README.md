# Productivity Stack

Self-hosted productivity suite for HomeLab Stack — Git hosting, password manager, knowledge base, and documentation wiki.

## What's Included

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| Gitea | 1.22.3 | `git.<DOMAIN>` | Self-hosted Git service |
| Vaultwarden | 1.32.0 | `vault.<DOMAIN>` | Bitwarden-compatible password manager |
| Outline | 0.80.2 | `docs.<DOMAIN>` | Team knowledge base & wiki |
| BookStack | 24.10 | `wiki.<DOMAIN>` | Documentation platform |

## Architecture

```
Users
  ├──► git.<DOMAIN>    ── Gitea (code repositories, CI/CD)
  ├──► vault.<DOMAIN>  ── Vaultwarden (password manager)
  ├──► docs.<DOMAIN>   ── Outline (knowledge base, SSO via Authentik OIDC)
  └──► wiki.<DOMAIN>   ── BookStack (documentation, SSO via Authentik OIDC)
       │
       ├──► homelab-postgres (gitea, vaultwarden, outline DBs)
       ├──► homelab-mariadb (bookstack DB)
       └──► homelab-redis (outline cache)
```

## Quick Start

```bash
# Ensure base + databases + sso stacks are running
cd stacks/base && docker compose up -d
cd ../databases && docker compose up -d

# Start productivity
cd ../productivity
ln -sf ../../.env .env
docker compose up -d
```

## Configuration

### Required Environment Variables

| Variable | Service | Description |
|----------|---------|-------------|
| `DOMAIN` | All | Base domain |
| `GITEA_DB_PASSWORD` | Gitea | PostgreSQL password |
| `GITEA_OAUTH2_JWT_SECRET` | Gitea | JWT secret (`openssl rand -hex 32`) |
| `VAULTWARDEN_ADMIN_TOKEN` | Vaultwarden | Admin panel token |
| `VAULTWARDEN_DB_PASSWORD` | Vaultwarden | PostgreSQL password |
| `OUTLINE_SECRET_KEY` | Outline | App secret (`openssl rand -hex 32`) |
| `OUTLINE_UTILS_SECRET` | Outline | Utils secret (`openssl rand -hex 32`) |
| `OUTLINE_DB_PASSWORD` | Outline | PostgreSQL password |
| `BOOKSTACK_APP_KEY` | BookStack | App key (`php artisan key:generate`) |
| `BOOKSTACK_DB_PASSWORD` | BookStack | MariaDB password |
| `REDIS_PASSWORD` | Outline | Redis password (shared) |

### Gitea Setup

1. Visit `https://git.<DOMAIN>`
2. First launch auto-creates admin account
3. Configure SSO: Site Administration → Authentication Sources → Add OAuth2 → Authentik
4. Disable self-registration: Configuration → Set `DISABLE_REGISTRATION=true`

### Vaultwarden Setup

1. Visit `https://vault.<DOMAIN>`
2. Create your account (first user becomes admin)
3. Admin panel: `https://vault.<DOMAIN>/admin` (token = `VAULTWARDEN_ADMIN_TOKEN`)
4. Install Bitwarden browser extension / mobile app
5. Set self-hosted server URL to `https://vault.<DOMAIN>`

### Outline Setup

Outline requires Authentik OIDC for authentication (no standalone login).

1. Create OIDC provider in Authentik for Outline
2. Set `OUTLINE_OAUTH_CLIENT_ID` and `OUTLINE_OAUTH_CLIENT_SECRET` in `.env`
3. Visit `https://docs.<DOMAIN>` — redirects to Authentik login
4. First user becomes admin

### BookStack Setup

1. Set `BOOKSTACK_AUTH_METHOD=oidc` in `.env` for SSO
2. Create OIDC provider in Authentik for BookStack
3. Default login (standard mode): `admin@admin.com` / `password`
4. Change password immediately after first login

## SSO Integration

All services support Authentik SSO:

- **Gitea**: OAuth2 via authentication sources
- **Vaultwarden**: Independent auth (intentionally — password manager should have separate credentials)
- **Outline**: OIDC required (no standalone auth)
- **BookStack**: OIDC or standard auth (configurable)

## CN Network Adaptation

BookStack image is on `lscr.io` (LinuxServer). For CN:

```bash
CN_MODE=true ./scripts/cn-pull.sh
```

All other images on Docker Hub.

## Health Check

```bash
docker compose ps --format "table {{.Name}}\t{{.Status}}"
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Gitea DB error | Ensure databases stack running; check `GITEA_DB_PASSWORD` |
| Vaultwarden signup disabled | Set `SIGNUPS_ALLOWED=true` temporarily, create account, then disable |
| Outline won't start | Requires all OIDC vars set; check Authentik is running |
| BookStack blank page | Check `BOOKSTACK_APP_KEY` is set; ensure MariaDB has bookstack DB |
| Slow first start | Gitea and Outline run DB migrations on first launch |
