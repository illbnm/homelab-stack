# Storage Stack — Self-Hosted Storage Services

Provides personal cloud storage, S3-compatible object storage, file management, and P2P synchronization.

## Architecture

```
Browser
  │
  ▼
Traefik (443)
  │
  ├── cloud.DOMAIN    → Nextcloud (Personal Cloud)
  ├── minio.DOMAIN    → MinIO Console
  ├── s3.DOMAIN       → MinIO API (S3)
  ├── files.DOMAIN    → FileBrowser
  └── sync.DOMAIN     → Syncthing

Internal:
  nextcloud-fpm  ─┐
  nextcloud-nginx ├── postgresql:5432 (shared databases network)
                  └── redis:6379 (shared databases network)
  minio           ─┘
  filebrowser
  syncthing
```

## Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| nextcloud-fpm | `nextcloud:29.0.7-fpm-alpine` | 9000 (internal) | PHP-FPM application server |
| nextcloud-nginx | `nginx:1.27-alpine` | 80 | Reverse proxy for FPM + static assets |
| minio | `minio/minio:RELEASE.2024-09-22T00-33-43Z` | 9000/9001 | S3-compatible object storage |
| filebrowser | `filebrowser/filebrowser:v2.31.1` | 80 | Lightweight file manager |
| syncthing | `lscr.io/linuxserver/syncthing:1.27.11` | 8384/22000 | P2P file synchronization |

## Prerequisites

- Base stack running (`stacks/base/` — Traefik + proxy network)
- Databases stack running (`stacks/databases/` — PostgreSQL + Redis)
- Domain with DNS pointing to your server
- Ports 80 + 443 + 22000 TCP/UDP open

## Quick Start

```bash
# 1. Copy and fill environment variables
cp .env.example .env
nano .env  # Fill ALL values marked REQUIRED

# 2. Start the stack
docker compose up -d

# 3. Wait for healthy
docker compose ps

# 4. Complete Nextcloud setup at https://cloud.DOMAIN
```

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `DOMAIN` | YES | Base domain, e.g. `yourdomain.com` |
| `NEXTCLOUD_ADMIN_USER` | YES | Nextcloud admin username |
| `NEXTCLOUD_ADMIN_PASSWORD` | YES | Nextcloud admin password |
| `NEXTCLOUD_DOMAIN` | YES | e.g. `cloud.yourdomain.com` |
| `MINIO_ROOT_USER` | YES | MinIO root user |
| `MINIO_ROOT_PASSWORD` | YES | MinIO root password |
| `POSTGRES_PASSWORD` | YES | Must match databases stack |
| `REDIS_PASSWORD` | YES | Must match databases stack |
| `STORAGE_ROOT` | NO | FileBrowser storage path (default `/data/storage`) |

## Integrating with Authentik

Nextcloud supports OIDC login via Authentik:

1. Run `../../scripts/setup-authentik.sh` to create an OIDC provider
2. The script writes credentials to `.env`
3. Nextcloud will automatically configure the OIDC app on startup
4. Users can log in at `https://cloud.DOMAIN/login` using their Authentik account

## Health Check

```bash
# All containers healthy
docker compose ps

# Nextcloud
curl -sf https://cloud.DOMAIN/status.php && echo OK

# MinIO Console
curl -sf https://minio.DOMAIN/minio/health/live && echo OK

# FileBrowser
curl -sf https://files.DOMAIN/ && echo OK

# Syncthing
curl -sf https://sync.DOMAIN/api/rest/noauth/health && echo OK
```

## CN Mirror

If `lscr.io` or `minio` images are inaccessible, update image paths:

```yaml
# MinIO
image: swr.cn-north-4.myhuaweicloud.com/ddn-k8s/docker.io/minio/minio:RELEASE.2024-09-22T00-33-43Z

# Syncthing
image: swr.cn-north-4.myhuaweicloud.com/ddn-k8s/lscr.io/linuxserver/syncthing:1.27.11
```

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Nextcloud "Database not available" | Verify `POSTGRES_PASSWORD` matches databases stack `.env` |
| MinIO console 404 | Ensure MinIO version supports `--console-address` flag |
| Syncthing discoverability issues | Open UDP 22000 on firewall for QUIC discovery |
| FileBrowser 403 | Ensure `${STORAGE_ROOT}` path is mounted and readable |
| Nextcloud slow | Redis connection issues; check `REDIS_PASSWORD` and connectivity |
