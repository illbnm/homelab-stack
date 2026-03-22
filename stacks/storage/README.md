# 📦 Storage Stack

> Complete self-hosted storage solution with Nextcloud, MinIO, FileBrowser, and Syncthing.

## 🎯 Bounty: [#3](../../issues/3) - $150 USDT

## 📋 Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| **Nextcloud** | `nextcloud:29.0.9-apache` | 80 | Personal cloud storage |
| **MinIO** | `minio/minio:RELEASE.2024-11-07` | 9000/9001 | S3-compatible object storage |
| **FileBrowser** | `filebrowser/filebrowser:v2.31.2` | 80 | Lightweight file manager |
| **Syncthing** | `lscr.io/linuxserver/syncthing:1.28.1` | 8384/22000 | P2P file synchronization |

## 🚀 Quick Start

```bash
# 1. Copy environment example
cp .env.example .env

# 2. Edit environment variables
nano .env

# 3. Start the stack
cd /home/zhaog/.openclaw/workspace/data/bounty-projects/homelab-stack
docker compose -f stacks/storage/docker-compose.yml up -d

# 4. Check status
docker compose -f stacks/storage/docker-compose.yml ps
```

## ⚙️ Configuration

### Environment Variables

```bash
# Domain
DOMAIN=example.com

# Nextcloud
NEXTCLOUD_ADMIN_USER=admin
NEXTCLOUD_ADMIN_PASSWORD=your-secure-password

# MinIO
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=your-secure-minio-password

# Storage Path
STORAGE_PATH=/data/storage
```

### Access URLs

After deployment, access services at:

- **Nextcloud**: `https://nextcloud.${DOMAIN}`
- **MinIO Console**: `https://minio.${DOMAIN}`
- **MinIO API**: `https://s3.${DOMAIN}`
- **FileBrowser**: `https://files.${DOMAIN}`
- **Syncthing**: `https://syncthing.${DOMAIN}`

## 📝 Service Details

### Nextcloud

- Uses Apache image for simplicity (FPM + Nginx available as alternative)
- Connects to shared PostgreSQL and Redis (from base infrastructure)
- Auto-configures HTTPS via Traefik
- Includes DAV redirect middleware for CalDAV/CardDAV

### MinIO

- Console accessible via `minio.${DOMAIN}`
- S3 API accessible via `s3.${DOMAIN}`
- Can be configured as external storage backend for Nextcloud

### FileBrowser

- Lightweight web-based file manager
- Access to `${STORAGE_PATH}` directory
- Simple authentication (configure via web UI on first login)

### Syncthing

- P2P file synchronization across devices
- Web UI on port 8384
- Sync ports: 22000 (TCP/UDP), 21027 (UDP discovery)
- Data stored in `${STORAGE_PATH}/syncthing`

## 🔧 Advanced Configuration

### Nextcloud + MinIO Integration

To use MinIO as Nextcloud's external storage:

1. Install "External storage support" app in Nextcloud
2. Configure S3 credentials:
   - Access Key: `MINIO_ROOT_USER`
   - Secret Key: `MINIO_ROOT_PASSWORD`
   - Host: `s3.${DOMAIN}`
   - Bucket: `nextcloud-storage`
   - Enable SSL: Yes
   - Enable Path style: Yes

### Syncthing Device Setup

1. Access Syncthing web UI at `https://syncthing.${DOMAIN}`
2. Add device ID from other devices
3. Share folders as needed
4. Configure sync intervals and versioning

## ✅ Verification Checklist

- [ ] Nextcloud accessible and installation completes
- [ ] MinIO Console accessible
- [ ] MinIO API connectable via `mc` client
- [ ] FileBrowser shows `${STORAGE_PATH}` contents
- [ ] Syncthing web UI accessible
- [ ] All services have valid HTTPS certificates
- [ ] Health checks passing

## 🐛 Troubleshooting

### Nextcloud stuck on installation

```bash
# Check logs
docker logs nextcloud

# Restart if needed
docker compose -f stacks/storage/docker-compose.yml restart nextcloud
```

### MinIO connection refused

```bash
# Ensure both routes are working
curl -I https://minio.${DOMAIN}
curl -I https://s3.${DOMAIN}
```

### Syncthing discovery issues

```bash
# Ensure ports are open
sudo ufw allow 22000/tcp
sudo ufw allow 22000/udp
sudo ufw allow 21027/udp
```

## 📚 Related Stacks

- [Databases](../databases/) - PostgreSQL, Redis (required dependencies)
- [Base](../base/) - Traefik, monitoring (required infrastructure)
- [SSO](../sso/) - Authentik (optional SSO integration)

---

*Bounty: $150 USDT | Status: In Progress*
