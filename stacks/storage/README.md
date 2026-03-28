# Storage Stack

Complete self-hosted storage suite: personal cloud, S3 object storage, file browser, and P2P sync.

## What's Included

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| Nextcloud | 29.0.7 | `cloud.<DOMAIN>` | Personal cloud (FPM + Nginx) |
| MinIO | 2024-09 | `minio.<DOMAIN>` (UI) / `s3.<DOMAIN>` (API) | S3-compatible object storage |
| FileBrowser | 2.31.1 | `files.<DOMAIN>` | Lightweight file manager |
| Syncthing | 1.27.11 | `sync.<DOMAIN>` | P2P file synchronization |

## Architecture

```
Internet
    │
    ▼
[Traefik] ← via 'proxy' network
    │
    ├──► cloud.<DOMAIN>  → Nginx → Nextcloud FPM
    ├──► minio.<DOMAIN>  → MinIO Console (port 9001)
    ├──► s3.<DOMAIN>     → MinIO S3 API (port 9000)
    ├──► files.<DOMAIN>  → FileBrowser
    └──► sync.<DOMAIN>   → Syncthing Web UI

[databases] ← shared network (Nextcloud PostgreSQL + Redis)
```

## Prerequisites

1. Base Stack deployed (`stacks/base`)
2. `docker network create proxy` (if not exists)
3. Copy `.env.example` → `.env` and fill values

## Quick Start

```bash
cd stacks/storage
cp .env.example .env
# Edit .env with your values
docker compose up -d
```

## Services

### Nextcloud

Personal cloud with FPM + Nginx for high performance.

- **URL**: `https://cloud.${DOMAIN}`
- **First login**: use `NEXTCLOUD_ADMIN_USER` / `NEXTCLOUD_ADMIN_PASSWORD`
- **Data directory**: `${STORAGE_PATH}/nextcloud`
- **Features**:
  - PostgreSQL backend (standalone)
  - Redis caching
  - Large file upload support (10GB)
  - Auto-discovery for CalDAV/CardDAV clients

### MinIO

S3-compatible object storage.

- **Console**: `https://minio.${DOMAIN}` (user: `${MINIO_ROOT_USER}`, pass: `${MINIO_ROOT_PASSWORD}`)
- **S3 API**: `https://s3.${DOMAIN}`
- **Default bucket**: `data` (created automatically on first run)
- **Usage**: Set as external storage in Nextcloud, or use directly with any S3 client

### FileBrowser

Browse and manage files in `${STORAGE_PATH}`.

- **URL**: `https://files.${DOMAIN}`
- **Default credentials**: `admin` / `admin` (change on first login)
- **Browse path**: `/srv` → `${STORAGE_PATH}`

### Syncthing

P2P file synchronization across devices.

- **URL**: `https://sync.${DOMAIN}`
- **Credentials**: `syncthing` / `${SYNCTHING_GUI_PASSWORD}`
- **Sync folder**: `${STORAGE_PATH}/syncthing`
- **LAN auto-discovery**: Enabled by default

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `DOMAIN` | ✅ | Base domain |
| `TZ` | ✅ | Timezone |
| `NEXTCLOUD_ADMIN_USER` | ✅ | Nextcloud admin username |
| `NEXTCLOUD_ADMIN_PASSWORD` | ✅ | Nextcloud admin password |
| `NEXTCLOUD_DB_USER` | ✅ | PostgreSQL username for Nextcloud |
| `NEXTCLOUD_DB_PASSWORD` | ✅ | PostgreSQL password for Nextcloud |
| `NEXTCLOUD_REDIS_PASSWORD` | ✅ | Redis password for Nextcloud |
| `MINIO_ROOT_USER` | ✅ | MinIO root user |
| `MINIO_ROOT_PASSWORD` | ✅ | MinIO root password |
| `SYNCTHING_GUI_PASSWORD` | ✅ | Syncthing GUI password |
| `SYNCTHING_API_KEY` | ✅ | Syncthing API key (generate random) |
| `STORAGE_PATH` | ✅ | Host path for all data (default: `/data/storage`) |

## Generate Secrets

```bash
# MinIO / Nextcloud Redis password
openssl rand -base64 32

# Syncthing GUI password
htpasswd -nbBC 10 syncthing 'yourpassword' | tr -d ':\n'

# Syncthing API key
openssl rand -hex 32
```

## Acceptance Criteria

- [x] Nextcloud accessible at `cloud.${DOMAIN}` with HTTPS
- [x] Nextcloud admin login works
- [x] MinIO Console accessible at `minio.${DOMAIN}` with HTTPS
- [x] MinIO S3 API accessible at `s3.${DOMAIN}` with HTTPS
- [x] MinIO `mc` client can connect to S3 API
- [x] FileBrowser accessible at `files.${DOMAIN}` with HTTPS
- [x] FileBrowser can browse `${STORAGE_PATH}` directory
- [x] Syncthing accessible at `sync.${DOMAIN}` with HTTPS
- [x] Syncthing can sync files between devices
