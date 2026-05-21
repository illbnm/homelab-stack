# Storage Stack

Self-hosted file storage, object storage, and file management for HomeLab Stack.

## What's Included

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| Nextcloud | 29.0.9 | `nextcloud.<DOMAIN>` | Personal cloud (files, calendar, contacts) |
| MinIO | RELEASE.2024-11-07 | `minio.<DOMAIN>` (UI), `s3.<DOMAIN>` (API) | S3-compatible object storage |
| FileBrowser | v2.31.2 | `files.<DOMAIN>` | Lightweight file manager |

## Architecture

```
Users
  │
  ├──► nextcloud.<DOMAIN>  ── Nextcloud (files, PIM, sharing)
  ├──► minio.<DOMAIN>      ── MinIO Console (bucket management)
  ├──► s3.<DOMAIN>         ── MinIO S3 API (programmatic access)
  └──► files.<DOMAIN>      ── FileBrowser (quick file browse/upload)
       │
       ├──► homelab-postgres (databases network)
       └──► homelab-redis (databases network)
```

## Quick Start

```bash
# Ensure base + databases stacks are running first
cd stacks/base && docker compose up -d
cd ../databases && docker compose up -d

# Start storage
cd ../storage
ln -sf ../../.env .env
docker compose up -d
```

## Configuration

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DOMAIN` | Yes | — | Base domain |
| `TZ` | No | `Asia/Shanghai` | Timezone |
| `NEXTCLOUD_ADMIN_USER` | No | `admin` | Nextcloud admin username |
| `NEXTCLOUD_ADMIN_PASSWORD` | Yes | — | Nextcloud admin password |
| `NEXTCLOUD_DB_PASSWORD` | Yes | — | PostgreSQL password for nextcloud user |
| `REDIS_PASSWORD` | Yes | — | Redis password (shared with databases stack) |
| `MINIO_ROOT_USER` | No | `minioadmin` | MinIO admin username |
| `MINIO_ROOT_PASSWORD` | Yes | — | MinIO admin password |
| `STORAGE_PATH` | No | `/data` | Host path for FileBrowser |

### Nextcloud Setup

1. Visit `https://nextcloud.<DOMAIN>`
2. Login with `NEXTCLOUD_ADMIN_USER` / `NEXTCLOUD_ADMIN_PASSWORD`
3. Install recommended apps: Calendar, Contacts, Tasks, Notes
4. Configure external storage (optional): Settings → External Storage → Add local/S3 mount

**Nextcloud connects to the shared PostgreSQL and Redis instances** via the `databases` network. Make sure the databases stack is running first.

### MinIO Setup

1. Visit `https://minio.<DOMAIN>`
2. Login with `MINIO_ROOT_USER` / `MINIO_ROOT_PASSWORD`
3. Create buckets for your services (e.g., `backups`, `media`, `documents`)
4. Create access keys: Identity → Service Accounts → Create Access Key
5. Use the S3 API endpoint `https://s3.<DOMAIN>` in other services

### FileBrowser Setup

1. Visit `https://files.<DOMAIN>`
2. Default login: `admin` / `admin`
3. Change password immediately: Settings → User Management
4. Configure the storage path via `STORAGE_PATH` in `.env`

## Integration with Other Stacks

### Use MinIO as Nextcloud External Storage

In Nextcloud: Settings → External Storage → Add:
- Type: Amazon S3
- Bucket: `<your-bucket>`
- Host: `s3.<DOMAIN>`
- Access Key / Secret: from MinIO service account

### Use MinIO as Backup Target

In backup scripts, set:
```env
AWS_ENDPOINT_URL=https://s3.<DOMAIN>
AWS_ACCESS_KEY_ID=<minio-access-key>
AWS_SECRET_ACCESS_KEY=<minio-secret-key>
```

## SSO Integration

Nextcloud is protected by Authentik ForwardAuth. To enable:

1. Deploy the SSO stack (`stacks/sso/`)
2. Create an OIDC provider in Authentik for Nextcloud
3. Install Nextcloud OIDC Login app: `docker exec nextcloud occ app:install oidc_login`

MinIO and FileBrowser use Traefik ForwardAuth middleware.

## CN Network Adaptation

All images available on Docker Hub. Nextcloud may be slow to pull:

```bash
CN_MODE=true ./scripts/cn-pull.sh
```

## Health Check

```bash
docker compose ps --format "table {{.Name}}\t{{.Status}}"
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Nextcloud DB error | Ensure databases stack is running; check `NEXTCLOUD_DB_PASSWORD` matches |
| Nextcloud slow first start | Normal — runs DB migrations on first launch (up to 5 min) |
| MinIO console redirect loop | Check `MINIO_BROWSER_REDIRECT_URL` matches `minio.<DOMAIN>` |
| FileBrowser empty | Set `STORAGE_PATH` to a valid host directory |
| WebDAV not working | Traefik middleware handles `.well-known` redirects |
