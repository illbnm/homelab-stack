# 🎬 Media Automation Stack (Jellyfin, Sonarr, Radarr, Prowlarr, qBittorrent, Jellyseerr)

> Automated media discovery, indexing, torrent downloading, hardlink library organization, and streaming.

## 📦 Services

| Service | Image | Subdomain | Description |
|---|---|---|---|
| **Jellyfin** | `jellyfin/jellyfin:10.9.11` | `media.${DOMAIN}` | Open-source media streaming server |
| **Sonarr** | `lscr.io/linuxserver/sonarr:4.0.11` | `sonarr.${DOMAIN}` | TV show automation and tracking |
| **Radarr** | `lscr.io/linuxserver/radarr:5.8.1` | `radarr.${DOMAIN}` | Movie automation and tracking |
| **Prowlarr** | `lscr.io/linuxserver/prowlarr:1.22.0` | `prowlarr.${DOMAIN}` | Torrent & Usenet indexer manager |
| **qBittorrent** | `lscr.io/linuxserver/qbittorrent:4.6.7` | `qbit.${DOMAIN}` | Torrent client with Web UI |
| **Jellyseerr** | `fallenbagel/jellyseerr:2.1.1` | `requests.${DOMAIN}` | Request management and user discovery |

---

## 🔗 TRaSH Guides Unified Directory Structure (Atomic Hardlinks)
To avoid double disk usage and instantaneous file movement, all downloaders and arr services share a single `/data` mount:

```
/data/
├── torrents/
│   ├── movies/
│   └── tv/
└── media/
    ├── movies/
    └── tv/
```

- In **qBittorrent**: Set default download location to `/data/torrents/`.
- In **Sonarr**: Set root folder to `/data/media/tv`.
- In **Radarr**: Set root folder to `/data/media/movies`.
