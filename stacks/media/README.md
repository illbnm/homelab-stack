# Media Stack — Jellyfin + Sonarr + Radarr + Prowlarr + qBittorrent + Jellyseerr

Complete media automation stack following TRaSH Guides hardlink best practices.

## Services

| Service | Image | Port | URL |
|---------|-------|------|-----|
| Jellyfin | `jellyfin/jellyfin:10.9.11` | 8096 | `https://jellyfin.${DOMAIN}` |
| Sonarr | `lscr.io/linuxserver/sonarr:4.0.11` | 8989 | `https://sonarr.${DOMAIN}` |
| Radarr | `lscr.io/linuxserver/radarr:5.8.1` | 7878 | `https://radarr.${DOMAIN}` |
| Prowlarr | `lscr.io/linuxserver/prowlarr:1.22.0` | 9696 | `https://prowlarr.${DOMAIN}` |
| qBittorrent | `lscr.io/linuxserver/qbittorrent:4.6.7` | 8080 | `https://qbittorrent.${DOMAIN}` |
| Jellyseerr | `fallenbagel/jellyseerr:2.1.1` | 5055 | `https://jellyseerr.${DOMAIN}` |

All services are behind Traefik HTTPS with Authentik forward auth.

## Quick Start

```bash
cp .env.example .env
nano .env  # Set domain, PUID/PGID, paths

# Create directory structure
mkdir -p /data/torrents/movies /data/torrents/tv /data/media/movies /data/media/tv

docker compose up -d
```

## Directory Structure (TRaSH Guides Hardlink)

```
/data/
├── torrents/          # qBittorrent downloads
│   ├── movies/
│   └── tv/
└── media/             # Jellyfin library
    ├── movies/
    └── tv/
```

**Important:** `/data/torrents` and `/data/media` must be on the same filesystem for hardlinks to work. This allows Sonarr/Radarr to import completed downloads without duplicating file data.

## Setup Guide

### 1. qBittorrent

1. Visit `https://qbittorrent.${DOMAIN}`
2. Default login: admin / adminadmin (change immediately)
3. Set download path to `/data/torrents`

### 2. Prowlarr

1. Visit `https://prowlarr.${DOMAIN}`
2. Add indexers (public/private trackers)
3. Settings → Apps → Add Sonarr and Radarr connections
   - Sonarr: `http://sonarr:8989`
   - Radarr: `http://radarr:7878`

### 3. Sonarr (TV Series)

1. Visit `https://sonarr.${DOMAIN}`
2. Settings → Download Clients → Add qBittorrent
   - Host: `qbittorrent`
   - Port: `8080`
   - Username/Password: your qBittorrent credentials
3. Settings → Indexers → Add (synced from Prowlarr automatically)
4. Settings → Media Management → Root Folder: `/data/media/tv`
5. Enable hardlinks: Settings → Media Management → Import → Use Hardlinks instead of Copy

### 4. Radarr (Movies)

1. Visit `https://radarr.${DOMAIN}`
2. Settings → Download Clients → Add qBittorrent (same as Sonarr)
3. Settings → Indexers → (synced from Prowlarr)
4. Settings → Media Management → Root Folder: `/data/media/movies`
5. Enable hardlinks (same as Sonarr)

### 5. Jellyfin

1. Visit `https://jellyfin.${DOMAIN}`
2. Create admin account
3. Add Library:
   - Movies: `/media/movies`
   - TV Shows: `/media/tv`
4. Configure playback, transcoding as needed

### 6. Jellyseerr

1. Visit `https://jellyseerr.${DOMAIN}`
2. Connect to Jellyfin (Settings → Jellyfin):
   - Server: `http://jellyfin:8096`
   - API key: from Jellyfin dashboard
3. Connect to Sonarr (Settings → Sonarr):
   - Server: `http://sonarr:8989`
   - API key: from Sonarr settings
4. Connect to Radarr (Settings → Radarr):
   - Server: `http://radarr:7878`
   - API key: from Radarr settings

## Startup Order

Jellyseerr depends on Sonarr and Radarr being healthy before starting. All other services start independently.

## Hardware Transcoding (Optional)

For Jellyfin hardware transcoding, add to docker-compose.yml:

```yaml
devices:
  - /dev/dri:/dev/dri
```

Or use NVIDIA GPU:

```yaml
deploy:
  resources:
    reservations:
      devices:
        - driver: nvidia
          count: 1
          capabilities: [gpu]
```

## DNS Records

| Hostname | Service |
|----------|---------|
| `jellyfin.${DOMAIN}` | Jellyfin |
| `sonarr.${DOMAIN}` | Sonarr |
| `radarr.${DOMAIN}` | Radarr |
| `prowlarr.${DOMAIN}` | Prowlarr |
| `qbittorrent.${DOMAIN}` | qBittorrent |
| `jellyseerr.${DOMAIN}` | Jellyseerr |