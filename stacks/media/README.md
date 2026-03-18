# Media Stack

Complete media server stack for automated TV/movie management with request handling.

## Services

| Service | Image | Port | URL | Purpose |
|---------|-------|------|-----|---------|
| Jellyfin | `jellyfin/jellyfin:10.9.11` | 8096 | `jellyfin.DOMAIN` | Media server & player |
| Sonarr | `lscr.io/linuxserver/sonarr:latest` | 8989 | `sonarr.DOMAIN` | TV series management |
| Radarr | `lscr.io/linuxserver/radarr:latest` | 7878 | `radarr.DOMAIN` | Movie management |
| Prowlarr | `lscr.io/linuxserver/prowlarr:latest` | 9696 | `prowlarr.DOMAIN` | Indexer management |
| qBittorrent | `lscr.io/linuxserver/qbittorrent:latest` | 8080 | `bt.DOMAIN` | Download client |
| Jellyseerr | `fallenbagel/jellyseerr:2.1.0` | 5055 | `requests.DOMAIN` | Media request portal |

## Quick Start

```bash
# 1. Create data directories (TRaSH Guides structure)
sudo mkdir -p /data/{torrents/{movies,tv},media/{movies,tv}}
sudo chown -R 1000:1000 /data

# 2. Configure environment
cp .env.example .env
# Edit .env — set DOMAIN, DATA_ROOT, TZ

# 3. Create proxy network (if not already created by base stack)
docker network create proxy

# 4. Start all services
docker compose up -d

# 5. Verify health
docker compose ps
```

## Directory Structure (TRaSH Guides)

This stack follows the [TRaSH Guides hardlink best practices](https://trash-guides.info/Hardlinks/How-to-setup-for/Docker/). All services share a single `/data` mount point, enabling **instant hardlinks** instead of slow copy+delete operations.

```
/data/                          ← DATA_ROOT in .env
├── torrents/                   ← qBittorrent download root
│   ├── movies/                 ← Radarr download category
│   └── tv/                     ← Sonarr download category
└── media/                      ← Jellyfin library root
    ├── movies/                 ← Radarr root folder
    └── tv/                     ← Sonarr root folder
```

**Why this matters:**
- Sonarr/Radarr use hardlinks to "move" completed downloads → zero disk space wasted
- No cross-filesystem copies — everything is on the same mount
- Seeding continues after import (hardlink points to same data)

## Post-Deployment Setup

### 1. qBittorrent — First Login

```bash
# Get the temporary admin password from logs
docker logs homelab-qbittorrent 2>&1 | grep "temporary password"
```

Then open `https://bt.DOMAIN`:
1. Log in with `admin` / `<temporary password>`
2. Go to **Settings → Downloads**:
   - Default Save Path: `/data/torrents/`
   - Keep torrent in: (leave empty)
3. Go to **Settings → Web UI**:
   - Change the admin password
4. Go to **Settings → BitTorrent**:
   - Enable DHT, PeX, and Local Peer Discovery as needed

### 2. Prowlarr — Add Indexers

Open `https://prowlarr.DOMAIN`:
1. Go to **Settings → General** → set API key or note the existing one
2. Go to **Indexers → Add Indexer** → add your preferred indexers
3. Go to **Settings → Apps → Add Application**:
   - Add **Sonarr**: URL = `http://homelab-sonarr:8989`, API key from Sonarr
   - Add **Radarr**: URL = `http://homelab-radarr:7878`, API key from Radarr
4. Prowlarr will auto-sync indexers to both apps

### 3. Sonarr — Configure Root Folder & Download Client

Open `https://sonarr.DOMAIN`:
1. Go to **Settings → Media Management**:
   - Add Root Folder: `/data/media/tv`
2. Go to **Settings → Download Clients → Add**:
   - Type: **qBittorrent**
   - Host: `homelab-qbittorrent`
   - Port: `8080`
   - Username: `admin`
   - Password: your qBittorrent password
   - Category: `tv`
3. Go to **Settings → Profiles** → configure quality profiles

### 4. Radarr — Configure Root Folder & Download Client

Open `https://radarr.DOMAIN`:
1. Go to **Settings → Media Management**:
   - Add Root Folder: `/data/media/movies`
2. Go to **Settings → Download Clients → Add**:
   - Type: **qBittorrent**
   - Host: `homelab-qbittorrent`
   - Port: `8080`
   - Username: `admin`
   - Password: your qBittorrent password
   - Category: `movies`
3. Go to **Settings → Profiles** → configure quality profiles

### 5. Jellyfin — Add Media Libraries

Open `https://jellyfin.DOMAIN`:
1. Complete the initial setup wizard
2. **Add Library → Movies**:
   - Content type: Movies
   - Folder: `/data/media/movies`
3. **Add Library → Shows**:
   - Content type: Shows
   - Folder: `/data/media/tv`
4. Configure metadata providers (TMDb, OMDb)

### 6. Jellyseerr — Connect to Jellyfin

Open `https://requests.DOMAIN`:
1. Select **Jellyfin** as media server
2. Enter Jellyfin URL: `http://homelab-jellyfin:8096`
3. Log in with Jellyfin admin credentials
4. Add Sonarr: `http://homelab-sonarr:8989` + API key
5. Add Radarr: `http://homelab-radarr:7878` + API key
6. Users can now request movies/shows through the Jellyseerr UI

## Request Flow

```
User requests a movie/show via Jellyseerr
  → Jellyseerr sends to Sonarr (TV) or Radarr (movies)
  → Sonarr/Radarr searches indexers via Prowlarr
  → Download sent to qBittorrent
  → qBittorrent downloads to /data/torrents/{movies,tv}/
  → Sonarr/Radarr hardlinks to /data/media/{movies,tv}/
  → Jellyfin detects new media and scans library
  → User watches in Jellyfin
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `TZ` | `Asia/Shanghai` | Timezone |
| `DOMAIN` | `example.com` | Base domain for Traefik routing |
| `PUID` | `1000` | User ID for file permissions |
| `PGID` | `1000` | Group ID for file permissions |
| `DATA_ROOT` | `/data` | Root data directory (TRaSH layout) |
| `BT_PORT` | `6881` | BitTorrent incoming port |

## FAQ

### Why a single `/data` mount instead of separate media/download paths?

The TRaSH Guides hardlink approach requires all directories on the **same filesystem**. A single `/data` mount ensures Sonarr/Radarr can create hardlinks from `/data/torrents/` to `/data/media/`, avoiding disk space duplication and slow file copies.

### How do I enable hardware transcoding in Jellyfin?

Add device passthrough to the Jellyfin service in `docker-compose.yml`:

```yaml
# Intel QuickSync (VAAPI)
devices:
  - /dev/dri:/dev/dri

# NVIDIA GPU
runtime: nvidia
environment:
  - NVIDIA_VISIBLE_DEVICES=all
```

Then enable hardware acceleration in Jellyfin → Dashboard → Playback → Transcoding.

### How do I update service versions?

Update the image tags in `docker-compose.yml`, then:

```bash
docker compose pull
docker compose up -d
```

Or let Watchtower handle it automatically if the base stack is running.

### qBittorrent shows "Unauthorized" on first access

Check the container logs for the temporary password:
```bash
docker logs homelab-qbittorrent 2>&1 | grep "temporary password"
```

### Sonarr/Radarr can't connect to qBittorrent

Verify the host is `homelab-qbittorrent` (container name, not localhost), port is `8080`, and credentials are correct. All services are on the same Docker network.
