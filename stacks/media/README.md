# Media Stack

Complete media management and streaming suite for HomeLab.

## What's Included

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| Jellyfin | 10.9.11 | `media.<DOMAIN>` | Media server & streaming |
| Jellyseerr | 2.1.0 | `requests.<DOMAIN>` | Media request management |
| Sonarr | 4.0.9 | `sonarr.<DOMAIN>` | TV series management |
| Radarr | 5.11.0 | `radarr.<DOMAIN>` | Movie management |
| Prowlarr | 1.24.3 | `prowlarr.<DOMAIN>` | Indexer manager |
| qBittorrent | 4.6.7 | `bt.<DOMAIN>` | Download client |

## Architecture

```
Jellyseerr ──┬── Sonarr ──┬── Prowlarr ──→ Indexers
             │            │
             ├── Radarr ──┤
             │            └── qBittorrent ──→ downloads/
             └── Jellyfin ──→ media/
                              (streaming)
```

## Prerequisites

- Base infrastructure stack running (Traefik + proxy network)
- Host directories for media and downloads:
  ```bash
  mkdir -p /opt/homelab/media /opt/homelab/downloads
  chown -R 1000:1000 /opt/homelab/media /opt/homelab/downloads
  ```

## Quick Start

```bash
cd stacks/media
cp .env.example .env
# Edit .env with your DOMAIN, MEDIA_PATH, DOWNLOAD_PATH
docker compose up -d
```

## Configuration

| Variable | Required | Description |
|----------|----------|-------------|
| `DOMAIN` | ✅ | Base domain |
| `TZ` | ✅ | Timezone |
| `PUID` | ✅ | User ID for file permissions |
| `PGID` | ✅ | Group ID for file permissions |
| `MEDIA_PATH` | ✅ | Host path for organized media |
| `DOWNLOAD_PATH` | ✅ | Host path for downloads |

## Post-Deploy Setup

1. **Jellyfin**: Open `https://media.<DOMAIN>` — run setup wizard, add media libraries
2. **Jellyseerr**: Open `https://requests.<DOMAIN>` — connect to Jellyfin, Sonarr, Radarr
3. **Sonarr/Radarr**: Configure download clients and quality profiles
4. **Prowlarr**: Add indexers, then sync to Sonarr/Radarr
5. **qBittorrent**: Default credentials — change immediately via Settings

## Health Checks

All services include Docker health checks. Verify status:

```bash
docker compose ps
```
