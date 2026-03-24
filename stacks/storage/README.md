# Storage Stack

Unified file storage, sync, and object storage for HomeLab.

## What's Included

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| Nextcloud (FPM+Nginx) | 29.0.7 | `nextcloud.<DOMAIN>` | File sync & collaboration |
| MinIO | 2024-09-22 | `minio.<DOMAIN>` (console), `s3.<DOMAIN>` (API) | S3-compatible object storage |
| FileBrowser | 2.31.1 | `files.<DOMAIN>` | Web file manager |
| Syncthing | 1.27.11 | `sync.<DOMAIN>` | Continuous file synchronization |

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
| `NEXTCLOUD_DB_USER` | ❌ | Default: `nextcloud` |
| `NEXTCLOUD_DB_PASSWORD` | ✅ | PostgreSQL password for nextcloud user |
| `REDIS_PASSWORD` | ✅ | Redis password (same as database stack) |
| `MINIO_ROOT_USER` | ❌ | Default: `minioadmin` |
| `MINIO_ROOT_PASSWORD` | ✅ | MinIO root password |
| `STORAGE_ROOT` | ❌ | Default: `/data/storage` |

## Nextcloud — FPM + Nginx

This stack uses Nextcloud in **FPM mode** with a separate Nginx container as the reverse proxy frontend. This is more performant than the all-in-one Apache image and allows independent scaling.

Custom config (`config/nextcloud/custom.config.php`) is mounted read-only and provides:
- `trusted_proxies` — allows Traefik to terminate TLS
- `overwriteprotocol` — forces HTTPS links
- `default_phone_region` — sets phone region
- Authentik OIDC integration (commented out, ready to enable)

### Enabling Authentik OIDC

1. Install the `user_oidc` app in Nextcloud:
   ```bash
   docker exec nextcloud-app php occ app:install user_oidc
   ```
2. Uncomment the OIDC block in `config/nextcloud/custom.config.php`
3. Configure the Authentik provider with the correct client ID/secret

## MinIO

- Console at `minio.<DOMAIN>`, S3 API at `s3.<DOMAIN>`
- On first start, `minio-init` creates default buckets: `nextcloud`, `backups`, `media`
- To configure Nextcloud external storage with MinIO:
  1. Install "External storage support" app in Nextcloud
  2. Add S3-compatible storage pointing to `s3.<DOMAIN>`

## Syncthing

After first start, access Syncthing at `https://sync.<DOMAIN>` and set a strong password. The GUI is open by default — restrict access in the Web UI settings or firewall rules.

P2P sync ports `22000/tcp`, `22000/udp`, and `21027/udp` are exposed to the host.

## Health Checks

```bash
docker compose ps
```
