# Storage Stack — Self-hosted Cloud Storage

Complete storage solution: personal cloud (Nextcloud), object storage (MinIO), lightweight file browser, and P2P sync (Syncthing).

## Architecture

```
Traefik (443)
  ├── nextcloud.DOMAIN   → Nginx → Nextcloud FPM → PostgreSQL + Redis
  ├── minio.DOMAIN       → MinIO Console (port 9001)
  ├── s3.DOMAIN          → MinIO API (port 9000)
  ├── files.DOMAIN       → FileBrowser
  └── sync.DOMAIN        → Syncthing

Storage: ${STORAGE_ROOT} (/data/storage)
  ├── nextcloud-data/
  ├── minio-data/
  └── sync/
```

## Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| nextcloud | `nextcloud:29.0.7-fpm-alpine` | 9000 (internal) | Personal cloud (FPM) |
| nextcloud-nginx | `nginx:1.27-alpine` | 80 (internal) | FastCGI reverse proxy |
| minio | `minio/minio:RELEASE.2024-09-22T00-33-43Z` | 9000/9001 | S3-compatible object storage |
| filebrowser | `filebrowser/filebrowser:v2.31.1` | 80 (internal) | Lightweight file manager |
| syncthing | `lscr.io/linuxserver/syncthing:1.27.11` | 8384 (internal) | P2P file sync |

## Quick Start

```bash
# 1. Start databases first (required)
cd stacks/databases && docker compose up -d
../../scripts/init-databases.sh

# 2. Start storage stack
cd ../storage && docker compose up -d

# 3. Initialize MinIO buckets
../../scripts/init-minio.sh

# 4. Configure Nextcloud OIDC (after SSO stack is up)
../../scripts/nextcloud-oidc-setup.sh
```

## Nextcloud

### First-run setup

1. Visit `https://nextcloud.${DOMAIN}`
2. Create admin account or wait for auto-configuration
3. Install recommended apps via Admin → Apps

### OIDC Login (Authentik)

After running `scripts/nextcloud-oidc-setup.sh`:
- Enable `sociallogin` app
- Navigate to Settings → Administration → Social Login
- Verify Authentik provider is configured

### External Storage (MinIO)

1. Install "External storage support" app
2. Settings → External Storage → Add Storage → Amazon S3
3. Configure:
   - Bucket: `documents` (from `init-minio.sh`)
   - Hostname: `minio`
   - Port: `9000`
   - Region: `us-east-1`
   - Enable Path Style: `true`
   - Access Key: `${MINIO_ROOT_USER}`
   - Secret Key: `${MINIO_ROOT_PASSWORD}`

### CLI Commands

```bash
# Scan files
docker exec -u www-data nextcloud php occ files:scan --all

# Add missing indices
docker exec -u www-data nextcloud php occ db:add-missing-indices

# Maintenance mode
docker exec -u www-data nextcloud php occ maintenance:mode --on
```

## MinIO

### Access

- **Console:** `https://minio.${DOMAIN}`
- **API:** `https://s3.${DOMAIN}`

### CLI (mc client)

```bash
# Configure
mc alias set myminio https://s3.${DOMAIN} ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD}

# List buckets
mc ls myminio

# Upload
mc cp ./file.txt myminio/documents/

# Generate share link (valid 7 days)
mc share download --expire 168h myminio/documents/file.txt
```

### Default Buckets

Created by `scripts/init-minio.sh`:

| Bucket | Purpose | Access |
|--------|---------|--------|
| `backups` | Database & config backups | Private |
| `media` | Shared media files | Public download |
| `documents` | Personal documents | Private |

## FileBrowser

- **URL:** `https://files.${DOMAIN}`
- **Default login:** `admin` / `admin` (change immediately!)
- **Root path:** `${STORAGE_ROOT}`

## Syncthing

- **URL:** `https://sync.${DOMAIN}`
- First visit: set admin password
- Add remote devices via Device ID
- Sync folders between devices

### Mobile Sync

1. Install Syncthing app ([Android](https://play.google.com/store/apps/details?id=com.nutomic.syncthingandroid) / [iOS](https://apps.apple.com/app/syncthing-fork/id1600632045))
2. Add your server as remote device
3. Share folders between phone and server

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `NEXTCLOUD_ADMIN_USER` | Yes | Nextcloud admin username |
| `NEXTCLOUD_ADMIN_PASSWORD` | Yes | Nextcloud admin password |
| `NEXTCLOUD_DB_PASSWORD` | Yes | Nextcloud PostgreSQL password |
| `MINIO_ROOT_USER` | Yes | MinIO root username |
| `MINIO_ROOT_PASSWORD` | Yes | MinIO root password |
| `STORAGE_ROOT` | No | Host path for storage (default: /data/storage) |
| `REDIS_PASSWORD` | Yes | Shared Redis password (for Nextcloud cache) |

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Nextcloud 502 | Check `nextcloud-nginx` is running and can reach `nextcloud:9000` |
| OIDC login fails | Verify `redirect_uris` in Authentik matches `https://nextcloud.DOMAIN/apps/sociallogin/custom_oidc/Authentik` |
| MinIO can't upload | Check bucket policy: `mc anonymous set download myminio/bucket` |
| Syncthing "folder marker missing" | Mount the exact same path on both sides |
| FileBrowser permission denied | Ensure `PUID:PGID` matches host directory ownership |