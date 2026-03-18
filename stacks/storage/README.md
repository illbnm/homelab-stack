# HomeLab Storage Stack

Self-hosted storage layer providing personal cloud storage, S3-compatible object storage, file browsing, and cross-device synchronization.

## Architecture

```
                    ┌──────────────────────────────────────────┐
                    │           proxy network (Traefik)        │
                    └──┬──────┬───────┬───────┬───────┬────────┘
                       │      │       │       │       │
                  cloud.*  minio.*  s3.*  files.*  sync.*
                       │      │       │       │       │
                ┌──────┴──┐   │       │       │       │
                │ NC Nginx │   │       │       │       │
                └──────┬──┘   │       │       │       │
    storage-internal   │      │       │       │       │
    ┌──────────────────┤      │       │       │       │
    │            ┌─────┴────┐ │       │  ┌────┴────┐  │
    │            │ Nextcloud│ │       │  │FileBrwsr│  │
    │            │  (FPM)   │ │       │  └─────────┘  │
    │            └─────┬────┘ │       │           ┌───┴─────┐
    │   ┌──────────┐   │  ┌───┴───┐   │           │Syncthing│
    │   │ NC Cron  │   │  │ MinIO │   │           └─────────┘
    │   └──────────┘   │  └───┬───┘   │             P2P: 22000
    │                  │      │       │
    └──────────────────┤      │       │
                       │  ┌───┴────┐  │
    databases network  │  │MC Init │  │
    ┌──────────────────┤  └────────┘  │
    │  PostgreSQL      │              │
    │  Redis           │              │
    └──────────────────┘              │
                                      │
                              ${STORAGE_ROOT}
                              (shared host dir)
```

## Services

| Service | Image | Subdomain | Purpose |
|---------|-------|-----------|---------|
| Nextcloud | `nextcloud:29.0.7-fpm-alpine` | `cloud.*` | Personal cloud storage |
| Nextcloud Nginx | `nginx:1.27-alpine` | (internal) | FPM reverse proxy |
| Nextcloud Cron | `nextcloud:29.0.7-fpm-alpine` | (internal) | Background tasks |
| MinIO | `minio/minio:RELEASE.2024-09-22T00-33-43Z` | `minio.*` / `s3.*` | S3-compatible object storage |
| MinIO Init | `minio/mc:RELEASE.2024-09-16T17-43-14Z` | (init) | Creates default buckets |
| FileBrowser | `filebrowser/filebrowser:v2.31.1` | `files.*` | Lightweight file manager |
| Syncthing | `lscr.io/linuxserver/syncthing:1.27.11` | `sync.*` | P2P file synchronization |

## Quick Start

```bash
# 1. Ensure base stack (Traefik) and databases stack are running
docker compose -f ../base/docker-compose.yml ps
docker compose -f ../databases/docker-compose.yml ps

# 2. Create storage directories on host
sudo mkdir -p /data/storage/{nextcloud,syncthing}

# 3. Configure environment
cp .env.example .env
nano .env   # Set all passwords and DOMAIN

# 4. Start all services
docker compose up -d

# 5. Verify
docker compose ps
# All containers should show "healthy" (except minio-init which exits after setup)
```

## Service Details

### Nextcloud (FPM + Nginx)

Nextcloud runs in FPM mode with a dedicated Nginx container for better performance.

**First-run setup:** On first start, Nextcloud automatically creates the admin account using `NEXTCLOUD_ADMIN_USER` / `NEXTCLOUD_ADMIN_PASSWORD` and connects to PostgreSQL.

**Database:** Uses the `nextcloud` database and user created by the databases stack init script. Connection via `homelab-postgres:5432`.

**Redis caching:** Uses Redis DB 3 (allocated in databases stack) for file locking and session/transactional caching.

**Config overrides:** The following are set via environment variables:
- `OVERWRITEPROTOCOL=https` — ensures correct URL generation behind Traefik
- `TRUSTED_PROXIES` — allows Traefik's internal Docker networks
- `NC_default_phone_region` — default phone region for user profiles

**Authentik SSO:** To enable OIDC login via Authentik:
1. In Authentik, create an OAuth2/OpenID provider for Nextcloud
2. Install the "Social Login" app in Nextcloud
3. Add an OpenID Connect provider with your Authentik details
4. Users can then log in via "Login with Authentik"

### MinIO (S3 Object Storage)

MinIO provides S3-compatible object storage with two Traefik routes:
- `minio.${DOMAIN}` — Web console (port 9001)
- `s3.${DOMAIN}` — S3 API endpoint (port 9000)

**Default buckets** (created by minio-init on first start):
| Bucket | Policy | Purpose |
|--------|--------|---------|
| `nextcloud` | Private | Nextcloud external storage backend |
| `backups` | Private | Database and config backups |
| `media` | Public read | Publicly accessible media files |
| `documents` | Private | General document storage |

**Connecting with mc client:**
```bash
mc alias set homelab https://s3.${DOMAIN} ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD}
mc ls homelab/
```

**As Nextcloud external storage:**
1. Enable the "External storage support" app in Nextcloud
2. Add an Amazon S3 storage with:
   - Bucket: `nextcloud`
   - Hostname: `homelab-minio` (internal) or `s3.${DOMAIN}` (external)
   - Port: 9000 (internal) or 443 (external)
   - Region: `us-east-1`
   - Enable SSL: yes (external) / no (internal)
   - Enable path style: yes

### FileBrowser

Lightweight web file manager at `files.${DOMAIN}`. Browses `${STORAGE_ROOT}` on the host.

**Default login:** `admin` / `admin` (change immediately on first access)

### Syncthing

P2P file synchronization at `sync.${DOMAIN}`. Syncs the `${STORAGE_ROOT}/syncthing` directory.

**Host ports required** for P2P discovery and transfer:
- `22000/tcp` — Syncthing protocol (relay + direct)
- `22000/udp` — QUIC protocol
- `21027/udp` — Local discovery

**Adding a device:**
1. Open `sync.${DOMAIN}` and note the Device ID
2. On the remote device, add this Device ID
3. Share a folder between both devices

## Network Architecture

| Network | Type | Services | Purpose |
|---------|------|----------|---------|
| `proxy` | External | NC Nginx, MinIO, FileBrowser, Syncthing | Traefik HTTPS routing |
| `databases` | External | Nextcloud, NC Cron | PostgreSQL + Redis access |
| `storage-internal` | Internal | Nextcloud, NC Nginx, NC Cron | FPM communication (no egress) |

Nextcloud FPM is never directly exposed — it only communicates via the internal `storage-internal` network with its Nginx frontend.

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DOMAIN` | Yes | — | Base domain for Traefik routing |
| `TZ` | No | `Asia/Shanghai` | Timezone |
| `STORAGE_ROOT` | No | `/data/storage` | Host path for shared file storage |
| `NEXTCLOUD_ADMIN_USER` | Yes | — | Nextcloud admin username |
| `NEXTCLOUD_ADMIN_PASSWORD` | Yes | — | Nextcloud admin password |
| `NEXTCLOUD_DB_PASSWORD` | Yes | — | PostgreSQL password (match databases stack) |
| `REDIS_PASSWORD` | Yes | — | Redis password (match databases stack) |
| `NC_DEFAULT_PHONE_REGION` | No | `CN` | Default phone region (ISO 3166-1) |
| `MINIO_ROOT_USER` | Yes | — | MinIO root username |
| `MINIO_ROOT_PASSWORD` | Yes | — | MinIO root password |
| `PUID` | No | `1000` | Syncthing user ID |
| `PGID` | No | `1000` | Syncthing group ID |

## Health Checks

| Service | Check | Interval | Start Period |
|---------|-------|----------|-------------|
| Nextcloud FPM | `php -r 'echo "OK"'` | 30s | 120s |
| Nextcloud Nginx | `wget /status.php` | 30s | 30s |
| MinIO | `curl /minio/health/live` | 30s | 30s |
| FileBrowser | `wget /health` | 30s | 15s |
| Syncthing | `wget /rest/noauth/health` | 30s | 30s |

## DNS Records

Add these DNS records pointing to your server:

| Record | Type | Value |
|--------|------|-------|
| `cloud.${DOMAIN}` | A/CNAME | Server IP |
| `minio.${DOMAIN}` | A/CNAME | Server IP |
| `s3.${DOMAIN}` | A/CNAME | Server IP |
| `files.${DOMAIN}` | A/CNAME | Server IP |
| `sync.${DOMAIN}` | A/CNAME | Server IP |

## Troubleshooting

**Nextcloud stuck on "Installing...":**
The first startup takes 1-2 minutes. Check logs:
```bash
docker logs -f homelab-nextcloud
```

**Nextcloud shows "Access through untrusted domain":**
Verify `DOMAIN` in `.env` matches the actual domain you're accessing. The `NEXTCLOUD_TRUSTED_DOMAINS` env var is set to `cloud.${DOMAIN}`.

**MinIO init didn't create buckets:**
Check the init container logs:
```bash
docker logs homelab-minio-init
```
To re-run: `docker compose run --rm minio-init`

**Syncthing can't find other devices:**
Ensure ports 22000/tcp, 22000/udp, and 21027/udp are open in your firewall. These must be on the host (not behind Traefik) for P2P discovery.

**FileBrowser shows empty directory:**
Verify `STORAGE_ROOT` in `.env` points to an existing directory on the host:
```bash
ls -la ${STORAGE_ROOT:-/data/storage}
```
