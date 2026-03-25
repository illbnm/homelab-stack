# Productivity Stack

Self-hosted productivity tools: code hosting, password manager, knowledge base, and PDF tools.

## Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| Gitea | `gitea/gitea:1.22.2` | 3000, 2222 | Git hosting |
| Vaultwarden | `vaultwarden/server:1.32.0` | 80 | Password manager |
| Outline | `outlinewiki/outline:0.80.2` | 3000 | Knowledge base |
| Stirling PDF | `frooodle/s-pdf:0.30.2` | 8080 | PDF tools |
| Excalidraw | `excalidraw/excalidraw:latest` | 80 | Whiteboard |

## Quick Start

### Prerequisites

- Base Stack (Traefik)
- Databases Stack (PostgreSQL + Redis)
- Storage Stack (MinIO) - for Outline

### 1. Initialize Database

```bash
# Run from Databases Stack
./scripts/init-databases.sh
```

### 2. Configure Environment

```bash
cp .env.example .env
nano .env
```

### 3. Create Outline bucket in MinIO

```bash
mc alias set homelab https://s3.yourdomain.com minioadmin yourpassword
mc mb homelab/outline
```

### 4. Start Services

```bash
docker compose up -d
```

### 5. Access Services

| Service | URL |
|---------|-----|
| Gitea | https://git.yourdomain.com |
| Vaultwarden | https://vault.yourdomain.com |
| Outline | https://outline.yourdomain.com |
| Stirling PDF | https://pdf.yourdomain.com |
| Excalidraw | https://draw.yourdomain.com |

## Configuration

### Gitea

#### First Setup

1. Access https://git.yourdomain.com
2. Database is pre-configured
3. Create admin account

#### Authentik OIDC

1. Create OAuth provider in Authentik
2. Add to Gitea:

```yaml
# In Gitea config
[openid]
ENABLE_OPENID_SIGNIN = true
ENABLE_OPENID_SIGNUP = false
WHITELISTED_URIS = auth.yourdomain.com
```

#### SSH Access

```bash
# Clone via SSH (port 2222)
git clone ssh://git@git.yourdomain.com:2222/user/repo.git

# Or add to ~/.ssh/config
Host git.yourdomain.com
  Port 2222
```

### Vaultwarden

#### First Setup

1. Access https://vault.yourdomain.com
2. Create admin account
3. Invite users via Admin Panel (requires `ADMIN_TOKEN`)

#### Browser Extension

1. Install Bitwarden extension
2. Set server URL: `https://vault.yourdomain.com`
3. Login with created account

#### Admin Panel

Access: `https://vault.yourdomain.com/admin`

Use `ADMIN_TOKEN` to authenticate.

### Outline

#### First Setup

1. Configure OIDC in Authentik
2. Set environment variables
3. Access https://outline.yourdomain.com
4. Login via Authentik

#### Authentik OIDC Setup

1. Authentik → Applications → Create
   - Name: Outline
   - Redirect URI: `https://outline.yourdomain.com/auth/oidc.callback`
2. Copy Client ID and Secret to `.env`

#### MinIO Storage

Outline uses MinIO for file storage:
- Bucket: `outline`
- Files are private by default

### Stirling PDF

No initial configuration required. Access and use directly.

Features:
- Merge/split PDFs
- Convert to/from images
- Compress PDFs
- Add watermarks
- OCR support

### Excalidraw

No configuration required. Access and use directly.

Features:
- Real-time collaboration (via room links)
- Export to PNG/SVG
- Hand-drawn style diagrams

## Architecture

```
                    ┌─────────────────────────────────────────────────────────┐
                    │                      Traefik                            │
                    └─────────────────────┬───────────────────────────────────┘
                                          │
    ┌──────────────┬──────────────┬───────┴───────┬──────────────┐
    │              │              │               │              │
    ▼              ▼              ▼               ▼              ▼
┌────────┐  ┌───────────┐  ┌─────────┐   ┌───────────┐  ┌──────────┐
│ Gitea  │  │Vaultwarden│  │ Outline │   │Stirling-PDF│  │Excalidraw│
│ (Git)  │  │ (Vault)   │  │ (Wiki)  │   │   (PDF)   │  │  (Draw)  │
└────┬───┘  └───────────┘  └────┬────┘   └───────────┘  └──────────┘
     │                         │
     │    ┌────────────────────┼────────────────────┐
     │    │                    │                    │
     ▼    ▼                    ▼                    ▼
┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐
│   PostgreSQL    │   │     Redis       │   │     MinIO       │
│  (Databases)    │   │  (Databases)    │   │   (Storage)     │
└─────────────────┘   └─────────────────┘   └─────────────────┘
```

## Health Checks

```bash
# Gitea
curl -sf http://localhost:3000/healthcheck

# Vaultwarden
curl -sf http://localhost:80/alive

# Outline
docker exec outline node build/server/healthcheck.js

# Stirling PDF
curl -sf http://localhost:8080/api/v1/info/status

# Excalidraw
curl -sf http://localhost:80
```

## Troubleshooting

### Gitea SSH Not Working

```bash
# Check SSH port
nc -zv your-server 2222

# Open firewall
sudo ufw allow 2222/tcp
```

### Vaultwarden HTTPS Required

Browser extension requires HTTPS. Ensure:
- Traefik is running
- Certificate is valid
- `DOMAIN` matches actual domain

### Outline OIDC Issues

```bash
# Check OIDC config
docker exec outline env | grep OIDC

# Check Authentik endpoints
curl -I https://auth.yourdomain.com/application/o/outline/.well-known/openid-configuration
```

### Stirling PDF Out of Memory

```bash
# Increase memory limit
# In docker-compose.yml:
deploy:
  resources:
    limits:
      memory: 2G
```

## Resource Requirements

| Service | Min Memory | Recommended |
|---------|------------|-------------|
| Gitea | 128 MB | 256-512 MB |
| Vaultwarden | 64 MB | 128-256 MB |
| Outline | 128 MB | 256-512 MB |
| Stirling PDF | 256 MB | 512 MB - 1 GB |
| Excalidraw | 64 MB | 128 MB |
| **Total** | **640 MB** | **1.3 - 2.5 GB** |

## Security Notes

1. **Disable public registration** (Gitea, Vaultwarden)
2. **Use strong ADMIN_TOKEN** for Vaultwarden
3. **Enable Authentik OIDC** for SSO
4. **Configure SMTP** for notifications

## License

MIT
