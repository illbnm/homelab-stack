# 📦 Storage Stack

Self-hosted storage services for the HomeLab: personal cloud, object storage, file management, and device sync.

## Services

| Service | Image | URL | Description |
|---------|-------|-----|-------------|
| **Nextcloud** | `nextcloud:29.0.7-fpm-alpine` | `nextcloud.${DOMAIN}` | Personal cloud (FPM + Nginx) |
| **MinIO** | `minio/minio:RELEASE.2024-09-22T00-33-43Z` | `minio.${DOMAIN}` / `s3.${DOMAIN}` | S3-compatible object storage |
| **FileBrowser** | `filebrowser/filebrowser:v2.31.1` | `files.${DOMAIN}` | Lightweight web file manager |
| **Syncthing** | `lscr.io/linuxserver/syncthing:1.27.11` | `sync.${DOMAIN}` | P2P file synchronization |

## Prerequisites

- **Databases Stack** — PostgreSQL + Redis must be running
- **Traefik** — Reverse proxy with HTTPS configured
- **SSO Stack** (optional) — Authentik for OIDC login to Nextcloud

## Quick Start

```bash
cd stacks/storage
cp .env.example .env
nano .env  # fill in passwords and domain
docker compose up -d
```

## Architecture

```
Internet
   │
   ▼
┌─────────────────────────────────────────────────────┐
│                   Traefik (HTTPS)                    │
│  nextcloud. │ minio. │ s3. │ files. │ sync.         │
└──┬──────────┬───────┬─────┬────────┬────────────────┘
   │          │       │     │        │
   ▼          ▼       ▼     ▼        ▼
Nginx→FPM  MinIO    MinIO  FB    Syncthing
   │       Console   API    │        │
   ▼                        ▼        ▼
┌─────────────────────────────────────────┐
│          Shared Storage Root            │
│              (/data)                    │
└─────────────────────────────────────────┘
   │
   ▼
┌──────────────────┐
│  PostgreSQL      │  (Databases Stack)
│  Redis           │
└──────────────────┘
```

## Configuration Details

### Nextcloud (FPM + Nginx)

- Runs in **FPM mode** with an Nginx frontend (not Apache)
- Uses shared PostgreSQL from the Databases Stack
- Redis used for file locking and caching
- Configures `trusted_proxies`, `overwriteprotocol`, `default_phone_region` automatically
- CalDAV/CardDAV redirect handled by Traefik middleware

#### Authentik OIDC Login (optional)

1. Create an OIDC provider in Authentik for Nextcloud
2. Set these in `.env`:
   ```bash
   AUTHENTIK_URL=https://authentik.yourdomain.com
   NEXTCLOUD_OIDC_CLIENT_ID=your_client_id
   NEXTCLOUD_OIDC_CLIENT_SECRET=your_client_secret
   ```
3. The `nextcloud-config` container will auto-install the `user_oidc` app and register the provider

### MinIO

- **Console**: `https://minio.${DOMAIN}` — Web UI for bucket management
- **API (S3)**: `https://s3.${DOMAIN}` — S3-compatible API endpoint
- Default buckets (`nextcloud`, `backups`, `media`) are auto-created on first run
- Can be configured as Nextcloud's external storage backend via the S3 app

#### Using MinIO as Nextcloud External Storage

1. Install the "External storage support" app in Nextcloud
2. Add an S3-compatible storage with:
   - Bucket: `nextcloud`
   - Host: `s3.${DOMAIN}`
   - Port: `443`
   - Enable SSL
   - Use MinIO access key/secret

### FileBrowser

- Browse and manage files in `${STORAGE_ROOT}` via web UI
- Default credentials: `admin` / `admin` (change on first login)
- Access at `https://files.${DOMAIN}`

### Syncthing

- P2P file synchronization between devices
- Web UI at `https://sync.${DOMAIN}`
- GUI credentials set on first login
- Data synced from `${STORAGE_ROOT}`

## Volumes

| Volume | Description |
|--------|-------------|
| `nextcloud-data` | Nextcloud application and data |
| `nextcloud-custom-apps` | Nextcloud custom apps |
| `nextcloud-config` | Nextcloud configuration |
| `minio-data` | MinIO object storage data |
| `filebrowser-data` | FileBrowser database |
| `syncthing-config` | Syncthing configuration |

## DNS Records Required

```
nextcloud.${DOMAIN}  →  your-server-ip
minio.${DOMAIN}      →  your-server-ip
s3.${DOMAIN}         →  your-server-ip
files.${DOMAIN}      →  your-server-ip
sync.${DOMAIN}       →  your-server-ip
```

## Troubleshooting

### Nextcloud won't start
```bash
# Check database connectivity
docker compose logs nextcloud-db-check
# Check Nextcloud logs
docker compose logs nextcloud
```

### MinIO buckets not created
```bash
# Re-run init container
docker compose up minio-init
docker compose logs minio-init
```

### FileBrowser shows empty directory
Verify `STORAGE_ROOT` in `.env` points to the correct host path and has files.

## References

- [Nextcloud FPM Documentation](https://docs.nextcloud.com/server/latest/admin_manual/installation/nginx.html)
- [MinIO Documentation](https://min.io/docs/minio/linux/index.html)
- [FileBrowser Documentation](https://filebrowser.org/)
- [Syncthing Documentation](https://docs.syncthing.net/)
