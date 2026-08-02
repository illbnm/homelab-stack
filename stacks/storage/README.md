# Storage Stack

Provides comprehensive storage solutions: personal cloud drive, S3-compatible object storage, web-based file management, and P2P device synchronization.

## Included Services

- **Nextcloud**: Cloud drive (using FPM + Nginx web server for performance).
- **MinIO**: S3-compatible object storage. Automatically provisions buckets (`nextcloud`, `outline`) via an initialization container.
- **FileBrowser**: Web UI to browse and manage the physical host storage.
- **Syncthing**: P2P synchronization client for syncing folders across mobile/desktop devices.

## Setup & Configuration

1. Copy `.env.example` to `.env` and fill in the required variables. Ensure your database passwords match the `databases` stack.
2. Create the physical storage directory on the host if it does not exist (as defined by `STORAGE_ROOT`).
   ```bash
   sudo mkdir -p /data/storage/sync
   sudo chown -R 1000:1000 /data/storage
   ```
3. Start the stack:
   ```bash
   docker compose up -d
   ```

## Nextcloud Setup

- The Nextcloud container is pre-configured to use the shared PostgreSQL and Redis databases via environment variables.
- On the first run, accessing `cloud.yourdomain.com` will automatically finish the installation using the `NEXTCLOUD_ADMIN_USER` and `NEXTCLOUD_ADMIN_PASSWORD` you provided in `.env`.
- To configure **Authentik OIDC**, install the "OpenID Connect user backend" app in Nextcloud and configure it with your Authentik endpoints.

## MinIO Object Storage

- **Console UI**: `https://minio.yourdomain.com`
- **S3 API Endpoint**: `https://s3.yourdomain.com`
- The `minio-init` container will automatically run `mc mb` to create buckets (`outline` and `nextcloud`) on the first boot. 
- You can use MinIO as the Primary Storage backend for Nextcloud by editing the `config.php` inside the Nextcloud container.
