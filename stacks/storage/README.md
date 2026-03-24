# Storage Stack

Unified file storage, sync, and object storage for HomeLab.

## What's Included

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| Nextcloud (FPM+Nginx) | 29.0.9 | `nextcloud.<DOMAIN>` | File sync & collaboration |
| MinIO | 2024-11-07 | `minio.<DOMAIN>` (console), `s3.<DOMAIN>` (API) | S3-compatible object storage |
| FileBrowser | 2.31.2 | `files.<DOMAIN>` | Web file manager |
| Syncthing | 1.28.1 | `sync.<DOMAIN>` | Continuous file synchronization |

## Architecture

```
Internet → Traefik
    ├── nextcloud.<DOMAIN>  → Nginx → Nextcloud FPM → PostgreSQL + Redis
    ├── minio.<DOMAIN>      → MinIO Console
    ├── s3.<DOMAIN>         → MinIO API
    ├── files.<DOMAIN>      → FileBrowser
    └── sync.<DOMAIN>       → Syncthing
```

## Prerequisites

- Base infrastructure stack running (Traefik + proxy network)
- Database layer running (PostgreSQL + Redis)
- `nextcloud` database and user created in PostgreSQL

## Quick Start

```bash
cd stacks/storage
cp .env.example .env
# Edit .env with your credentials
docker compose up -d
```

## Configuration

| Variable | Required | Description |
|----------|----------|-------------|
| `DOMAIN` | ✅ | Base domain |
| `TZ` | ✅ | Timezone |
| `NEXTCLOUD_ADMIN_USER` | ❌ | Default: `admin` |
| `NEXTCLOUD_ADMIN_PASSWORD` | ✅ | Admin password |
| `NEXTCLOUD_DB_PASSWORD` | ✅ | PostgreSQL password for nextcloud user |
| `REDIS_PASSWORD` | ✅ | Redis password (same as database stack) |
| `MINIO_ROOT_USER` | ❌ | Default: `minioadmin` |
| `MINIO_ROOT_PASSWORD` | ✅ | MinIO root password |
| `STORAGE_PATH` | ❌ | Default: `/data` |

## Syncthing

After first start, access Syncthing at `https://sync.<DOMAIN>` and set a strong password. The GUI is open by default — change `STGUIADDRESS` in compose if you want to restrict access.

## Health Checks

```bash
docker compose ps
```
