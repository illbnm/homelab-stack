# 🗄️ Storage Stack (Nextcloud FPM, MinIO S3, FileBrowser, Syncthing)

> Enterprise self-hosted cloud drive, S3-compatible object storage, web explorer, and P2P sync.

## 📦 Services

| Service | Image | Subdomain | Description |
|---|---|---|---|
| **Nextcloud** | `nextcloud:29.0.7-fpm-alpine` + Nginx | `cloud.${DOMAIN}` | Personal productivity cloud drive |
| **MinIO** | `minio/minio:RELEASE.2024-09-22T00-33-43Z` | `minio.${DOMAIN}` (UI), `s3.${DOMAIN}` (API) | S3-compatible high performance object storage |
| **FileBrowser** | `filebrowser/filebrowser:v2.31.1` | `files.${DOMAIN}` | Lightweight web file manager |
| **Syncthing** | `lscr.io/linuxserver/syncthing:1.27.11` | `sync.${DOMAIN}` | Continuous cross-device P2P file synchronization |

## 🔑 Shared Infrastructure Integration
- **PostgreSQL:** Uses shared `nextcloud` database on `homelab-postgres:5432`.
- **Redis:** Uses shared `homelab-redis:6379` (DB 3) for transactional file locking and cache.
- **MinIO S3 Buckets:** Automatically initialized via `minio-init` service (`homelab-storage`, `nextcloud-backups`).
