# Productivity Stack

Self-hosted productivity suite: **Git hosting**, **password management**, **team wiki**, **PDF tools**, and **collaborative whiteboard**.

## Services

| Service | URL | Purpose |
|---------|-----|---------|
| [Gitea](https://gitea.io/) | `git.yourdomain.com` | Git code hosting with Actions CI/CD |
| [Vaultwarden](https://github.com/dani-garcia/vaultwarden) | `vault.yourdomain.com` | Bitwarden-compatible password manager |
| [Outline](https://www.getoutline.com/) | `docs.yourdomain.com` | Team knowledge base / wiki |
| [Stirling PDF](https://github.com/Stirling-Tools/Stirling-PDF) | `pdf.yourdomain.com` | PDF processing toolkit (merge, split, OCR, etc.) |
| [Excalidraw](https://excalidraw.com/) | `draw.yourdomain.com` | Collaborative whiteboard |

## Architecture

```
                    ┌─────────────┐
                    │   Traefik   │ (from base stack)
                    │   :443      │
                    └──────┬──────┘
           ┌───────────┬───┴───┬──────────┬──────────┐
           ▼           ▼       ▼          ▼          ▼
      ┌────────┐  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐
      │ Gitea  │  │ Vault- │ │Outline │ │Stirling│ │Excali- │
      │ :3000  │  │warden  │ │ :3000  │ │  PDF   │ │  draw  │
      │        │  │  :80   │ │        │ │ :8080  │ │  :80   │
      └───┬────┘  └────────┘ └───┬────┘ └────────┘ └────────┘
          │                      │
          ▼                      ▼
      ┌────────┐            ┌────────┐
      │ Gitea  │            │ MinIO  │ (from storage stack)
      │ Runner │            │  Init  │ → creates 'outline' bucket
      └────────┘            └────────┘
          │                      │
          ▼                      ▼
    ┌──────────────────────────────────┐
    │   PostgreSQL + Redis + MinIO     │ (from databases + storage stacks)
    └──────────────────────────────────┘
```

## Prerequisites

| Stack | Required For |
|-------|-------------|
| Base Infrastructure | Traefik reverse proxy, Let's Encrypt TLS |
| Databases | PostgreSQL (Gitea, Outline), Redis (Outline) |
| Storage | MinIO (Outline file storage) |
| SSO | Authentik OIDC (Gitea, Outline) |

### Database Setup

Create the required databases in the shared PostgreSQL instance:

```sql
-- Run in PostgreSQL (from databases stack)
CREATE USER gitea WITH PASSWORD 'your-gitea-db-password';
CREATE DATABASE gitea OWNER gitea;

CREATE USER outline WITH PASSWORD 'your-outline-db-password';
CREATE DATABASE outline OWNER outline;
```

> If using the databases stack's `initdb/01-init-databases.sh`, add `gitea` and `outline` to the init script.

## Quick Start

```bash
# 1. Copy environment template
cp .env.example .env

# 2. Generate secrets
sed -i "s/^GITEA_OAUTH2_JWT_SECRET=.*/GITEA_OAUTH2_JWT_SECRET=$(openssl rand -hex 32)/" .env
sed -i "s/^OUTLINE_SECRET_KEY=.*/OUTLINE_SECRET_KEY=$(openssl rand -hex 32)/" .env
sed -i "s/^OUTLINE_UTILS_SECRET=.*/OUTLINE_UTILS_SECRET=$(openssl rand -hex 32)/" .env
sed -i "s/^VAULTWARDEN_ADMIN_TOKEN=.*/VAULTWARDEN_ADMIN_TOKEN=$(openssl rand -base64 48)/" .env

# 3. Fill in remaining values (domain, DB passwords, OIDC credentials)
nano .env

# 4. Start the stack
docker compose up -d
```

## Service Configuration

### Gitea

**First-time setup (admin account):**

```bash
# Create admin user via CLI
docker exec -it gitea gitea admin user create \
  --username admin \
  --password 'your-admin-password' \
  --email admin@yourdomain.com \
  --admin
```

**Authentik OIDC setup:**

1. In Authentik, create an OAuth2 Provider for Gitea:
   - Client Type: Confidential
   - Redirect URI: `https://git.yourdomain.com/user/oauth2/authentik/callback`
   - Scopes: `openid profile email`
2. In Gitea → Site Administration → Authentication Sources → Add:
   - Type: OAuth2
   - Provider: OpenID Connect
   - Client ID / Secret from Authentik
   - Auto Discovery URL: `https://auth.yourdomain.com/application/o/gitea/.well-known/openid-configuration`

**Gitea Actions runner:**

```bash
# Get runner registration token from Gitea Admin → Actions → Runners
# Set GITEA_RUNNER_TOKEN in .env, then restart:
docker compose up -d gitea-runner
```

**SSH clone:**

```bash
# Clone via SSH (uses port 2222 by default)
git clone ssh://git@git.yourdomain.com:2222/user/repo.git
```

### Vaultwarden

**IMPORTANT:** Vaultwarden requires HTTPS for browser extensions to work. The Traefik labels handle this automatically.

**Admin panel:** Access `https://vault.yourdomain.com/admin` with the `VAULTWARDEN_ADMIN_TOKEN`.

**Inviting users:**
1. Go to Admin panel → Users → Invite User
2. Enter email address (requires SMTP to be configured)
3. User receives invite link via email

**Browser extension:**
1. Install [Bitwarden extension](https://bitwarden.com/download/)
2. Settings → Self-hosted → Server URL: `https://vault.yourdomain.com`
3. Create account or log in

### Outline

**Authentik OIDC setup:**

1. In Authentik, create an OAuth2 Provider for Outline:
   - Client Type: Confidential
   - Redirect URI: `https://docs.yourdomain.com/auth/oidc.callback`
   - Scopes: `openid profile email`
2. Set `OUTLINE_OAUTH_CLIENT_ID` and `OUTLINE_OAUTH_CLIENT_SECRET` in `.env`

**MinIO file storage:**
- The `outline-minio-init` container automatically creates the `outline` bucket
- Files uploaded in Outline are stored in MinIO (from storage stack)
- Bucket URL must match `AWS_S3_UPLOAD_BUCKET_URL` in environment

### Stirling PDF

No additional configuration needed. Access `pdf.yourdomain.com` for:

- Merge / Split / Rotate PDFs
- OCR (text recognition)
- Convert to/from images
- Add watermarks
- Compress PDFs
- And many more tools

### Excalidraw

No configuration needed. Access `draw.yourdomain.com` to start drawing.

> **Note:** This is the public instance without collaboration server. For real-time collaboration, consider adding the [excalidraw-room](https://github.com/excalidraw/excalidraw-room) service.

## Subdomains

| Subdomain | Service |
|-----------|---------|
| `git.yourdomain.com` | Gitea |
| `vault.yourdomain.com` | Vaultwarden |
| `docs.yourdomain.com` | Outline |
| `pdf.yourdomain.com` | Stirling PDF |
| `draw.yourdomain.com` | Excalidraw |

Create DNS A records (or wildcard `*.yourdomain.com`) pointing to your server.

## Volumes

| Volume | Service | Content |
|--------|---------|---------|
| `gitea-data` | Gitea | Git repositories, LFS, config |
| `gitea-runner-data` | Gitea Runner | Runner state |
| `vaultwarden-data` | Vaultwarden | Encrypted vault database, attachments |
| `outline-data` | Outline | Local cache (primary storage in MinIO) |
| `stirling-data` | Stirling PDF | Tessdata (OCR language packs) |

## Troubleshooting

### Vaultwarden browser extension can't connect

Ensure HTTPS is working: `curl -I https://vault.yourdomain.com/alive`
The extension **requires** valid HTTPS — self-signed certs won't work.

### Outline shows "database connection error"

1. Verify PostgreSQL is running: `docker exec homelab-postgres pg_isready`
2. Check database exists: `docker exec homelab-postgres psql -U postgres -c '\l' | grep outline`
3. Verify password in `.env` matches databases stack

### Gitea Actions runner not registering

1. Verify Gitea is healthy: `docker exec gitea gitea doctor check`
2. Check runner token: Admin → Actions → Runners
3. View logs: `docker logs gitea-runner`

### MinIO bucket init fails

Ensure the storage stack is running and MinIO is accessible on the `databases` network:
```bash
docker exec outline-minio-init mc alias set minio http://homelab-minio:9000 minioadmin minioadmin
```
