# Productivity Stack

Self-hosted productivity suite covering code hosting, password management, team knowledge base, documentation, PDF tools, and collaborative whiteboarding.

## Services

| Service | Domain | Port | Image | Description |
|---------|--------|------|-------|-------------|
| Gitea | `git.${DOMAIN}` | 3000 | `gitea/gitea:1.22.3` | Git code hosting with OIDC (Authentik), Actions runner |
| Vaultwarden | `vault.${DOMAIN}` | 80 | `vaultwarden/server:1.32.0` | Password manager (Bitwarden-compatible) with admin token |
| Outline | `docs.${DOMAIN}` | 3000 | `outlinewiki/outline:0.80.2` | Team knowledge base with MinIO S3 storage + OIDC |
| BookStack | `wiki.${DOMAIN}` | 80 | `lscr.io/linuxserver/bookstack:24.10.20241031` | Wiki/documentation platform with OIDC |
| Stirling PDF | `pdf.${DOMAIN}` | 8080 | `frooodle/s-pdf:0.30.2` | Self-hosted PDF toolkit (40+ operations) |
| Excalidraw | `draw.${DOMAIN}` | 3000 | `excalidraw/excalidraw:latest` | Collaborative virtual whiteboard |

## Prerequisites

- Traefik configured with `proxy` network (external)
- PostgreSQL shared instance on `homelab-postgres:5432` (external, `databases` network)
- Redis shared instance on `homelab-redis:6379` (external, `databases` network)
- MariaDB shared instance on `homelab-mariadb:3306` (external, `databases` network)
- Authentik OIDC provider (for Gitea, Outline, BookStack)

## Environment Variables

### Required `.env` entries

```env
# Domain
DOMAIN=yourdomain.com

# General
TZ=Asia/Shanghai
PUID=1000
PGID=1000

# Authentik SSO
AUTHENTIK_DOMAIN=auth.yourdomain.com

# Database passwords
GITEA_DB_PASSWORD=<strong-password>
VAULTWARDEN_DB_PASSWORD=<strong-password>
OUTLINE_DB_PASSWORD=<strong-password>
BOOKSTACK_DB_PASSWORD=<strong-password>
REDIS_PASSWORD=<strong-password>

# Gitea
GITEA_OAUTH2_JWT_SECRET=<openssl rand -base64 32>

# Vaultwarden
VAULTWARDEN_ADMIN_TOKEN=<openssl rand -base64 48>

# Outline
OUTLINE_SECRET_KEY=<openssl rand -base64 32>
OUTLINE_UTILS_SECRET=<openssl rand -base64 32>

# BookStack
BOOKSTACK_APP_KEY=<generate-via-bookstack-container>
```

## Deployment

```bash
cd stacks/productivity
docker compose up -d
```

## Verification

- [ ] Gitea accessible at `https://git.${DOMAIN}`, OIDC login with Authentik works
- [ ] Vaultwarden accessible at `https://vault.${DOMAIN}`, browser extension connects
- [ ] Outline accessible at `https://docs.${DOMAIN}`, documents can be created
- [ ] BookStack accessible at `https://wiki.${DOMAIN}`, OIDC login works
- [ ] Stirling PDF accessible at `https://pdf.${DOMAIN}`, all PDF tools functional
- [ ] Excalidraw accessible at `https://draw.${DOMAIN}`, collaborative drawing works
- [ ] All services have valid HTTPS certificates via Traefik
