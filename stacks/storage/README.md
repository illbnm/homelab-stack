# 💾 Storage Stack (Nextcloud + MinIO + FileBrowser + Syncthing)

This stack provides self-hosted personal cloud storage, S3-compatible object storage, lightweight file browser, and P2P sync.

---

## 📦 Services Included

- **Nextcloud (`29.0.7-fpm-alpine`)**: Personal cloud drive running FPM mode backed by Nextcloud Nginx (`1.27-alpine`).
- **MinIO (`RELEASE.2024-09-22T00-33-43Z`)**: S3-compatible object storage.
- **FileBrowser (`v2.31.1`)**: Fast web file manager.
- **Syncthing (`1.27.11`)**: Peer-to-peer file synchronization server.

---

## ⚙️ MinIO Bucket Initialization

Use the initialization script to set up default buckets:

```bash
# Create default bucket 'homelab-backups'
./scripts/init-minio.sh homelab-backups
```

---

## 🚀 Deployment Instructions

```bash
docker compose -f stacks/storage/docker-compose.yml up -d
```

---

## 📖 Service Routing Table

- **Nextcloud Drive:** `https://cloud.${DOMAIN}`
- **MinIO Console:** `https://minio.${DOMAIN}`
- **MinIO S3 API:** `https://s3.${DOMAIN}`
- **FileBrowser:** `https://files.${DOMAIN}`
- **Syncthing Web UI:** `https://sync.${DOMAIN}`
