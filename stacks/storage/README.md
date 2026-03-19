# 💾 Storage Stack

> File sync, cloud storage, and S3-compatible object storage.

**Services:** Nextcloud · MinIO · FileBrowser  
**Bounty:** $150 USDT ([#3](https://github.com/illbnm/homelab-stack/issues/3))

---

## 🏗️ Architecture

```
User (Browser)
    │
    ├──► https://nextcloud.${DOMAIN}  →  Nextcloud (file sync, calendar, contacts)
    │                                     Uses PostgreSQL + Redis
    │
    ├──► https://minio.${DOMAIN}      →  MinIO Console (S3 web UI)
    │                                     https://s3.${DOMAIN} → MinIO API
    │
    └──► https://files.${DOMAIN}      →  FileBrowser (lightweight file manager)
                                           Mounts host directories via ${STORAGE_PATH}

Shared: PostgreSQL (homelab-postgres), Redis (homelab-redis)
```

**Nextcloud** is a full-featured self-hosted cloud (Google Drive alternative).  
**MinIO** is an S3-compatible object storage server — use it to store backups, media, or any files via S3 API.  
**FileBrowser** is a lightweight web-based file manager for browsing host directories.

---

## 🚀 Quick Start

### 1. Prerequisites

```bash
# Base infrastructure must be running first
docker network create proxy 2>/dev/null || true
docker network create databases 2>/dev/null || true

# Create storage directories on host
sudo mkdir -p /opt/homelab/storage
sudo chown -R 1000:1000 /opt/homelab/storage
```

### 2. Configure environment

```bash
cd stacks/storage
cp .env.example .env
nano .env
```

Required `.env` variables:

```env
DOMAIN=yourdomain.com
TZ=Asia/Shanghai

# Nextcloud
NEXTCLOUD_ADMIN_USER=admin
NEXTCLOUD_ADMIN_PASSWORD=<choose-strong-password>
STORAGE_PATH=/opt/homelab/storage

# Database (uses homelab-postgres + homelab-redis)
POSTGRES_USER=homelab
POSTGRES_PASSWORD=<generate-secure-password>

# MinIO
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=<choose-strong-password>

# FileBrowser
# No additional config needed — uses STORAGE_PATH
```

### 3. Create shared databases

```bash
# Connect to the shared PostgreSQL
docker exec -it homelab-postgres psql -U postgres -c "CREATE DATABASE nextcloud;"
docker exec -it homelab-postgres psql -U postgres -c "CREATE USER homelab WITH PASSWORD '<password>';"
docker exec -it homelab-postgres psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE nextcloud TO homelab;"
```

### 4. Start services

```bash
docker compose up -d
```

### 5. Initial setup

#### Nextcloud — first-run

1. Visit `https://nextcloud.${DOMAIN}`
2. Login with `NEXTCLOUD_ADMIN_USER` / `NEXTCLOUD_ADMIN_PASSWORD`
3. Go to Settings → Administration → Basic settings → configure Redis
4. Add apps: Files, Calendar, Contacts, Deck, Talk

#### MinIO — first-run

1. Visit `https://minio.${DOMAIN}`
2. Login with `MINIO_ROOT_USER` / `MINIO_ROOT_PASSWORD`
3. Create a bucket (e.g. `backups`, `media`)
4. Get Access Key + Secret Key from Identity → Service Accounts

#### FileBrowser — no setup needed

1. Visit `https://files.${DOMAIN}`
2. Default credentials: `admin` / `admin`
3. Change password immediately

---

## 🌐 Service URLs (after DNS + Traefik)

| Service | URL | Credentials |
|---------|-----|-------------|
| Nextcloud | `https://nextcloud.${DOMAIN}` | Set in `.env` |
| MinIO Console | `https://minio.${DOMAIN}` | Set in `.env` |
| MinIO S3 API | `https://s3.${DOMAIN}` | Use Access Key from MinIO |
| FileBrowser | `https://files.${DOMAIN}` | `admin` / `admin` (change this!) |

---

## 🔐 SSO / Authentik Integration

### Nextcloud — OIDC via oidc_login app

Run the Nextcloud OIDC setup script:

```bash
./scripts/nextcloud-oidc-setup.sh
```

This:
1. Downloads and enables the `oidc_login` app in Nextcloud
2. Configures Authentik as the OIDC provider
3. Outputs instructions for adding the OIDC application in Authentik

After setup, Nextcloud shows an **"OpenID"** button on the login page alongside local accounts.

### FileBrowser — Basic Auth only

FileBrowser does not support OIDC. For protection via Traefik ForwardAuth:

```yaml
labels:
  - "traefik.http.middlewares.files-auth.forwardauth.address=https://${AUTHENTIK_DOMAIN}/outpost.goauthentik.io/auth/traefik"
  - "traefik.http.middlewares.files-auth.forwardauth.trustForwardHeader=true"
  - "traefik.http.routers.files.middlewares=files-auth"
```

### MinIO — S3 API access

MinIO uses its own S3-compatible authentication. For SSO-gated S3 access, use **Traefik ForwardAuth** on the console URL only (S3 API at port 9000 cannot be easily protected with OIDC).

---

## 📁 File Structure

```
stacks/storage/
├── docker-compose.yml
├── .env
└── data/

Docker volumes:
  nextcloud-data     → /var/www/html (Nextcloud PHP files + user data)
  minio-data         → /data (S3 object storage)
  filebrowser-data   → /database (settings, credentials)

Host paths:
  ${STORAGE_PATH}    → mounted in FileBrowser at /srv

Shared networks:
  proxy      → Traefik access
  databases  → PostgreSQL + Redis
```

---

## 🔧 Common Tasks

### Connect Nextcloud to MinIO S3 storage

1. Nextcloud → Apps → Enable **External storage support**
2. Settings → Administration → External storage
3. Add: Amazon S3 → configure:
   - Bucket: `nextcloud`
   - Host: `https://s3.${DOMAIN}`
   - Access Key + Secret: from MinIO Service Account
   - Region: `us-east-1`

### Use MinIO as a backup target

```bash
# Install mc (MinIO Client)
docker exec -it minio mc alias set myminio https://s3.${DOMAIN} <access-key> <secret-key>

# Create a bucket for backups
docker exec -it minio mc mb myminio/backups

# Copy files
docker exec -it minio mc cp /data/backup.tar.gz myminio/backups/
```

### Sync files to Nextcloud via WebDAV

```bash
# Using curl
curl -u admin:password -X PROPFIND \
  https://nextcloud.${DOMAIN}/remote.php/dav/files/admin/ \
  -H "Depth: 1"

# Using rclone (recommended for large syncs)
# Install rclone on any machine, configure:
rclone config
# name: nextcloud
# type: webdav
# url: https://nextcloud.${DOMAIN}/remote.php/dav/files/admin/
# vendor: other

# Sync local folder to Nextcloud
rclone sync ./local-folder nextcloud:Files --progress
```

### Connect Nextcloud desktop client

1. Download Nextcloud desktop client: https://nextcloud.com/install/
2. Server URL: `https://nextcloud.${DOMAIN}`
3. Username + password (or SSO if configured)

### Upload large files via FileBrowser

1. `https://files.${DOMAIN}` → navigate to folder
2. Click **Upload** → select files
3. Supports drag-and-drop

---

## 🐛 Troubleshooting

### Nextcloud shows "Redis connection refused"

1. Verify Redis is running: `docker exec -it homelab-redis redis-cli ping`
2. Check Nextcloud config:
   ```bash
   docker exec -it nextcloud cat /var/www/html/config/config.php | grep redis
   ```
3. Add manually if needed:
   ```php
   'memcache.distributed' => '\OC\Memcache\Redis',
   'memcache.locking' => '\OC\Memcache\Redis',
   'redis' => [
     'host' => 'homelab-redis',
     'port' => 6379,
   ],
   ```

### Nextcloud "Trusted Domain" error

Add your domain to trusted domains:
```bash
docker exec -it nextcloud bash -c "echo \"nextcloud.${DOMAIN}\" >> /var/www/html/config/config.php"
```

Or edit `config/config.php` directly:
```php
'trusted_domains' => ['localhost', 'nextcloud.${DOMAIN}'],
```

### MinIO Access Denied

1. Verify credentials: `https://minio.${DOMAIN}` → Identity → Service Accounts
2. Check bucket policy:
   ```bash
   docker exec -it minio mc anonymous set download myminio/mybucket
   ```

### FileBrowser cannot browse directories

1. Check `STORAGE_PATH` in `.env` exists on host: `ls ${STORAGE_PATH}`
2. Check permissions: `ls -la ${STORAGE_PATH}`
3. FileBrowser must have read/write access to the mounted path

### Nextcloud slow uploads

1. Increase PHP memory limit:
   ```yaml
   environment:
     - PHP_MEMORY_LIMIT=512M
     - PHP_UPLOAD_LIMIT=10G
   ```
2. Enable Redis object cache (see Troubleshooting section above)
3. Check PostgreSQL performance:
   ```bash
   docker exec -it homelab-postgres psql -U postgres -c "SELECT pg_database_size('nextcloud');"
   ```

---

## 🔄 Update services

```bash
cd stacks/storage
docker compose pull
docker compose up -d
```

To update a specific service:
```bash
docker compose pull nextcloud && docker compose up -d nextcloud
```

---

## 🗑️ Tear down

```bash
cd stacks/storage
docker compose down        # keeps volumes
docker compose down -v    # removes volumes (loses ALL data!)
```

---

## 📋 Acceptance Criteria

- [x] Nextcloud starts with PostgreSQL + Redis, accessible via Traefik
- [x] Nextcloud WebDAV and CalDAV/CardDAV endpoints functional
- [x] Nextcloud OIDC via oidc_login app (run nextcloud-oidc-setup.sh)
- [x] MinIO S3 API and Console accessible via Traefik
- [x] FileBrowser browses host directories
- [x] All services with health checks
- [x] Image tags are pinned versions
- [x] README documents full setup, SSO integration, and common tasks
