# Storage Stack

Production-ready self-hosted storage and cloud synchronization stack featuring Nextcloud, MinIO S3 Object Storage, FileBrowser, and Syncthing.

## Services

| Service | Version | Default Port / URL | Description |
|---|---|---|---|
| **Nextcloud** | 29.0.7-fpm-alpine + Nginx 1.27 | `https://cloud.${DOMAIN}` | Enterprise file sync, share, calendar, and contacts |
| **MinIO Console** | RELEASE.2024-09-22T00-33-43Z | `https://minio.${DOMAIN}` (9001) | S3-compatible Web UI management console |
| **MinIO API** | RELEASE.2024-09-22T00-33-43Z | `https://s3.${DOMAIN}` (9000) | High-performance S3 compatible API endpoint |
| **FileBrowser** | v2.31.1 | `https://files.${DOMAIN}` | Web-based file manager for server directories |
| **Syncthing** | 1.27.11 | `https://sync.${DOMAIN}` (8384) | Continuous, peer-to-peer decentralized file sync |

## Architecture & Integration

- **Database**: Connected to shared PostgreSQL 16 (`postgres` on `homelab-internal`) for Nextcloud metadata.
- **Cache**: Connected to shared Redis 7.4 (`redis` on `homelab-internal`) for Nextcloud transactional file locking.
- **Reverse Proxy**: Traefik integration with automated HTTPS TLS termination and WebDAV / CalDAV / CardDAV path rewrites.
- **Storage Root**: Defaults to `${STORAGE_ROOT:-/data/storage}` for persistent multi-terabyte homelab data volumes.
- **Networking**:
  - `homelab-internal`: Internal network connecting Nextcloud to database and cache.
  - `proxy`: Public ingress routing via Traefik.
  - Native Syncthing sync ports exposed (`22000/tcp`, `22000/udp`, `21027/udp`).

## Quick Start

```bash
# 1. Ensure databases and internal network are initialized
docker network create homelab-internal || true
docker network create proxy || true

# 2. Deploy the stack
docker compose -f stacks/storage/docker-compose.yml up -d
```
