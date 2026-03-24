# Media Stack

Complete self-hosted media management: streaming, TV/movie automation, and request management.

## Services

| Service | Image | URL | Purpose |
|---------|-------|-----|---------|
| Jellyfin | `jellyfin/jellyfin:10.9.11` | `jellyfin.<DOMAIN>` | Media streaming server |
| Sonarr | `lscr.io/linuxserver/sonarr:4.0.11` | `sonarr.<DOMAIN>` | TV series management |
| Radarr | `lscr.io/linuxserver/radarr:5.8.1` | `radarr.<DOMAIN>` | Movie management |
| Prowlarr | `lscr.io/linuxserver/prowlarr:1.22.0` | `prowlarr.<DOMAIN>` | Indexer management |
| qBittorrent | `lscr.io/linuxserver/qbittorrent:4.6.7` | `bt.<DOMAIN>` | Download client |
| Jellyseerr | `fallenbagel/jellyseerr:2.1.1` | `requests.<DOMAIN>` | Media requests |

## Directory Structure (TRaSH Guides)

Following [TRaSH Guides hardlink best practices](https://trash-guides.info/Hardlinks/How-to-setup-for/Docker/):

```
/data/                    ← DATA_ROOT in .env
├── torrents/             ← qBittorrent downloads here
│   ├── movies/           ← Radarr category
│   └── tv/               ← Sonarr category
└── media/                ← Organized libraries (hardlinked from torrents/)
    ├── movies/           ← Radarr root folder → Jellyfin movie library
    └── tv/               ← Sonarr root folder → Jellyfin TV library
```

Create the directories before starting:
```bash
mkdir -p /data/{torrents/{movies,tv},media/{movies,tv}}
chown -R 1000:1000 /data
```

## Quick Start

```bash
cd stacks/media
cp .env.example .env
nano .env               # Set DOMAIN, DATA_ROOT, PUID/PGID
docker compose up -d
```

## Post-Deploy Configuration

### 1. qBittorrent Setup

1. Open `bt.<DOMAIN>` — check container logs for initial admin password:
   ```bash
   docker logs qbittorrent 2>&1 | grep "temporary password"
   ```
2. Settings → Downloads → Default Save Path: `/data/torrents`
3. Create categories: `movies` (save path: `/data/torrents/movies`), `tv` (save path: `/data/torrents/tv`)

### 2. Prowlarr → Sonarr/Radarr

1. Open `prowlarr.<DOMAIN>`
2. Settings → Apps → Add Sonarr: URL = `http://sonarr:8989`, API Key from Sonarr
3. Settings → Apps → Add Radarr: URL = `http://radarr:7878`, API Key from Radarr
4. Add indexers in Indexers tab

### 3. Sonarr/Radarr → qBittorrent

1. Sonarr → Settings → Download Clients → Add → qBittorrent
   - Host: `qbittorrent`, Port: `8080`
   - Category: `tv`
2. Sonarr → Settings → Media Management → Root Folder: `/data/media/tv`
3. Radarr → same steps but Category: `movies`, Root: `/data/media/movies`

### 4. Jellyfin Media Libraries

1. Open `jellyfin.<DOMAIN>` and complete setup wizard
2. Add Libraries:
   - Movies → `/data/media/movies`
   - TV Shows → `/data/media/tv`

### 5. Jellyseerr

1. Open `requests.<DOMAIN>`
2. Connect to Jellyfin: URL = `http://jellyfin:8096`
3. Connect to Sonarr/Radarr with their internal URLs and API keys

## FAQ

**Q: Why use a single `/data` mount instead of separate paths?**
A: This enables hardlinks between `/data/torrents` and `/data/media` on the same filesystem, saving disk space and avoiding file copies.

**Q: How do I find API keys?**
A: Sonarr/Radarr → Settings → General → API Key. Prowlarr → Settings → General → API Key.

**Q: qBittorrent default password?**
A: Check container logs: `docker logs qbittorrent 2>&1 | grep password`
