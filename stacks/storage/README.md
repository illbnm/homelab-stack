# Storage Stack

Nextcloud + MinIO + FileBrowser for file storage and management.

## Services

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| Nextcloud | 29.0.9 | `nextcloud.<DOMAIN>` | Cloud file sync |
| MinIO | 2024-11-17 | `minio.<DOMAIN>` | S3-compatible storage |
| FileBrowser | 2.31.2 | `files.<DOMAIN>` | Web file manager |

## Quick Start

```bash
docker compose -f stacks/storage/docker-compose.yml up -d
```

Post-install: run Nextcloud setup wizard, configure MinIO access keys.
