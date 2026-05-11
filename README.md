# Storage Stack — Nextcloud + MinIO + FileBrowser + Syncthing

**Bounty: $150 USDT**

A production-ready Docker Compose stack for self-hosted storage behind Traefik reverse proxy with automatic HTTPS.

## Architecture

```
Traefik (external)
  ├── cloud.example.com → Nextcloud (Nginx → FPM)
  ├── s3.cloud.example.com → MinIO API
  ├── minio.cloud.example.com → MinIO Console
  ├── files.cloud.example.com → FileBrowser
  └── sync.cloud.example.com → Syncthing
```

## Services

| Service | Image | Purpose |
|---------|-------|---------|
| Nextcloud | `nextcloud:29.0.7-fpm-alpine` | Cloud file sync |
| Nextcloud Nginx | `nginx:1.27-alpine` | Reverse proxy for FPM |
| PostgreSQL | `postgres:16-alpine` | Nextcloud database |
| Redis | `redis:7-alpine` | Nextcloud caching + locking |
| MinIO | `minio/minio:RELEASE.2024-09-22` | S3-compatible object storage |
| FileBrowser | `filebrowser/filebrowser:v2.31.1` | Web file manager |
| Syncthing | `lscr.io/linuxserver/syncthing:1.27.11` | P2P folder sync |

## Prerequisites

- Docker Engine 24+ with Compose v2
- Traefik reverse proxy running on the `traefik` Docker network
- DNS records pointing your domains to the server IP
- A storage directory on the host (e.g., `/data/storage`)

## Quick Start

```bash
# 1. Clone and configure
cp .env.example .env
# Edit .env with your domains and passwords

# 2. Start the stack
docker compose up -d

# 3. Post-install: configure Nextcloud
docker compose exec -u www-data nextcloud php occ config:system:set trusted_proxies 0 --value "10.0.0.0/8"
docker compose exec -u www-data nextcloud php occ config:system:set overwriteprotocol --value "https"
docker compose exec -u www-data nextcloud php occ config:system:set default_phone_region --value "US"

# 4. MinIO: create a bucket for Nextcloud
docker compose exec minio mc alias set local http://localhost:9000 ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD}
docker compose exec minio mc mb local/nextcloud
docker compose exec minio mc anonymous set download local/nextcloud

# 5. Authentik OIDC (optional): add a Social Login provider in Nextcloud admin
```

## Configuration

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `NEXTCLOUD_ADMIN_USER` | Yes | — | Nextcloud admin username |
| `NEXTCLOUD_ADMIN_PASSWORD` | Yes | — | Nextcloud admin password |
| `NEXTCLOUD_DOMAIN` | Yes | — | Nextcloud and subdomain base |
| `NEXTCLOUD_DB_PASSWORD` | Yes | — | PostgreSQL password |
| `MINIO_ROOT_USER` | Yes | — | MinIO admin username |
| `MINIO_ROOT_PASSWORD` | Yes | — | MinIO admin password |
| `STORAGE_ROOT` | No | `/data/storage` | Host path for file storage |
| `PUID` | No | `1000` | User ID for Syncthing |
| `PGID` | No | `1000` | Group ID for Syncthing |

## Subdomains

| Subdomain | Service |
|-----------|---------|
| `${DOMAIN}` | Nextcloud |
| `s3.${DOMAIN}` | MinIO S3 API |
| `minio.${DOMAIN}` | MinIO Console |
| `files.${DOMAIN}` | FileBrowser |
| `sync.${DOMAIN}` | Syncthing |

## Security Notes

- All passwords stored in `.env` — never commit this file
- Nextcloud admin setup runs automatically on first boot
- MinIO root credentials must be changed after first login
- FileBrowser default credentials: `admin` / `admin` — change on first login
- Syncthing UI requires initial admin setup
- All services behind Traefik HTTPS by default
- Nextcloud Nginx config includes security headers (HSTS, CSP, X-Frame-Options)
