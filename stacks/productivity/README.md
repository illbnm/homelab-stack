# Productivity Stack

Self-hosted productivity suite: code hosting, password management, documentation, and team collaboration.

## What's Included

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| Gitea | 1.22 | `git.<DOMAIN>` | Git code hosting (GitHub alternative) |
| Vaultwarden | 1.32 | `vault.<DOMAIN>` | Password manager (Bitwarden-compatible) |
| Outline | 0.80 | `docs.<DOMAIN>` | Team knowledge base and wiki |
| BookStack | latest | `wiki.<DOMAIN>` | Documentation platform |
| Stirling PDF | 0.30 | `pdf.<DOMAIN>` | PDF manipulation toolkit |
| Excalidraw | latest | `draw.<DOMAIN>` | Collaborative whiteboard |

## Architecture

```
Internet
    │
    ├──► git.<DOMAIN>    → Gitea (Git repositories)
    ├──► vault.<DOMAIN>  → Vaultwarden (Password manager)
    ├──► docs.<DOMAIN>   → Outline (Knowledge base)
    ├──► wiki.<DOMAIN>   → BookStack (Documentation)
    ├──► pdf.<DOMAIN>    → Stirling PDF (PDF tools)
    └──► draw.<DOMAIN>  → Excalidraw (Whiteboard)

    All services use shared databases (PostgreSQL + Redis) from Databases Stack
```

## Prerequisites

- Base Infrastructure stack deployed first
- Databases Stack deployed (provides shared PostgreSQL + Redis)
- SSO Stack deployed (provides Authentik OIDC)

## Quick Start

```bash
cd stacks/productivity
cp .env.example .env
# Edit .env with your credentials
docker compose up -d
```

## Configuration

### Environment Variables (`.env`)

#### Gitea
| Variable | Required | Description |
|----------|----------|-------------|
| `GITEA_DB_PASSWORD` | ✅ | PostgreSQL password for Gitea |
| `GITEA_OAUTH2_JWT_SECRET` | ✅ | Random secret for OAuth2 JWT |
| `DOMAIN` | ✅ | Base domain |

#### Vaultwarden
| Variable | Required | Description |
|----------|----------|-------------|
| `VAULTWARDEN_ADMIN_TOKEN` | ✅ | Bcrypt-hashed admin token. Generate: |
| `VAULTWARDEN_DB_PASSWORD` | ✅ | PostgreSQL password |
| `VAULTWARDEN_DOMAIN` | ✅ | Must be reachable via HTTPS |

Generate admin token:
```bash
docker run --rm vaultwarden/server:1.32.0 ./vaultwarden_admin_token
```

#### Outline
| Variable | Required | Description |
|----------|----------|-------------|
| `OUTLINE_SECRET_KEY` | ✅ | Random 32-char secret |
| `OUTLINE_UTILS_SECRET` | ✅ | Random 32-char secret |
| `OUTLINE_DB_PASSWORD` | ✅ | PostgreSQL password |
| `REDIS_PASSWORD` | ✅ | Redis password |
| `OUTLINE_OAUTH_*` | ✅ | Authentik OIDC credentials |

Generate secrets:
```bash
openssl rand -hex 32
```

#### BookStack
| Variable | Required | Description |
|----------|----------|-------------|
| `BOOKSTACK_APP_KEY` | ✅ | Random 32-char secret |
| `BOOKSTACK_DB_PASSWORD` | ✅ | MariaDB password |
| `BOOKSTACK_AUTH_METHOD` | — | Set to `oidc` for SSO |
| `BOOKSTACK_OIDC_*` | If OIDC | Authentik OIDC credentials |

#### Stirling PDF
| Variable | Required | Description |
|----------|----------|-------------|
| `TZ` | — | Timezone (default: Asia/Shanghai) |

#### Excalidraw
Excalidraw works out of the box with default settings. No configuration required.

## Service URLs

| Service | URL | Notes |
|---------|-----|-------|
| Gitea | `https://git.<DOMAIN>` | First user becomes admin |
| Vaultwarden | `https://vault.<DOMAIN>` | Browser extension recommended |
| Outline | `https://docs.<DOMAIN>` | Auth via Authentik SSO |
| BookStack | `https://wiki.<DOMAIN>` | Auth via Authentik SSO |
| Stirling PDF | `https://pdf.<DOMAIN>` | Login: `admin` / `strojar` |
| Excalidraw | `https://draw.<DOMAIN>` | No login required |

## Stirling PDF Usage

Stirling PDF features:
- **Merge/Split** — Combine or divide PDF files
- **Rotate/Reorder** — Fix scanned document orientation
- **Compress** — Reduce file size
- **OCR** — Extract text from scanned PDFs
- **Watermark** — Add text/image watermarks
- **Convert** — PDF ↔ Images, Office documents
- **Security** — Encrypt, decrypt, redact

Default credentials: `admin` / `strojar` (change after first login)

## Troubleshooting

### Outline shows "Database does not exist"
Ensure the Databases Stack is running and PostgreSQL is initialized:
```bash
docker compose -f ../databases/docker-compose.yml up -d postgres
```

### Vaultwarden not accessible
- Vaultwarden requires HTTPS. Ensure Traefik is running.
- Check `DOMAIN` environment variable matches your actual domain.

### BookStack OIDC login not working
Ensure Authentik application is configured with correct redirect URIs:
- Callback: `https://wiki.${DOMAIN}/oidc/callback`
- Logout: `https://wiki.${DOMAIN}/oidc/signout`

### All services down after restart
Check logs:
```bash
docker compose logs -f
```
