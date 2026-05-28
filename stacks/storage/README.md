# Storage Stack

Nextcloud + MinIO + FileBrowser for unified file management.

## Services

| Service | Image | Purpose | Access |
|---------|-------|---------|--------|
| Nextcloud | nextcloud:29.0.7-fpm-alpine | File sync & share | https://nextcloud.${DOMAIN} |
| Nextcloud Nginx | nginx:1.27-alpine | Reverse proxy for Nextcloud FPM | — |
| Nextcloud DB | mariadb:11.4 | Database | — |
| MinIO | minio/minio:RELEASE.2024-09-22 | S3-compatible storage | https://minio-console.${DOMAIN} |
| FileBrowser | filebrowser/filebrowser:latest | Web file manager | https://files.${DOMAIN} |

## Quick Start

```bash
# 1. Prerequisites
docker network create proxy

# 2. Configure
cp stacks/storage/.env.example stacks/storage/.env
# Edit .env with your domain and passwords

# 3. Deploy
docker compose -f stacks/storage/docker-compose.yml up -d
```

## Health Checks

All services include Docker health checks. Monitor with:

```bash
docker ps --filter "network=proxy" --format "table {{.Names}}\t{{.Status}}"
```
