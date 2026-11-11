# Storage Stack — Nextcloud (FPM + Nginx) + MinIO + FileBrowser + Syncthing

## Services

| Service | Image | Endpoint | Purpose |
|---|---|---|---|
| Nextcloud FPM | `nextcloud:29.0.7-fpm-alpine` | Internal `:9000` | Personal cloud backend (PostgreSQL + Redis DB 3 + Authentik OIDC) |
| Nextcloud Nginx | `nginx:1.27-alpine` | `https://${NEXTCLOUD_DOMAIN}` | High-throughput FPM frontend |
| MinIO | `minio/minio:RELEASE.2024-09-22T00-33-43Z` | `https://minio.${DOMAIN}` / `https://s3.${DOMAIN}` | S3-compatible object storage |
| FileBrowser | `filebrowser/filebrowser:v2.31.1` | `https://files.${DOMAIN}` | Web file manager over `${STORAGE_ROOT}` |
| Syncthing | `lscr.io/linuxserver/syncthing:1.27.11` | `https://sync.${DOMAIN}` | P2P multi-device synchronization |
