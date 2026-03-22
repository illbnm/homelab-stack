# 🛠️ Productivity Stack

Self-hosted productivity suite: Git hosting, password management, team wiki, PDF tools, and collaborative whiteboard.

## Services

| Service | Image | URL | Purpose |
|---------|-------|-----|---------|
| Gitea | `gitea/gitea:1.22.2` | `git.example.com` | Git code hosting |
| Vaultwarden | `vaultwarden/server:1.32.0` | `vault.example.com` | Password manager (Bitwarden-compatible) |
| Outline | `outlinewiki/outline:0.80.2` | `docs.example.com` | Team knowledge base |
| Outline Redis | `redis:7.4-alpine` | internal | Outline session/cache store |
| Stirling PDF | `frooodle/s-pdf:0.30.2` | `pdf.example.com` | PDF processing toolkit |
| Excalidraw | `excalidraw/excalidraw:latest` | `draw.example.com` | Collaborative whiteboard |

## Prerequisites

- Base stack running (`proxy` network)
- PostgreSQL from databases stack (or set up separately)
- MinIO from storage stack (for Outline file storage)

## Quick Start

```bash
# 1. Generate secrets
echo "OUTLINE_SECRET_KEY=$(openssl rand -hex 32)"
echo "OUTLINE_UTILS_SECRET=$(openssl rand -hex 32)"
echo "VAULTWARDEN_ADMIN_TOKEN=$(openssl rand -base64 48)"

# 2. Configure environment
cp stacks/productivity/.env.example stacks/productivity/.env
nano stacks/productivity/.env  # fill in all values

# 3. Create databases (if using shared PostgreSQL)
docker exec postgres psql -U postgres -c "CREATE USER gitea WITH PASSWORD 'yourpassword';"
docker exec postgres psql -U postgres -c "CREATE DATABASE gitea OWNER gitea;"
docker exec postgres psql -U postgres -c "CREATE USER outline WITH PASSWORD 'yourpassword';"
docker exec postgres psql -U postgres -c "CREATE DATABASE outline OWNER outline;"

# 4. Create Outline MinIO bucket
docker exec minio-init mc mb local/outline 2>/dev/null || true

# 5. Start the stack
cd stacks/productivity
docker compose up -d

# 6. Check health
docker compose ps
```

## Service Details

### Gitea — Git Hosting

**First run**: Visit `https://git.example.com` → complete installation (or auto-completes from env vars if DB is ready).

**Registrations disabled** by default (`GITEA__service__DISABLE_REGISTRATION: "true"`). Create users via admin panel: Site Administration → User Accounts → Create User.

**SSH Git access**: Port 2222 is exposed for `git clone ssh://git@git.example.com:2222/user/repo.git`

**Authentik OIDC Integration**:
1. In Authentik: create OAuth2/OIDC provider for Gitea
2. In Gitea: Site Admin → Authentication Sources → Add OAuth2
   - Provider: OpenID Connect
   - Client ID/Secret from Authentik
   - OpenID Connect Auto Discovery URL: `https://auth.example.com/application/o/<slug>/.well-known/openid-configuration`

**Gitea Actions** (CI/CD):
```bash
# Register a runner
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  gitea/act_runner:nightly register \
  --no-interactive \
  --instance https://git.example.com \
  --token <runner-token>
```

### Vaultwarden — Password Manager

> ⚠️ **HTTPS is mandatory**. Browser extensions refuse to connect to HTTP endpoints.

**First time**: Visit `https://vault.example.com` → Create account (first account becomes admin if `SIGNUPS_ALLOWED=false` — use admin panel to invite users after).

**Admin panel**: `https://vault.example.com/admin` (requires `VAULTWARDEN_ADMIN_TOKEN`)

**Browser extensions**: Connect with server URL `https://vault.example.com`

**WebSocket notifications**: Configured via Traefik dual-router (port 80 for app + port 3012 for WebSocket). Live sync between devices works out of the box.

**Bitwarden-compatible clients**: iOS/Android Bitwarden app → Settings → Server URL → `https://vault.example.com`

### Outline — Team Knowledge Base

Outline requires **authentication via OIDC** (it doesn't have built-in user management). You have two options:

**Option 1: Authentik OIDC** (recommended, after SSO stack deployed):
Uncomment the `OIDC_*` environment variables in `.env` and `docker-compose.yml`.

**Option 2: Slack/Google OAuth** (quick start without SSO stack):
Set `SLACK_CLIENT_ID` + `SLACK_CLIENT_SECRET` or `GOOGLE_CLIENT_ID` + `GOOGLE_CLIENT_SECRET`.

**File storage**: Uses MinIO S3 backend — create the `outline` bucket in MinIO before starting:
```bash
docker exec minio-init mc mb local/outline
```

**Redis**: Dedicated `outline-redis` container to avoid key namespace conflicts with other services.

### Stirling PDF

All-in-one PDF toolkit — no login required by default.

Features: merge, split, compress, convert, OCR, watermark, sign, and 50+ other operations.

**OCR languages**: Additional Tesseract languages can be downloaded via the web UI (Settings → OCR Languages).

### Excalidraw

No authentication, collaborative by default (share link = shared whiteboard). For private use, protect via Traefik middleware:

```yaml
# Add to Excalidraw labels in docker-compose.yml:
traefik.http.routers.excalidraw.middlewares: "traefik-auth@file"
```

## Network Architecture

```
Internet → Traefik (proxy network)
  ├── git.domain → gitea:3000
  ├── vault.domain → vaultwarden:80
  ├── vault.domain/notifications/hub → vaultwarden:3012 (WebSocket)
  ├── docs.domain → outline:3000
  ├── pdf.domain → stirling-pdf:8080
  └── draw.domain → excalidraw:80

productivity_internal (internal):
  outline → outline-redis
  outline → postgres (via DB host)
  gitea → postgres (via DB host)
```

## Authentik OIDC Setup (SSO Stack Integration)

After deploying the SSO stack, enable OIDC for all services:

### Gitea OIDC
Site Admin → Authentication Sources → Add OAuth2:
- Auto Discovery: `https://auth.example.com/application/o/gitea/.well-known/openid-configuration`

### Outline OIDC
Uncomment in `docker-compose.yml`:
```yaml
OIDC_CLIENT_ID: ${OIDC_CLIENT_ID}
OIDC_CLIENT_SECRET: ${OIDC_CLIENT_SECRET}
OIDC_AUTH_URI: "https://auth.example.com/application/o/authorize/"
OIDC_TOKEN_URI: "https://auth.example.com/application/o/token/"
OIDC_USERINFO_URI: "https://auth.example.com/application/o/userinfo/"
```

## Troubleshooting

**Vaultwarden WebSocket not working** (browser extension shows "offline"):
- Check that port 3012 is accessible: `docker compose logs vaultwarden | grep -i websocket`
- Verify dual Traefik router configuration is applied

**Outline "Invalid OIDC configuration"**:
- Ensure `SECRET_KEY` and `UTILS_SECRET` are 32-byte hex strings
- Ensure `URL` matches exactly what's configured in the OIDC provider

**Gitea SSH clone fails**:
- Ensure port 2222 is open: `nc -zv git.example.com 2222`
- Use: `git clone ssh://git@git.example.com:2222/user/repo.git`

**Outline can't upload files**:
- Ensure MinIO `outline` bucket exists
- Verify `AWS_S3_UPLOAD_BUCKET_URL` points to your MinIO S3 endpoint
