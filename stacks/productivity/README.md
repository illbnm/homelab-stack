# Productivity Stack

Self-hosted productivity suite covering code hosting, password management, team knowledge base, PDF tools, and online whiteboard.

## What's Included

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| Gitea | 1.22.2 | `git.<DOMAIN>` | Git code hosting + Actions runner |
| Vaultwarden | 1.32.0 | `vault.<DOMAIN>` | Password manager (Bitwarden compatible) |
| Outline | 0.80.2 | `docs.<DOMAIN>` | Team knowledge base |
| Stirling PDF | 0.30.2 | `pdf.<DOMAIN>` | PDF processing tools |
| Excalidraw | latest-sha | `draw.<DOMAIN>` | Online whiteboard |
| BookStack | 24.10 | `wiki.<DOMAIN>` | Documentation wiki |

## Architecture

```
Internet
    │
    ▼
[Traefik :443]
    │  TLS termination (Let's Encrypt)
    │
    ├──► git.<DOMAIN>     → Gitea (OIDC via Authentik)
    ├──► vault.<DOMAIN>   → Vaultwarden (SMTP + admin token)
    ├──► docs.<DOMAIN>    → Outline (OIDC + MinIO storage)
    ├──► pdf.<DOMAIN>     → Stirling PDF
    ├──► draw.<DOMAIN>    → Excalidraw
    └──► wiki.<DOMAIN>    → BookStack

[proxy]     ← shared Docker network
[databases] ← PostgreSQL, MariaDB, Redis (from databases stack)
[storage]   ← MinIO object storage (from storage stack)
```

## Prerequisites

- Base stack deployed (Traefik running on `proxy` network)
- Databases stack deployed (`homelab-postgres`, `homelab-mariadb`, `homelab-redis`)
- SSO stack deployed (Authentik for OIDC)
- Storage stack deployed (MinIO for Outline file uploads)
- Required databases created: `gitea`, `vaultwarden`, `outline`, `bookstack`
- Required database users created: `gitea`, `vaultwarden`, `outline`, `bookstack`

## Quick Start

```bash
# From repo root
cd stacks/productivity
ln -sf ../../.env .env          # share root .env
cp .env.example .env            # or create fresh .env from example
docker compose up -d
```

## Configuration

### Environment Variables (`.env`)

| Variable | Required | Description |
|----------|----------|-------------|
| `DOMAIN` | ✅ | Base domain, e.g. `home.example.com` |
| `AUTHENTIK_DOMAIN` | ✅ | Authentik domain, e.g. `auth.home.example.com` |
| `GITEA_DB_PASSWORD` | ✅ | PostgreSQL password for Gitea user |
| `VAULTWARDEN_DB_PASSWORD` | ✅ | PostgreSQL password for Vaultwarden user |
| `OUTLINE_DB_PASSWORD` | ✅ | PostgreSQL password for Outline user |
| `BOOKSTACK_DB_PASSWORD` | ✅ | MariaDB password for BookStack user |
| `REDIS_PASSWORD` | ✅ | Redis password from databases stack |
| `VAULTWARDEN_ADMIN_TOKEN` | ✅ | Random hex string for admin API |
| `OUTLINE_SECRET_KEY` | ✅ | Random hex string (32 bytes) |
| `OUTLINE_UTILS_SECRET` | ✅ | Random hex string (32 bytes) |
| `GITEA_OAUTH2_JWT_SECRET` | ✅ | Random hex string for Gitea JWT |
| `GITEA_SECRET_KEY` | ✅ | Random hex string for Gitea sessions |
| `SMTP_HOST` | ✅ | SMTP server for Vaultwarden emails |
| `SMTP_USER` | ✅ | SMTP username |
| `SMTP_PASS` | ✅ | SMTP password |
| `MINIO_ACCESS_KEY` | ✅ | MinIO access key |
| `MINIO_SECRET_KEY` | ✅ | MinIO secret key |

### Gitea OIDC Setup

1. Create an OAuth2 application in Authentik with:
   - Authorization: `https://git.<DOMAIN>/user/oauth2/authorize`
   - Token: `https://git.<DOMAIN>/user/oauth2/token`
   - Refresh: `https://git.<DOMAIN>/user/oauth2_refresh`
   - Scopes: `openid`, `profile`, `email`
2. Add the client ID and secret to `.env` as `GITEA_OAUTH_CLIENT_ID` / `GITEA_OAUTH_CLIENT_SECRET`
3. Registration is disabled by default; create the first admin user via Gitea command:

```bash
docker exec gitea gitea admin user create \
  --username admin \
  --email admin@yourdomain.com \
  --password yourpassword \
  --admin
```

### Vaultwarden Admin

Generate an admin token in `.env`:
```bash
openssl rand -hex 32
```

Admin interface available at `https://vault.<DOMAIN>/admin` (protected by `ADMIN_TOKEN` header).

### Outline OIDC Setup

Create an application in Authentik:
- Authorization URI: `https://${AUTHENTIK_DOMAIN}/application/o/authorize/`
- Token URI: `https://${AUTHENTIK_DOMAIN}/application/o/token/`
- Info URI: `https://${AUTHENTIK_DOMAIN}/application/o/userinfo/`
- Logout URI: `https://${AUTHENTIK_DOMAIN}/application/o/outline/end-session/`
- Scopes: `openid`, `profile`, `email`
- Redirect URI: `https://docs.<DOMAIN>/auth/oidc/callback`

### Gitea Actions Runner

The runner is registered automatically at startup. The token is created in:
Gitea Admin → Actions → Runners → Generate Token

Add the token to `.env` as `GITEA_ACTIONS_RUNNER_TOKEN`.

### MinIO for Outline

Create a bucket named `outline` (or set `MINIO_BUCKET_OUTLINE`) in MinIO before starting Outline.

## Healthchecks

All services include Docker healthchecks. Verify status:
```bash
docker compose ps
```
