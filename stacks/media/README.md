# Media Stack — Jellyfin + Sonarr + Radarr + qBittorrent + Prowlarr

Complete media server stack with automated downloading and streaming.

## Services

| Service | URL | Purpose |
|---------|-----|---------|
| **Jellyfin** | `https://media.${DOMAIN}` | Media streaming server |
| **Sonarr** | `https://sonarr.${DOMAIN}` | TV show automation |
| **Radarr** | `https://radarr.${DOMAIN}` | Movie automation |
| **Prowlarr** | `https://prowlarr.${DOMAIN}` | Indexer management |
| **qBittorrent** | `https://bt.${DOMAIN}` | Torrent download client |

## Quick Start

```bash
cp .env.example .env
# Edit .env: set DOMAIN, MEDIA_PATH, DOWNLOAD_PATH

docker compose up -d
```

## Workflow

1. **Prowlarr** manages indexers — configure once, all apps use it
2. **Sonarr/Radarr** monitor your watchlists, request downloads via qBittorrent
3. **qBittorrent** downloads to `DOWNLOAD_PATH`
4. Sonarr/Radarr rename + move completed files to `MEDIA_PATH`
5. **Jellyfin** scans `MEDIA_PATH` and streams to your devices

## First-Time Setup

1. Access each service and complete the initial setup wizard
2. In Sonarr/Radarr: Settings → Download Client → add qBittorrent
3. In Sonarr/Radarr: Settings → Indexers → add Prowlarr
4. In Sonarr: configure Media Management → rename episodes
5. In Jellyfin: add media library pointing to `/media`
