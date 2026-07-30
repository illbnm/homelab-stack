# Productivity Stack

Self-hosted productivity suite: Git hosting, password manager, team wiki, PDF tools, and whiteboard.

## Services

| Service | Image | Port | URL |
|---------|-------|------|-----|
| Gitea | `gitea/gitea:1.22.2` | 3000 | `https://gitea.${DOMAIN}` |
| Gitea Runner | `gitea/act_runner:latest` | — | CI/CD for Gitea Actions |
| Vaultwarden | `vaultwarden/server:1.32.0` | 80 | `https://vault.${DOMAIN}` |
| Outline | `outlinewiki/outline:0.80.2` | 3000 | `https://docs.${DOMAIN}` |
| Stirling PDF | `frooodle/s-pdf:0.30.2` | 8080 | `https://pdf.${DOMAIN}` |
| Excalidraw | `excalidraw/excalidraw:latest` | 80 | `https://draw.${DOMAIN}` |

## Quick Start

```bash
# 1. Copy and edit environment variables
cp .env.example .env
nano .env  # Fill in all passwords and domain

# 2. Ensure prerequisite stacks are running
docker compose -f ../databases/docker-compose.yml up -d
docker compose -f ../base/docker-compose.yml up -d

# 3. Start the productivity stack
docker compose up -d

# 4. Initialize databases (auto-handled by outline-init container)
# Gitea and Outline databases are created automatically on first start
```

## Prerequisites

### Required Stacks (must be running first)
- **Base Stack** — Traefik reverse proxy with HTTPS
- **Databases Stack** — PostgreSQL 16 + Redis 7
- **SSO Stack** — Authentik for OIDC authentication
- **Storage Stack** — MinIO for Outline file storage

### DNS Records Required
| Hostname | Target |
|----------|--------|
| `gitea.${DOMAIN}` | Traefik |
| `vault.${DOMAIN}` | Traefik |
| `docs.${DOMAIN}` | Traefik |
| `pdf.${DOMAIN}` | Traefik |
| `draw.${DOMAIN}` | Traefik |

## Features

### Gitea
- Git code hosting with web UI
- Authentik OIDC single sign-on
- Registration disabled (admin-only account creation)
- Gitea Actions CI/CD with built-in runner
- Shared PostgreSQL database

### Vaultwarden
- Bitwarden-compatible password manager
- HTTPS required (browser extensions need TLS)
- Public registration disabled
- Admin panel protected with `ADMIN_TOKEN`
- SMTP email notifications for 2FA and invites
- WebSocket live sync support

### Outline
- Team knowledge base and wiki
- Authentik OIDC authentication
- MinIO S3 backend for file uploads
- Shared PostgreSQL + Redis
- Markdown + rich text editing

### Stirling PDF
- Full-featured PDF toolkit
- Merge, split, rotate, compress PDFs
- Add/remove passwords, watermarks
- Convert to/from PDF
- OCR support

### Excalidraw
- Online whiteboard and diagram tool
- Real-time collaboration
- Hand-drawn style diagrams
- Export to PNG, SVG, PDF

## Post-Install Configuration

See [authentik-setup.md](./authentik-setup.md) for detailed Authentik OIDC configuration:
1. Create OAuth2 providers in Authentik for Gitea and Outline
2. Configure redirect URIs
3. Set client IDs/secrets in `.env`
4. Create MinIO bucket for Outline

## Environment Variables

| Variable | Service | Description |
|----------|---------|-------------|
| `DOMAIN` | All | Your root domain |
| `GITEA_DB_PASSWORD` | Gitea | PostgreSQL password |
| `GITEA_RUNNER_TOKEN` | Gitea | Actions runner registration token |
| `VAULTWARDEN_ADMIN_TOKEN` | Vaultwarden | Admin panel access token |
| `OUTLINE_SECRET_KEY` | Outline | Session encryption key |
| `OUTLINE_UTILS_SECRET` | Outline | Utility encryption key |
| `OUTLINE_DB_PASSWORD` | Outline | PostgreSQL password |
| `OUTLINE_OIDC_CLIENT_ID` | Outline | Authentik OAuth2 client ID |
| `OUTLINE_OIDC_CLIENT_SECRET` | Outline | Authentik OAuth2 client secret |
| `MINIO_ROOT_USER` | Outline | MinIO access key |
| `MINIO_ROOT_PASSWORD` | Outline | MinIO secret key |
| `POSTGRES_PASSWORD` | Init | PostgreSQL superuser password |
| `SMTP_HOST` | Vaultwarden/Outline | SMTP server hostname |
| `SMTP_PORT` | Vaultwarden/Outline | SMTP server port |
| `SMTP_USER` | Vaultwarden/Outline | SMTP username |
| `SMTP_PASS` | Vaultwarden/Outline | SMTP password |

## Data Persistence

All service data is stored in named Docker volumes:
- `gitea_data` — Gitea repositories and config
- `gitea_runner_data` — Runner state and cache
- `vaultwarden_data` — Encrypted vault data
- `outline_data` — Outline document attachments
- `stirling_data` — Stirling PDF config and temp files
- `excalidraw_data` — Excalidraw saved drawings

## Health Check

```bash
# Check all services
curl -s https://gitea.${DOMAIN}/api/healthz
curl -s https://vault.${DOMAIN}/alive
curl -s https://docs.${DOMAIN}/api/health
curl -s https://pdf.${DOMAIN}/api/v1/info/status
```

## Backup

```bash
# Backup all volumes
docker run --rm -v gitea_data:/data -v $(pwd):/backup alpine tar czf /backup/gitea-backup.tar.gz -C /data .
docker run --rm -v vaultwarden_data:/data -v $(pwd):/backup alpine tar czf /backup/vaultwarden-backup.tar.gz -C /data .
docker run --rm -v outline_data:/data -v $(pwd):/backup alpine tar czf /backup/outline-backup.tar.gz -C /data .
```