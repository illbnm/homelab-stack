# 🎬 Media Stack

Complete self-hosted media automation stack following the [TRaSH Guides](https://trash-guides.info/) hardlink best practices.

## Services

| Service | Image | Port | URL | Purpose |
|---------|-------|------|-----|---------|
| **Jellyfin** | `jellyfin/jellyfin:10.9.11` | 8096 | `jellyfin.<DOMAIN>` | Media server & streaming |
| **Sonarr** | `lscr.io/linuxserver/sonarr:4.0.11` | 8989 | `sonarr.<DOMAIN>` | TV series automation |
| **Radarr** | `lscr.io/linuxserver/radarr:5.8.1` | 7878 | `radarr.<DOMAIN>` | Movie automation |
| **Prowlarr** | `lscr.io/linuxserver/prowlarr:1.22.0` | 9696 | `prowlarr.<DOMAIN>` | Indexer management |
| **qBittorrent** | `lscr.io/linuxserver/qbittorrent:4.6.7` | 8080 | `qbittorrent.<DOMAIN>` | Torrent downloader |
| **Jellyseerr** | `fallenbagel/jellyseerr:2.1.1` | 5055 | `jellyseerr.<DOMAIN>` | Media request portal |

## Architecture

