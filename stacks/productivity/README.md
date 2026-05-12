# Productivity Stack — Gitea + Vaultwarden + Outline + BookStack + Stirling PDF + Excalidraw

Self-hosted productivity suite covering code hosting, password management, knowledge base, PDF tools, and whiteboarding.

## Services

| Service | Image | Purpose | URL |
|---------|-------|---------|-----|
| Gitea | gitea/gitea:1.22.3 | Git hosting | `git.{$DOMAIN}` |
| Vaultwarden | vaultwarden/server:1.32.0 | Password manager | `vault.{$DOMAIN}` |
| Outline | outlinewiki/outline:0.80.2 | Team knowledge base | `docs.{$DOMAIN}` |
| Stirling PDF | frooodle/s-pdf:0.30.2 | PDF tools | `pdf.{$DOMAIN}` |
| Excalidraw | excalidraw/excalidraw | Online whiteboard | `draw.{$DOMAIN}` |

## Dependencies

- [Databases Stack](../databases/) for PostgreSQL, Redis, MariaDB
- [SSO Stack](../sso/) for Authentik OIDC
- [Storage Stack](../storage/) for MinIO (Outline file storage)

## Setup

```bash
cp .env.example .env
# Fill in all values
docker compose up -d
```

## Service Configuration

### Gitea
- PostgreSQL shared via databases stack
- Authentik OIDC login
- Registration disabled (admin creates accounts)
- Gitea Actions runner ready

### Vaultwarden
- HTTPS required (browser extension mandate)
- Public registration disabled
- Admin panel at `/admin` with `ADMIN_TOKEN`
- PostgreSQL backend

### Outline
- PostgreSQL + Redis via databases stack
- Authentik OIDC login
- Local file storage (configurable to MinIO)
