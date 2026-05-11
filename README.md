# Media Stack — Jellyfin + Sonarr + Radarr + qBittorrent + Prowlarr

**Bounty: $160 USDT**

Full media automation stack behind Traefik HTTPS.

## Services

| Service | Image | Purpose |
|---------|-------|---------|
| Jellyfin | `jellyfin/jellyfin:10.10` | Media server (movies, TV, music) |
| Sonarr | `sonarr:4.0` | TV show auto-download & organize |
| Radarr | `radarr:5.0` | Movie auto-download & organize |
| Prowlarr | `prowlarr:1.25` | Indexer management (Torrent + Usenet) |
| Flaresolverr | `flaresolverr` | Cloudflare bypass for indexers |
| qBittorrent | `qbittorrent:5.0` | Torrent client with web UI |
| NZBGet | `nzbget:24.5` | Usenet downloader (optional) |

## Architecture

```
Indexers ← Prowlarr → Flaresolverr (Cloudflare bypass)
                        ↓
Sonarr (TV) ──→ qBittorrent / NZBGet ──→ Downloads
Radarr (Movies) ──→                        ↓
                                       Jellyfin (Media Server)
```

## Domains

| Domain | Service |
|--------|---------|
| `media.example.com` | Jellyfin |
| `sonarr.media.example.com` | Sonarr |
| `radarr.media.example.com` | Radarr |
| `prowlarr.media.example.com` | Prowlarr |
| `torrent.media.example.com` | qBittorrent |
| `nzb.media.example.com` | NZBGet |

## Quick Start

```bash
cp .env.example .env
# Edit JELLYFIN_DOMAIN and MEDIA_ROOT

docker compose up -d

# Initial setup per service (one-time):
# 1. qBittorrent: http://torrent.domain:8080 (default: admin/adminadmin)
# 2. Jellyfin: http://media.domain:8096 — create admin account
# 3. Sonarr/Radarr/Prowlarr: configure indexers, download clients, root folders
```

## Directory Structure

```
${MEDIA_ROOT}/
├── movies/       # Radarr managed
├── tv/           # Sonarr managed
├── music/        # Jellyfin managed
└── downloads/    # qBittorrent / NZBGet output
```
