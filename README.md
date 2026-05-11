# Productivity Stack — Gitea + Vaultwarden + Outline + BookStack

**Bounty: $170 USDT**

A Docker Compose stack for self-hosted productivity tools behind Traefik.

## Services

| Service | Image | Purpose |
|---------|-------|---------|
| Gitea | `gitea/gitea:1.22` | Self-hosted Git service with SSH |
| Vaultwarden | `vaultwarden/server:1.32` | Bitwarden-compatible password manager |
| Outline | `outlinewiki/outline:latest` | Knowledge base/wiki for teams |
| BookStack | `lscr.io/linuxserver/bookstack:24.10` | Documentation/wiki platform |
| PostgreSQL | `postgres:16-alpine` | Shared database (Gitea, Outline, BookStack) |
| Redis | `redis:7-alpine` | Cache backend (Outline) |

## Domains

| Subdomain | Service |
|-----------|---------|
| `git.${DOMAIN}` | Gitea |
| `vault.${DOMAIN}` | Vaultwarden |
| `wiki.${DOMAIN}` | Outline |
| `docs.${DOMAIN}` | BookStack |

## Quick Start

```bash
# 1. Clone and configure
cp .env.example .env
# Edit .env with your domains and passwords

# 2. Create databases
docker compose exec postgres psql -U homelab -c "CREATE DATABASE gitea;"
docker compose exec postgres psql -U homelab -c "CREATE DATABASE outline;"
docker compose exec postgres psql -U homelab -c "CREATE DATABASE bookstack;"

# 3. Start the stack
docker compose up -d

# 4. Configure Gitea (first visit)
# Visit https://git.example.com — the install page will auto-configure with env vars

# 5. Configure Vaultwarden
# Visit https://vault.example.com — create first account, then disable signups
# Admin panel at https://vault.example.com/admin with ADMIN_TOKEN

# 6. Configure Outline
# Visit https://wiki.example.com — uses OIDC (Authentik) or Slack for login

# 7. Configure BookStack
# Visit https://docs.example.com — create admin account on first visit
```

## Security

- All passwords and secrets in `.env` — never commit
- Vaultwarden starts with signups disabled by default
- Outline uses OIDC authentication (Authentik recommended)
- BookStack requires initial admin setup
- All services behind Traefik HTTPS
- PostgreSQL handles auth via password, not trust
