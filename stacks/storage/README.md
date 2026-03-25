# Storage Stack

Self-hosted storage services: personal cloud, object storage, file browser, and P2P sync.

## Services

| Service | Image | Ports | Purpose |
|---------|-------|-------|---------|
| Nextcloud | `nextcloud:29.0.7-fpm-alpine` | 9000 (FPM) | Personal cloud |
| Nextcloud Nginx | `nginx:1.27-alpine` | 80 | Web frontend |
| MinIO | `minio/minio:RELEASE.2024-09-22T00-33-43Z` | 9000, 9001 | S3-compatible storage |
| FileBrowser | `filebrowser/filebrowser:v2.31.1` | 80 | File manager |
| Syncthing | `lscr.io/linuxserver/syncthing:1.27.11` | 8384, 22000 | P2P sync |

## Quick Start

### Prerequisites

- Base Stack (Traefik)
- Databases Stack (PostgreSQL + Redis)

### 1. Initialize Database

```bash
# Run from Databases Stack
./scripts/init-databases.sh
```

### 2. Configure Environment

```bash
cp .env.example .env
nano .env
```

### 3. Start Services

```bash
docker compose up -d
```

### 4. Access Services

| Service | URL |
|---------|-----|
| Nextcloud | https://cloud.yourdomain.com |
| MinIO Console | https://minio.yourdomain.com |
| MinIO API | https://s3.yourdomain.com |
| FileBrowser | https://files.yourdomain.com |
| Syncthing | https://syncthing.yourdomain.com |

## Configuration

### Nextcloud

#### First Setup

1. Access https://cloud.yourdomain.com
2. Database connection is auto-configured via environment
3. Admin credentials set via `NEXTCLOUD_ADMIN_USER/PASSWORD`

#### Trusted Proxies

Add to `config.php` (in volume):

```php
'trusted_proxies' => ['10.0.0.0/8', '172.16.0.0/12'],
'overwriteprotocol' => 'https',
'default_phone_region' => 'US',
```

#### Authentik OIDC (Optional)

1. Create OAuth provider in Authentik
2. Add to Nextcloud:

```bash
docker exec -u www-data nextcloud php occ oidc:create-provider \
  --client-id="nextcloud" \
  --client-secret="your-secret" \
  --discovery-endpoint="https://auth.yourdomain.com/application/o/nextcloud/.well-known/openid-configuration" \
  Authentik
```

### MinIO

#### Create Bucket

```bash
# Install mc client
curl -O https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc

# Configure
./mc alias set homelab https://s3.yourdomain.com minioadmin yourpassword

# Create bucket
./mc mb homelab/my-bucket

# Set policy
./mc anonymous set download homelab/my-bucket
```

#### Use as Nextcloud External Storage

1. Nextcloud → Settings → External Storage
2. Add S3 storage:
   - Host: `s3.yourdomain.com`
   - Bucket: `my-bucket`
   - Access Key: `MINIO_ROOT_USER`
   - Secret Key: `MINIO_ROOT_PASSWORD`

### FileBrowser

#### Default Login

- Username: `admin`
- Password: `admin`

#### Change Password

Access Settings → User Management after first login.

### Syncthing

#### Setup

1. Access https://syncthing.yourdomain.com
2. Set GUI username/password in Settings
3. Add folders to sync
4. Add remote devices (share Device ID)

#### Port Forwarding

For external connectivity:
- TCP: 22000
- UDP: 21027

## Architecture

```
                    ┌─────────────────────────────────────────────────────────┐
                    │                      Traefik                            │
                    └─────────────────────┬───────────────────────────────────┘
                                          │
         ┌────────────────────────────────┼────────────────────────────────┐
         │                                │                                │
         ▼                                ▼                                ▼
┌─────────────────┐              ┌─────────────────┐              ┌─────────────────┐
│   Nextcloud     │              │     MinIO       │              │  FileBrowser    │
│  (FPM + Nginx)  │              │   (S3 API)      │              │   (Web UI)      │
└────────┬────────┘              └─────────────────┘              └─────────────────┘
         │
         ▼
┌─────────────────┐
│  PostgreSQL     │
│     Redis       │
│  (from Databases│
│      Stack)     │
└─────────────────┘
```

## Health Checks

```bash
# Nextcloud
docker exec nextcloud php-fpm-healthcheck

# MinIO
curl -sf http://localhost:9000/minio/health/live

# FileBrowser
curl -sf http://localhost:80/health

# Syncthing
curl -sf http://localhost:8384/rest/noauth/health
```

## Troubleshooting

### Nextcloud 502 Error

```bash
# Check FPM
docker logs nextcloud

# Check Nginx
docker logs nextcloud-nginx

# Verify PHP-FPM health
docker exec nextcloud php-fpm-healthcheck
```

### MinIO Can't Connect

```bash
# Check credentials
docker exec minio env | grep MINIO

# Test API
curl -I https://s3.yourdomain.com
```

### FileBrowser No Auth

```bash
# Set in .env
FILEBROWSER_NOAUTH=true

# Or configure user in GUI
```

### Syncthing Can't Connect

```bash
# Check port forwarding
nc -zv your-server 22000

# Check firewall
sudo ufw allow 22000/tcp
sudo ufw allow 22000/udp
sudo ufw allow 21027/udp
```

## Resource Requirements

| Service | Min Memory | Recommended |
|---------|------------|-------------|
| Nextcloud + Nginx | 256 MB | 512 MB - 1 GB |
| MinIO | 256 MB | 512 MB - 1 GB |
| FileBrowser | 32 MB | 64 MB |
| Syncthing | 128 MB | 256 MB |
| **Total** | **672 MB** | **1.3 - 2 GB** |

## Backup

Backups are handled by the Backup Stack. Key volumes:

- `nextcloud-html`, `nextcloud-data`
- `minio-data`
- `filebrowser-db`
- `syncthing-config`

## Security Notes

1. **Change default passwords** (MinIO, FileBrowser, Syncthing)
2. **Use HTTPS** (automatic via Traefik)
3. **Restrict Syncthing access** with authentication
4. **Consider Authentik OIDC** for Nextcloud

## License

MIT
