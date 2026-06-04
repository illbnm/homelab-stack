# Storage Stack

> Self-hosted storage services: personal cloud, object storage, file browser, and P2P sync.

## Services

| Service | Image | URL | Purpose |
|---------|-------|-----|---------|
| Nextcloud | `nextcloud:29.0.7-fpm-alpine` | `nextcloud.DOMAIN` | Personal cloud storage |
| Nextcloud Nginx | `nginx:1.27-alpine` | (frontend for Nextcloud FPM) | Web frontend |
| MinIO | `minio/minio:RELEASE.2024-09-22T00-33-43Z` | `minio.DOMAIN` (console), `s3.DOMAIN` (API) | S3-compatible object storage |
| FileBrowser | `filebrowser/filebrowser:v2.31.1` | `files.DOMAIN` | Lightweight file manager |
| Syncthing | `lscr.io/linuxserver/syncthing:1.27.11` | `sync.DOMAIN` | P2P file synchronization |

## Prerequisites

1. **Base stack** running (creates `proxy` network, Traefik)
2. **Databases stack** running (provides `homelab-postgres` and `homelab-redis`)

## Quick Start

```bash
cd stacks/storage
cp .env.example .env
nano .env  # fill in passwords and domain
docker compose up -d
```

## Architecture

```
                   ┌─────────────────────────────────────────────┐
                   │              Traefik (proxy)                │
                   │  nextcloud.DOMAIN  minio.DOMAIN  s3.DOMAIN  │
                   │  files.DOMAIN      sync.DOMAIN              │
                   └───────┬──────┬──────┬──────┬──────┬────────┘
                           │      │      │      │      │
          ┌────────────────┼──────┼──────┼──────┼──────┼────────┐
          │  Storage Stack │      │      │      │      │        │
          │                │      │      │      │      │        │
          │   ┌────────────┤      │      │      │      │        │
          │   │ Nginx (:80)│      │      │      │      │        │
          │   │      │     │      │      │      │      │        │
          │   │ Nextcloud   │      │      │      │      │        │
          │   │ FPM (:9000) │      │      │      │      │        │
          │   └──────┬──────┘      │      │      │      │        │
          │          │             │      │      │      │        │
          │   ┌──────┴──────┐ ┌────┴───┐  │  ┌───┴────┐│        │
          │   │  databases  │ │ MinIO  │  │  │Syncthing│        │
          │   │  network    │ │:9000   │  │  │:8384    │        │
          │   │             │ │:9001   │  │  └─────────┘│        │
          │   └─────────────┘ └────────┘  │              │        │
          │                          ┌────┴───┐          │        │
          │                          │FileBrws│          │        │
          │                          │  :80   │          │        │
          │                          └────────┘          │        │
          └──────────────────────────────────────────────┘
```

## Configuration

### Nextcloud (FPM + Nginx)

- Uses **FPM mode** with Nginx as the web frontend
- PostgreSQL database from shared databases stack
- Redis for caching and file locking
- Configured with `trusted_proxies`, `overwriteprotocol=https`, `default_phone_region`
- DAV redirect middleware for CalDAV/CardDAV compatibility
- PHP tuning via `config/nextcloud/php.ini`

### OIDC / Authentik Integration

To enable SSO login via Authentik:

1. Install the **Social Login** app in Nextcloud (Admin → Apps)
2. Create a new OIDC application in Authentik:
   - **Provider type**: OAuth2/OpenID
   - **Client type**: Confidential
   - **Redirect URI**: `https://nextcloud.DOMAIN/index.php/apps/sociallogin/custom_oidc/authentik`
   - **Scopes**: `openid profile email`
3. Fill in the OIDC environment variables in `.env`

### MinIO

- Console accessible at `minio.DOMAIN`
- S3 API accessible at `s3.DOMAIN`
- Default buckets created automatically on first boot:
  - `nextcloud` — for Nextcloud external storage
  - `backups` — for backup storage
  - `media` — for media assets (public download policy)

Connect with `mc` client:
```bash
mc alias set homelab https://s3.DOMAIN minioadmin YOUR_PASSWORD
mc ls homelab/
```

### FileBrowser

- Browse `${STORAGE_ROOT}` directory via web UI
- Default credentials: `admin` / `admin` (change on first login)
- Database stored in `filebrowser-data` volume

### Syncthing

- Web GUI accessible at `sync.DOMAIN`
- Sync data stored in `${STORAGE_ROOT}`
- Configuration persisted in `syncthing-config` volume
- Add remote devices via the Web GUI to start syncing

## Volumes

| Volume | Purpose |
|--------|---------|
| `nextcloud-data` | Nextcloud application files and user data |
| `nextcloud-config` | Nextcloud configuration (`config.php`) |
| `minio-data` | MinIO object storage data |
| `filebrowser-data` | FileBrowser SQLite database |
| `syncthing-config` | Syncthing configuration and keys |

## Troubleshooting

### Nextcloud "trusted domain" error
Add your domain to `NEXTCLOUD_TRUSTED_DOMAINS` in the environment or edit `config.php` manually.

### MinIO init fails
Ensure MinIO is healthy before `minio-init` runs. The init container retries automatically.

### Syncthing not reachable from outside
Syncthing needs ports `22000/tcp` and `22000/udp` for device-to-device sync. Add port mappings if needed:
```yaml
ports:
  - 22000:22000/tcp
  - 22000:22000/udp
```
