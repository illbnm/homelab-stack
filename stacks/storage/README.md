# Storage Stack

Self-hosted cloud storage: personal cloud drive, object storage, file browser, and multi-device sync.

## What's Included

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| Nextcloud FPM | 29.0.7 | *(internal:9000)* | Cloud drive application server |
| Nextcloud Nginx | 1.27 | `cloud.<DOMAIN>` | Nextcloud web frontend |
| MinIO | 2024-09-22 | `minio.<DOMAIN>` / `s3.<DOMAIN>` | S3-compatible object storage |
| FileBrowser | v2.31.1 | `files.<DOMAIN>` | Lightweight file manager |
| Syncthing | 1.27.11 | `sync.<DOMAIN>` | P2P file synchronization |

## Architecture

```
Internet
    │
    ▼
[Traefik :443]
    │
    ├──► cloud.<DOMAIN> ──► [Nginx] ──► [Nextcloud FPM :9000]
    │                                ──► [PostgreSQL] (databases network)
    │                                ──► [Redis]       (databases network)
    │
    ├──► minio.<DOMAIN> ──► [MinIO Console :9001]
    ├──► s3.<DOMAIN>    ──► [MinIO API :9000]
    │
    ├──► files.<DOMAIN> ──► [FileBrowser :80]
    │
    └──► sync.<DOMAIN>  ──► [Syncthing :8384]
                             ports: 22000/tcp+udp, 21027/udp (for direct P2P)
```

## Prerequisites

- Base stack running (Traefik on `proxy` network)
- **Databases stack running** (PostgreSQL + Redis on `databases` network)
- Docker Compose v2.20+

## Quick Start

```bash
# Step 1: Ensure databases stack is running
cd stacks/databases
docker compose up -d

# Step 2: Setup storage stack
cd ../storage
cp .env.example .env
vim .env  # Set NEXTCLOUD_ADMIN_PASSWORD, NEXTCLOUD_DB_PASSWORD, REDIS_PASSWORD, MINIO_ROOT_PASSWORD

# Step 3: Create storage directory
sudo mkdir -p ${STORAGE_ROOT:-/data/storage}
sudo chown -R ${PUID}:${PGID} ${STORAGE_ROOT:-/data/storage}

# Step 4: Symlink shared .env (or use local)
# ln -sf ../../.env .env

# Step 5: Start services
docker compose up -d
```

## Configuration

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `TZ` | ✅ | `Asia/Shanghai` | Timezone |
| `DOMAIN` | ✅ | — | Base domain |
| `PUID` | ✅ | `1000` | User ID |
| `PGID` | ✅ | `1000` | Group ID |
| `NEXTCLOUD_ADMIN_USER` | ✅ | `admin` | Nextcloud admin username |
| `NEXTCLOUD_ADMIN_PASSWORD` | ✅ | — | Nextcloud admin password |
| `NEXTCLOUD_DB_PASSWORD` | ✅ | — | PostgreSQL password for Nextcloud (must match databases stack) |
| `REDIS_PASSWORD` | ✅ | — | Redis password (must match databases stack) |
| `MINIO_ROOT_USER` | ✅ | `minioadmin` | MinIO admin username |
| `MINIO_ROOT_PASSWORD` | ✅ | — | MinIO admin password (min 8 chars) |
| `STORAGE_ROOT` | — | `/data/storage` | Host path for FileBrowser/Syncthing data |
| `FB_NOAUTH` | — | `false` | Disable FileBrowser auth (not recommended) |

### Service URLs

| Service | URL |
|---------|-----|
| Nextcloud | `https://cloud.<DOMAIN>` |
| MinIO Console | `https://minio.<DOMAIN>` |
| MinIO API (S3) | `https://s3.<DOMAIN>` |
| FileBrowser | `https://files.<DOMAIN>` |
| Syncthing | `https://sync.<DOMAIN>` |

## Post-Deploy Setup

### 1. Nextcloud — First Login

1. Open `https://cloud.<DOMAIN>`
2. Login with `NEXTCLOUD_ADMIN_USER` / `NEXTCLOUD_ADMIN_PASSWORD`
3. Go to **Settings → Administration → Overview** — check for any warnings
4. Recommended: install apps via **Apps** menu:
   - `files_external` — Mount MinIO as external storage
   - `calendar` / `contacts` / `tasks` — PIM apps
   - `nextcloud_files_antivirus` — ClamAV integration (if available)

### 2. Nextcloud — Connect MinIO as External Storage

1. Enable **External storage support** app (usually pre-installed)
2. Go to **Administration → External storage**
3. Add storage:
   - Folder name: `S3`
   - External storage: `Amazon S3`
   - Bucket: `nextcloud` (auto-created by `minio-init`)
   - Hostname: `s3.<DOMAIN>` (or `minio` if internal)
   - Port: `443` (or `9000` if internal)
   - Region: `us-east-1`
   - Access key: `MINIO_ROOT_USER`
   - Secret key: `MINIO_ROOT_PASSWORD`
   - Enable SSL: ✅
   - Enable path-style: ✅

### 3. MinIO — Access Console

1. Open `https://minio.<DOMAIN>`
2. Login with `MINIO_ROOT_USER` / `MINIO_ROOT_PASSWORD`
3. Three default buckets are auto-created: `nextcloud`, `backups`, `media`
4. Use `mc` client from CLI:
   ```bash
   mc alias set homelab https://s3.<DOMAIN> <MINIO_ROOT_USER> <MINIO_ROOT_PASSWORD>
   mc ls homelab/
   mc cp localfile.txt homelab/backups/
   ```

### 4. Syncthing — Add Remote Devices

1. Open `https://sync.<DOMAIN>`
2. Click **Add Remote Device** → paste the other device's Device ID
3. Share folders with the remote device
4. Default sync folder: `/data` (maps to `${STORAGE_ROOT}` on host)

### 5. FileBrowser — First Login

1. Open `https://files.<DOMAIN>`
2. Default credentials: `admin` / `admin` (change immediately)
3. Go to **User Settings → Change Password**
4. Browse files in `${STORAGE_ROOT}`

## Nextcloud FPM + Nginx Architecture

This stack uses Nextcloud in **FPM mode** (not the default Apache image) for better performance and integration with Traefik:

```
Traefik → Nginx (:80) → Nextcloud FPM (:9000)
```

Benefits:
- Nginx handles static files efficiently
- FPM process pool is tunable for performance
- Separation allows Nginx-level caching/optimization
- `nginx-nextcloud.conf` is the Nginx config (mounted read-only)

## Database Configuration

Nextcloud uses the shared PostgreSQL and Redis from the **databases stack**. Ensure:

1. `databases` network exists: `docker network ls | grep databases`
2. `NEXTCLOUD_DB_PASSWORD` matches in both `stacks/databases/.env` and `stacks/storage/.env`
3. PostgreSQL user `nextcloud` and database `nextcloud` are created by the initdb script in databases stack

## Optional: Authentik OIDC for Nextcloud

To enable SSO login via Authentik:

1. In Authentik, create an OAuth2/OpenID Provider for Nextcloud
2. Install the **Nextcloud OIDC Login** app: `occ app:install oidc_login`
3. Add to Nextcloud's `config.php`:
   ```php
   'oidc_login_provider_issuer' => 'https://auth.<DOMAIN>/application/o/nextcloud/',
   'oidc_login_client_id' => '<client-id-from-authentik>',
   'oidc_login_client_secret' => '<client-secret-from-authentik>',
   'oidc_login_auto_redirect' => false,
   'oidc_login_logout_url' => 'https://auth.<DOMAIN>/application/o/nextcloud/end-session/',
   'oidc_login_default_group' => 'users',
   ```

## Startup Order

```
[nextcloud FPM] (healthy) ──► [nextcloud-nginx] ──► accessible via Traefik
[minio] (healthy) ──► [minio-init] (creates default buckets, then exits)
[filebrowser] — independent
[syncthing] — independent
```

## CN Network Adaptation

The `lscr.io` image (Syncthing) may be slow in China. Set up Docker mirror:

```bash
# From repo root
./scripts/setup-cn-mirrors.sh
```

## Troubleshooting

### Nextcloud shows "Database is not available"
- Verify databases stack is running: `docker compose -f ../databases/docker-compose.yml ps`
- Check `NEXTCLOUD_DB_PASSWORD` matches in both stacks
- Verify `databases` network: `docker network inspect databases`

### Nextcloud shows "Redis not available"
- Check `REDIS_PASSWORD` matches in both stacks
- Verify Redis container: `docker exec homelab-redis redis-cli -a <password> ping`

### MinIO Console redirects to wrong URL
- Ensure `MINIO_BROWSER_REDIRECT_URL=https://minio.<DOMAIN>` is set
- If using a different domain, update the variable accordingly

### FileBrowser can't see files
- Check `STORAGE_ROOT` is set and the directory exists on the host
- Verify mount: `docker exec filebrowser ls /srv`

### Syncthing can't connect to remote devices
- Open firewall ports: `22000/tcp`, `22000/udp`, `21027/udp`
- Check device IDs are correct
- For NAT traversal, ensure port forwarding for 22000

## Optional: Authentik Forward Auth

To protect FileBrowser or Syncthing with SSO:

```yaml
- "traefik.http.routers.filebrowser.middlewares=authentik@file,security-headers@file"
```

Note: Nextcloud has its own auth system, so Forward Auth is typically not used for it (use OIDC instead).
