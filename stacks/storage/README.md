# 📦 Storage Stack

Self-hosted storage services: personal cloud, object storage, file browser, and cross-device sync.

## Services

| Service | Image | Port | URL | Purpose |
|---------|-------|------|-----|---------|
| Nextcloud | `nextcloud:29.0.7-fpm-alpine` | 9000 (FPM) | `https://cloud.DOMAIN` | Personal cloud / file sync |
| Nextcloud Nginx | `nginx:1.27-alpine` | 80 | (internal) | HTTP frontend for FPM |
| Nextcloud Cron | `nextcloud:29.0.7-fpm-alpine` | — | — | Background jobs |
| MinIO | `minio/minio:RELEASE.2024-09-22T00-33-43Z` | 9000/9001 | `https://minio.DOMAIN` (Console) / `https://s3.DOMAIN` (API) | S3-compatible object storage |
| MinIO Init | `minio/mc:RELEASE.2024-09-16T17-43-14Z` | — | — | Creates default buckets |
| FileBrowser | `filebrowser/filebrowser:v2.31.1` | 80 | `https://files.DOMAIN` | Lightweight file management |
| Syncthing | `lscr.io/linuxserver/syncthing:1.27.11` | 8384/22000 | `https://sync.DOMAIN` | P2P file synchronization |

## Prerequisites

Before starting the storage stack:

1. **Base Infrastructure** stack running (Traefik reverse proxy)
2. **Database** stack running (PostgreSQL + Redis)
3. Docker networks created: `proxy`, `databases`
4. Nextcloud database initialized (handled by `databases/initdb/01-init-databases.sh`)

## Quick Start

```bash
cd stacks/storage

# 1. Configure environment
cp .env.example .env
nano .env  # Fill in passwords and domain

# 2. Create storage directories
sudo mkdir -p /data/storage/nextcloud-external
sudo mkdir -p /data/storage/syncthing

# 3. Start services
docker compose up -d

# 4. Wait for Nextcloud first boot (~2 min)
docker compose logs -f nextcloud

# 5. Verify all services are healthy
docker compose ps
```

## Architecture

```
                    ┌──────────────┐
                    │   Traefik    │
                    │  (External)  │
                    └──────┬───────┘
           ┌───────────────┼───────────────┬──────────────┐
           ▼               ▼               ▼              ▼
    ┌─────────────┐  ┌──────────┐  ┌────────────┐  ┌──────────┐
    │  NC Nginx   │  │  MinIO   │  │ FileBrowser │  │ Syncthing│
    │  :80        │  │  :9001   │  │  :80        │  │  :8384   │
    └──────┬──────┘  │  :9000   │  └─────────────┘  │  :22000  │
           ▼         └──────────┘                    └──────────┘
    ┌─────────────┐
    │ NC FPM :9000│──────── databases network ────── PostgreSQL
    └─────────────┘                                  Redis
```

### Nextcloud FPM Architecture

Unlike the simpler Apache variant, this stack uses **FPM mode** for better performance:

- **Nextcloud FPM** — Runs PHP-FPM process, handles PHP logic only
- **Nextcloud Nginx** — Serves static files, proxies PHP to FPM via FastCGI
- **Nextcloud Cron** — Runs `cron.php` every 5 minutes for background tasks

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DOMAIN` | `yourdomain.com` | Your domain |
| `TZ` | `Asia/Shanghai` | Timezone |
| `NEXTCLOUD_ADMIN_USER` | `admin` | Nextcloud admin username |
| `NEXTCLOUD_ADMIN_PASSWORD` | — | Nextcloud admin password |
| `NEXTCLOUD_DB_PASSWORD` | — | Must match databases stack |
| `REDIS_PASSWORD` | — | Must match databases stack |
| `MINIO_ROOT_USER` | `minioadmin` | MinIO admin username |
| `MINIO_ROOT_PASSWORD` | — | MinIO admin password |
| `STORAGE_ROOT` | `/data/storage` | Host path for file storage |
| `PUID` / `PGID` | `1000` | User/group ID for Syncthing |
| `DEFAULT_PHONE_REGION` | `CN` | ISO 3166-1 alpha-2 country code |

### MinIO Buckets (auto-created)

| Bucket | Purpose | Access |
|--------|---------|--------|
| `nextcloud` | Nextcloud external storage | Private |
| `backups` | Backup storage | Private |
| `shared` | Public file sharing | Public download |

### Nextcloud → MinIO External Storage

To use MinIO as Nextcloud external storage:

1. Enable the "External storage support" app in Nextcloud
2. Go to **Settings → External storage**
3. Add S3-compatible storage:
   - Bucket: `nextcloud`
   - Hostname: `minio` (internal Docker DNS)
   - Port: `9000`
   - Region: `us-east-1`
   - Access Key: `$MINIO_ROOT_USER`
   - Secret Key: `$MINIO_ROOT_PASSWORD`
   - Enable path-style access: ✅
   - Disable SSL: ✅ (internal network)

## Authentik SSO Integration

To enable single sign-on via Authentik (SSO stack):

### 1. Create OAuth2 Provider in Authentik

- **Name:** Nextcloud
- **Authorization flow:** default-provider-authorization-implicit-consent
- **Client type:** Confidential
- **Redirect URIs:** `https://cloud.DOMAIN/apps/sociallogin/custom_oidc/authentik`
- Note the Client ID and Client Secret

### 2. Install OIDC App in Nextcloud

```bash
docker exec -u www-data nextcloud php occ app:install sociallogin
```

### 3. Configure in Nextcloud Settings

Go to **Settings → Social login** and add:
- **Title:** Authentik
- **Authorize URL:** `https://sso.DOMAIN/application/o/authorize/`
- **Token URL:** `https://sso.DOMAIN/application/o/token/`
- **Profile URL:** `https://sso.DOMAIN/application/o/userinfo/`
- **Client ID:** (from step 1)
- **Client Secret:** (from step 1)
- **Scope:** `openid email profile`

## Ports Summary

| Port | Service | Protocol | Exposed Via |
|------|---------|----------|-------------|
| 22000 | Syncthing Sync | TCP/UDP | Direct (host) |
| 21027 | Syncthing Discovery | UDP | Direct (host) |

All other services are accessed through Traefik reverse proxy via HTTPS.

## Health Checks

All services include Docker health checks:

```bash
# Check all services
docker compose ps

# Expected output:
# nextcloud         running (healthy)
# nextcloud-nginx   running (healthy)
# nextcloud-cron    running
# minio             running (healthy)
# minio-init        exited (0)       # one-shot, exits after bucket creation
# filebrowser       running (healthy)
# syncthing         running (healthy)
```

## Volumes

| Volume | Contents | Backup Priority |
|--------|----------|-----------------|
| `nextcloud-html` | Nextcloud application files | Low |
| `nextcloud-data` | User files | **Critical** |
| `nextcloud-config` | Configuration | High |
| `minio-data` | Object storage data | **Critical** |
| `filebrowser-db` | FileBrowser settings/DB | Low |
| `syncthing-config` | Syncthing configuration + keys | High |

## Troubleshooting

### Nextcloud "Trusted domain" error

Add your domain to trusted domains:
```bash
docker exec -u www-data nextcloud php occ config:system:set trusted_domains 1 --value="cloud.DOMAIN"
```

### Nextcloud shows security warnings

Ensure HSTS and .well-known redirects are working. The nginx.conf and Traefik labels handle this automatically.

### MinIO Console not accessible

Verify Traefik labels and that the `proxy` network is correctly configured:
```bash
docker network inspect proxy | grep minio
```

### Syncthing can't connect to devices

Ensure ports 22000 (TCP/UDP) and 21027 (UDP) are open in your firewall:
```bash
sudo ufw allow 22000/tcp
sudo ufw allow 22000/udp
sudo ufw allow 21027/udp
```

## CN Mirror Alternatives

For users in China where certain registries are blocked:

| Original | CN Mirror |
|----------|-----------|
| `nextcloud:29.0.7-fpm-alpine` | `docker.io/library/nextcloud:29.0.7-fpm-alpine` |
| `nginx:1.27-alpine` | `docker.io/library/nginx:1.27-alpine` |
| `minio/minio:RELEASE.2024-09-22T00-33-43Z` | `docker.io/minio/minio:RELEASE.2024-09-22T00-33-43Z` |
| `minio/mc:RELEASE.2024-09-16T17-43-14Z` | `docker.io/minio/mc:RELEASE.2024-09-16T17-43-14Z` |
| `filebrowser/filebrowser:v2.31.1` | `docker.io/filebrowser/filebrowser:v2.31.1` |
| `lscr.io/linuxserver/syncthing:1.27.11` | `swr.cn-north-4.myhuaweicloud.com/ddn-k8s/lscr.io/linuxserver/syncthing:1.27.11` |

---

*Generated/reviewed with: claude-opus-4-6*
