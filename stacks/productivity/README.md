# Productivity Stack

Self-hosted productivity suite for code hosting, password management, knowledge base, PDF tools, and collaborative whiteboard.

## Services

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| Gitea | 1.22.2 | `git.<DOMAIN>` | Git code hosting with Actions runner |
| Vaultwarden | 1.32.0 | `vault.<DOMAIN>` | Password manager (Bitwarden-compatible) |
| Outline | 0.80.2 | `docs.<DOMAIN>` | Team knowledge base / wiki |
| BookStack | 24.10 | `wiki.<DOMAIN>` | Structured documentation platform |
| Stirling PDF | 0.30.2 | `pdf.<DOMAIN>` | PDF processing toolkit |
| Excalidraw | latest | `draw.<DOMAIN>` | Collaborative whiteboard |

## Prerequisites

Deploy **before** this stack:
1. **Base Infrastructure** — Traefik reverse proxy + TLS
2. **Database Layer** — PostgreSQL, Redis, MariaDB shared instances
3. **SSO** — Authentik (for OIDC login)

## Quick Start

```bash
cp .env.example .env
# Edit .env — fill all CHANGE_ME values
docker compose up -d
```

## Configuration

### Gitea
- Public registration is **disabled** — admin creates accounts via web UI
- Authentik OIDC: configure an application in Authentik admin, set `GITEA_OAUTH_CLIENT_ID/SECRET`
- Actions runner: enabled by default, self-hosted runners can connect
- SMTP: set `GITEA_SMTP_ENABLED=true` and SMTP vars

### Vaultwarden
- Public sign-ups disabled; admin invites users via admin panel (`/admin`)
- **HTTPS required** — browser extensions refuse HTTP connections
- Protect admin panel with `VAULTWARDEN_ADMIN_TOKEN`
- SMTP: configure for email invitations and 2FA codes

### Outline
- Authentik OIDC login required (no local accounts)
- File storage: `local` (default) or `s3` (MinIO) — set `OUTLINE_FILE_STORAGE=s3`
- Requires PostgreSQL + Redis

### BookStack
- Supports `standard` or `oidc` auth via `BOOKSTACK_AUTH_METHOD`
- Uses MariaDB (from databases stack)

### Stirling PDF
- No auth by default — add Authentik ForwardAuth or IP whitelist for production
- All PDF tools: merge, split, convert, OCR, compress, watermark, etc.

### Excalidraw
- Standalone whiteboard, no external dependencies
- Data is client-side only (not persisted server-side)

## Networks

- `proxy` — external, shared with Traefik
- `databases` — external, shared with PostgreSQL/Redis/MariaDB

## Volumes

| Volume | Service | Purpose |
|--------|---------|---------|
| `gitea-data` | Gitea | Repos, config, SSH keys |
| `vaultwarden-data` | Vaultwarden | Encrypted vault database |
| `outline-data` | Outline | Uploaded files (local storage) |
| `bookstack-data` | BookStack | Config + uploads |
| `stirling-data` | Stirling PDF | OCR tessdata |
| `stirling-config` | Stirling PDF | App config |

## Troubleshooting

```bash
# Check all services are healthy
docker compose ps

# View logs
docker compose logs -f gitea
docker compose logs -f vaultwarden
docker compose logs -f outline
docker compose logs -f bookstack

# Reset Gitea admin password
docker exec -it gitea gitea admin user change-password --username admin --password NEWPASS
```
