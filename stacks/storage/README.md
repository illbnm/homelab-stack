# Storage Stack

Self-hosted storage suite: personal cloud, object storage, file manager, and P2P sync.

## Services

| Service | Image | URL |
|---------|-------|-----|
| Nextcloud (FPM) | `nextcloud:29.0.7-fpm-alpine` | `https://cloud.${DOMAIN}` |
| Nextcloud Nginx | `nginx:1.27-alpine` | Frontend for FPM |
| MinIO | `minio/minio:RELEASE.2024-09-22T00-33-43Z` | Console: `https://minio.${DOMAIN}` · API: `https://s3.${DOMAIN}` |
| FileBrowser | `filebrowser/filebrowser:v2.31.1` | `https://files.${DOMAIN}` |
| Syncthing | `lscr.io/linuxserver/syncthing:1.27.11` | `https://sync.${DOMAIN}` |

## Quick Start

```bash
cp .env.example .env
nano .env  # Fill in passwords and domain

# Start prerequisite stacks
docker compose -f ../databases/docker-compose.yml up -d
docker compose -f ../base/docker-compose.yml up -d

# Start storage stack
docker compose up -d
```

## DNS Records

| Hostname | Service |
|----------|---------|
| `cloud.${DOMAIN}` | Nextcloud |
| `minio.${DOMAIN}` | MinIO Console |
| `s3.${DOMAIN}` | MinIO S3 API |
| `files.${DOMAIN}` | FileBrowser |
| `sync.${DOMAIN}` | Syncthing |

## Features

### Nextcloud
- FPM mode with Nginx frontend for performance
- Shared PostgreSQL database + Redis cache
- Trusted proxies configured for Traefik
- External storage mounted at `/external-storage`
- Auto-install with admin credentials from env
- CalDAV/CardDAV well-known redirects

### MinIO
- S3-compatible object storage
- Console at `minio.${DOMAIN}`
- API at `s3.${DOMAIN}`
- Auto-creates buckets: `nextcloud`, `outline`, `backups`
- `mc` client compatible

### FileBrowser
- Browse `${STORAGE_ROOT}` directory
- Upload, download, preview files
- User management with JSON auth

### Syncthing
- P2P file synchronization
- Sync `${STORAGE_ROOT}` across devices
- Web UI at `sync.${DOMAIN}`
- UDP/TCP port 22027 for direct sync