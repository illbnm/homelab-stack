# Media Stack

Production-grade automated home theater media pipeline adhering strictly to [TRaSH Guides](https://trash-guides.info/Hardlinks/How-to-setup-for/Docker/) atomic moves and hardlink architecture.

## Services Architecture

| Service | Version | Access URL | Role |
|---|---|---|---|
| **Jellyfin** | `10.9.11` | `https://jellyfin.${DOMAIN}` | Open-source media streaming server |
| **Sonarr** | `4.0.11` | `https://sonarr.${DOMAIN}` | Automated TV show calendar, parser, and requester |
| **Radarr** | `5.8.1` | `https://radarr.${DOMAIN}` | Automated Movie collection manager |
| **Prowlarr** | `1.22.0` | `https://prowlarr.${DOMAIN}` | Centralized indexer and tracker proxy |
| **qBittorrent** | `4.6.7` | `https://torrent.${DOMAIN}` | High-speed BitTorrent daemon |
| **Jellyseerr** | `2.1.1` | `https://requests.${DOMAIN}` | User-friendly media discovery and request portal |

## TRaSH Hardlinks Volume Structure

To avoid slow cross-device I/O copies and duplicate disk usage, all media services mount the single parent volume `/data`:

```
/data/
├── torrents/
│   ├── movies/
│   └── tv/
└── media/
    ├── movies/
    └── tv/
```

When qBittorrent completes a download into `/data/torrents/movies/`, Radarr can instantly create an atomic hardlink to `/data/media/movies/` in 0 seconds with zero additional disk space consumed.

## Connecting Sonarr / Radarr to qBittorrent

1. In Sonarr/Radarr, navigate to **Settings** → **Download Clients**.
2. Add **qBittorrent**:
   - Host: `qbittorrent`
   - Port: `8080`
   - Use credentials configured during first login.
3. In **Settings** → **Indexers**, add Prowlarr via Prowlarr sync or API key.

## Quick Start

```bash
mkdir -p /data/torrents/movies /data/torrents/tv /data/media/movies /data/media/tv
cp stacks/media/.env.example stacks/media/.env
docker compose -f stacks/media/docker-compose.yml up -d
```
