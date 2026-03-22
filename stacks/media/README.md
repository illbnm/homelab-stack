# 🎬 Media Stack

Complete self-hosted media management suite. Automatically searches, downloads, organizes, and streams your media library.

## Services

| Service | Image | URL | Purpose |
|---------|-------|-----|---------|
| Jellyfin | `jellyfin/jellyfin:10.9.11` | `jellyfin.example.com` | Media streaming server |
| Sonarr | `lscr.io/linuxserver/sonarr:4.0.11` | `sonarr.example.com` | TV series management |
| Radarr | `lscr.io/linuxserver/radarr:5.8.1` | `radarr.example.com` | Movie management |
| Prowlarr | `lscr.io/linuxserver/prowlarr:1.22.0` | `prowlarr.example.com` | Indexer management |
| qBittorrent | `lscr.io/linuxserver/qbittorrent:4.6.7` | `qbittorrent.example.com` | Torrent downloader |
| Jellyseerr | `fallenbagel/jellyseerr:2.1.1` | `jellyseerr.example.com` | Media request portal |

## Prerequisites

- Base infrastructure stack running (`proxy` network must exist)
- Host directories created (see below)

## Directory Structure

Following [TRaSH Guides](https://trash-guides.info/Hardlinks/How-to-setup-for/Docker/) hardlink best practice — **all data on the same filesystem** enables instant hardlinks (no copying):

```
/data/
├── torrents/              # qBittorrent download root (DOWNLOADS_ROOT)
│   ├── movies/            # radarr category
│   └── tv/                # sonarr category
└── media/                 # Jellyfin library root (MEDIA_ROOT)
    ├── movies/
    └── tv/
```

```bash
# Create directories
sudo mkdir -p /data/{torrents/{movies,tv},media/{movies,tv}}
sudo chown -R $USER:$USER /data
```

## Quick Start

```bash
# 1. Create host directories
sudo mkdir -p /data/{torrents/{movies,tv},media/{movies,tv}}
sudo chown -R $(id -u):$(id -g) /data

# 2. Configure environment
cp stacks/media/.env.example stacks/media/.env
# Edit DOMAIN, MEDIA_ROOT, DOWNLOADS_ROOT, PUID, PGID

# 3. Start the stack (order is managed by depends_on)
cd stacks/media
docker compose up -d

# 4. Check health
docker compose ps
```

## Post-Start Configuration

### 1. qBittorrent — Initial Setup

Default credentials: `admin` / `adminadmin` (change immediately!)

In qBittorrent Settings:
- **Downloads → Save files to location**: `/downloads`
- **BitTorrent → Categories**: add `movies` → `/downloads/movies`, `tv` → `/downloads/tv`
- **Web UI**: set a strong password
- **Advanced → Network interface**: (optional) bind to VPN if using one

### 2. Prowlarr — Add Indexers

1. Go to `https://prowlarr.example.com`
2. **Indexers → Add Indexer**: add your preferred torrent/usenet indexers
3. **Settings → Apps → Add App**: connect to Sonarr and Radarr (auto-sync indexers)

### 3. Sonarr — Connect to qBittorrent

1. Go to `https://sonarr.example.com`
2. **Settings → Download Clients → Add**: qBittorrent
   - Host: `qbittorrent` (container name)
   - Port: `8080`
   - Username/Password: your qBittorrent credentials
   - Category: `tv`
3. **Settings → Media Management**: set root folder to `/data/media/tv`
4. Prowlarr will auto-sync indexers after step 2 above

### 4. Radarr — Connect to qBittorrent

Same as Sonarr, but:
- Category: `movies`
- Root folder: `/data/media/movies`

### 5. Jellyfin — Add Media Library

1. Go to `https://jellyfin.example.com` → complete initial setup wizard
2. **Dashboard → Libraries → Add Media Library**:
   - Type: Movies → Folder: `/data/media/movies`
   - Type: TV Shows → Folder: `/data/media/tv`
3. Trigger a library scan

### 6. Jellyseerr — Connect to Jellyfin + Arr Stack

1. Go to `https://jellyseerr.example.com`
2. Sign in with Jellyfin credentials
3. Configure Sonarr/Radarr under **Settings → Services**

## Hardware Acceleration (Optional)

### Intel Quick Sync (iGPU)

Uncomment in `docker-compose.yml`:
```yaml
devices:
  - /dev/dri:/dev/dri
```

In Jellyfin Dashboard → Playback → Transcoding: select "Intel Quick Sync Video"

### NVIDIA GPU

```yaml
runtime: nvidia
environment:
  NVIDIA_VISIBLE_DEVICES: all
```

Requires: [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)

## Network Architecture

```
Internet → Traefik (proxy network)
             ├── jellyfin.domain → Jellyfin:8096
             ├── sonarr.domain → Sonarr:8989
             ├── radarr.domain → Radarr:7878
             ├── prowlarr.domain → Prowlarr:9696
             ├── qbittorrent.domain → qBittorrent:8080
             └── jellyseerr.domain → Jellyseerr:5055

Internal (media_internal network — services communicate here):
  Sonarr ←→ qBittorrent
  Radarr ←→ qBittorrent
  Prowlarr → Sonarr, Radarr (indexer sync)
  Jellyseerr → Jellyfin, Sonarr, Radarr
```

## FAQ

**Q: Sonarr says "Unable to connect to qBittorrent"**
A: Use container name `qbittorrent` as the host (not `localhost` or an IP). Both containers must be on `media_internal` network.

**Q: Hardlinks not working / Radarr copies instead of moving**
A: Ensure `MEDIA_ROOT` and `DOWNLOADS_ROOT` are on the **same filesystem** and the same physical disk. If they're on different volumes, hardlinks are impossible and files will be copied.

**Q: Jellyfin is slow / transcoding fails**
A: Enable hardware acceleration (see above). Without it, Jellyfin transcodes in software which is CPU-intensive.

**Q: qBittorrent WebUI not accessible**
A: Check logs: `docker compose logs qbittorrent`. The initial password is printed to logs on first run if you haven't set one.

**Q: How do I update service versions?**
A: Watchtower handles auto-updates for containers with `com.centurylinklabs.watchtower.enable: "true"` label. To manually update: `docker compose pull && docker compose up -d`
