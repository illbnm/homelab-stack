# 💾 Storage Stack

Self-hosted storage suite covering personal cloud, S3-compatible object storage, file management, and P2P sync.

## Services

| Service | Image | URL | Purpose |
|---------|-------|-----|---------|
| Nextcloud | `nextcloud:29.0.7-fpm-alpine` | `cloud.example.com` | Personal cloud (Google Drive alternative) |
| Nextcloud Nginx | `nginx:1.27-alpine` | (frontend proxy) | Nextcloud FPM frontend |
| MinIO | `minio/minio:RELEASE.2024-09-22T00-33-43Z` | `minio.example.com` / `s3.example.com` | S3-compatible object storage |
| FileBrowser | `filebrowser/filebrowser:v2.31.1` | `files.example.com` | Lightweight web file manager |
| Syncthing | `lscr.io/linuxserver/syncthing:1.27.11` | `sync.example.com` | P2P file synchronization |

## Prerequisites

- Base stack running (`proxy` network must exist)
- PostgreSQL + Redis from the databases stack (optional — Nextcloud falls back to SQLite)
- Host directory: `STORAGE_ROOT` (default `/data/storage`)

## Quick Start

```bash
# 1. Create storage directory
sudo mkdir -p /data/storage
sudo chown -R $(id -u):$(id -g) /data/storage

# 2. Configure environment
cp stacks/storage/.env.example stacks/storage/.env
nano stacks/storage/.env

# 3. Start the stack
cd stacks/storage
docker compose up -d

# 4. Check health
docker compose ps
```

## Service Details

### Nextcloud

Deployed in **FPM mode** (PHP-FPM + Nginx) for better performance.

**First run**: Visit `https://cloud.example.com` — Nextcloud auto-installs using env vars.

**Database options:**
- **PostgreSQL (recommended)**: Set `NEXTCLOUD_DB_HOST` to your PostgreSQL container. Uses shared instance from the databases stack.
- **SQLite (fallback)**: Remove `POSTGRES_*` env vars — Nextcloud creates a local SQLite DB. Not recommended for production.

**Performance tuning** (`config/nextcloud.config.php`):
- APCu local memory cache
- Redis distributed cache + locking
- Preview generation enabled

**CalDAV/CardDAV**: The Traefik middleware handles `.well-known` redirects automatically.

**Large file uploads**: Nginx is configured for `client_max_body_size 10G`.

### MinIO Object Storage

Two routes:
- `https://minio.example.com` — Console UI (management)
- `https://s3.example.com` — S3 API endpoint

**Default buckets** (created by `minio-init`):
- `nextcloud` — for Nextcloud external storage integration
- `backups` — for system backups
- `uploads` — general purpose

**Connect with mc (MinIO client):**
```bash
mc alias set homelab https://s3.example.com minioadmin yourpassword
mc ls homelab
```

**Use as Nextcloud external storage:**
1. Enable "External storage support" app in Nextcloud
2. Settings → External storages → Add S3
3. Host: `s3.example.com`, Bucket: `nextcloud`, Key/Secret: MinIO credentials

### FileBrowser

Lightweight file manager — browse, upload, download, share files from `STORAGE_ROOT`.

Default credentials: `admin` / `admin` — **change immediately after first login**.

### Syncthing

P2P sync daemon. Open ports 22000 and 21027 on your firewall/router for remote device sync.

```bash
# Required open ports
22000/tcp   # Sync protocol
22000/udp   # Sync protocol (QUIC)
21027/udp   # Local discovery (optional, LAN only)
```

## Network Architecture

```
Internet → Traefik (proxy network)
  ├── cloud.domain → nextcloud-nginx:80 → nextcloud:9000 (FPM)
  ├── minio.domain → minio:9001 (console)
  ├── s3.domain → minio:9000 (API)
  ├── files.domain → filebrowser:80
  └── sync.domain → syncthing:8384

storage_internal (internal, no external access):
  nextcloud-nginx ←→ nextcloud (FPM FastCGI)
  nextcloud ←→ minio (object storage backend)
  nextcloud ←→ postgres (shared DB from databases stack)
  nextcloud ←→ redis (shared cache from databases stack)
```

## Authentik OIDC Integration

To enable Authentik SSO for Nextcloud:
1. In Authentik: create an OIDC provider for Nextcloud
2. In Nextcloud: install "Social login" or "OpenID Connect user backend" app
3. Configure OIDC endpoint in Nextcloud `config.php`

## Troubleshooting

**Nextcloud showing "Maintenance mode":**
```bash
docker exec nextcloud php occ maintenance:mode --off
```

**Nextcloud "Database connection error":**
- Ensure PostgreSQL is running and accessible from `storage_internal` network
- Check `NEXTCLOUD_DB_*` variables in `.env`

**MinIO Console not loading:**
```bash
docker compose logs minio
```
Ensure `MINIO_BROWSER_REDIRECT_URL` matches your actual domain.

**Syncthing can't connect to remote device:**
- Ensure ports 22000/tcp, 22000/udp are open in your firewall
- Check that both devices have each other's Device ID added
