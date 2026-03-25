# Media Stack

Complete media server stack with automated content management and downloading.

## Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| Jellyfin | `jellyfin/jellyfin:10.9.11` | 8096 | Media server |
| Sonarr | `lscr.io/linuxserver/sonarr:4.0.11` | 8989 | TV series management |
| Radarr | `lscr.io/linuxserver/radarr:5.8.1` | 7878 | Movie management |
| Prowlarr | `lscr.io/linuxserver/prowlarr:1.22.0` | 9696 | Indexer manager |
| qBittorrent | `lscr.io/linuxserver/qbittorrent:4.6.7` | 8080 | Download client |
| Jellyseerr | `fallenbagel/jellyseerr:2.1.1` | 5055 | Request manager |

## Quick Start

### 1. Create Directory Structure

```bash
# Following TRaSH Guides hardlink best practices
sudo mkdir -p /data/{torrents,media}/{movies,tv}
sudo chown -R 1000:1000 /data
```

### 2. Configure Environment

```bash
cp .env.example .env
nano .env
```

### 3. Start Services

```bash
docker compose up -d
```

### 4. Access Services

| Service | URL |
|---------|-----|
| Jellyfin | https://jellyfin.yourdomain.com |
| Sonarr | https://sonarr.yourdomain.com |
| Radarr | https://radarr.yourdomain.com |
| Prowlarr | https://prowlarr.yourdomain.com |
| qBittorrent | https://qbittorrent.yourdomain.com |
| Jellyseerr | https://jellyseerr.yourdomain.com |

## Directory Structure

Following [TRaSH Guides](https://trash-guides.info/Hardlinks/How-to-setup-for/Docker/) for hardlink support:

```
/data/
├── torrents/              # Downloads (can be deleted after import)
│   ├── movies/
│   └── tv/
└── media/                 # Final media library
    ├── movies/
    └── tv/
```

**Why this structure?**
- Enables hardlinks (same filesystem)
- Instant file moves (no copy)
- Saves disk space and I/O

## Configuration

### Step 1: Prowlarr (Indexers)

1. Access https://prowlarr.yourdomain.com
2. Add indexers (TorrentLeech, RARBG, etc.)
3. Settings → Apps → Add:
   - Sonarr: `http://sonarr:8989`
   - Radarr: `http://radarr:7878`

### Step 2: qBittorrent (Downloads)

1. Access https://qbittorrent.yourdomain.com
2. Default: admin / adminadmin
3. Tools → Options:
   - Set download path: `/data/torrents`
   - Enable "Use subcategories"

### Step 3: Sonarr (TV)

1. Access https://sonarr.yourdomain.com
2. Settings → Media Management:
   - Root folder: `/data/media/tv`
3. Settings → Download Clients:
   - Add qBittorrent
   - Host: `qbittorrent`
   - Port: `8080`
4. Add shows → Search episodes

### Step 4: Radarr (Movies)

1. Access https://radarr.yourdomain.com
2. Settings → Media Management:
   - Root folder: `/data/media/movies`
3. Settings → Download Clients:
   - Add qBittorrent
   - Host: `qbittorrent`
4. Add movies → Search

### Step 5: Jellyfin (Playback)

1. Access https://jellyfin.yourdomain.com
2. Setup wizard:
   - Create admin user
   - Add libraries:
     - Movies: `/media/movies`
     - TV Shows: `/media/tv`
3. Settings → Playback:
   - Enable hardware transcoding (if supported)

### Step 6: Jellyseerr (Requests)

1. Access https://jellyseerr.yourdomain.com
2. Sign in with Jellyfin account
3. Configure:
   - Jellyfin URL: `http://jellyfin:8096`
   - Sonarr: `http://sonarr:8989`
   - Radarr: `http://radarr:7878`

## Network Diagram

```
                    ┌─────────────────┐
                    │   Jellyseerr    │
                    │  (Requests)     │
                    └────────┬────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
         ▼                   ▼                   ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│     Sonarr      │ │     Radarr      │ │    Jellyfin     │
│   (TV Shows)    │ │    (Movies)     │ │ (Media Server)  │
└────────┬────────┘ └────────┬────────┘ └─────────────────┘
         │                   │
         └─────────┬─────────┘
                   │
                   ▼
         ┌─────────────────┐
         │   Prowlarr      │
         │  (Indexers)     │
         └────────┬────────┘
                  │
                  ▼
         ┌─────────────────┐
         │  qBittorrent    │
         │  (Downloads)    │
         └─────────────────┘
```

## Health Checks

```bash
# Check all services
docker compose ps

# Test individual services
curl -sf http://localhost:8096/health        # Jellyfin
curl -sf http://localhost:8989/health        # Sonarr
curl -sf http://localhost:7878/health        # Radarr
curl -sf http://localhost:9696/health        # Prowlarr
curl -sf http://localhost:8080/api/v2/app/version  # qBittorrent
curl -sf http://localhost:5055/api/v1/status # Jellyseerr
```

## Troubleshooting

### Permission Issues

```bash
# Fix permissions
sudo chown -R 1000:1000 /data
sudo chmod -R 775 /data
```

### Hardlinks Not Working

```bash
# Check if same filesystem
df -h /data/torrents /data/media

# Must show same device (e.g., /dev/sda1)
# If different, files will be copied instead of hardlinked
```

### qBittorrent Can't Connect

```bash
# Check if port is open
nc -zv your-server 6881

# Open firewall
sudo ufw allow 6881/tcp
sudo ufw allow 6881/udp
```

### Jellyfin Transcoding Issues

```bash
# Check GPU support
docker exec jellyfin ls -la /dev/dri

# Enable in docker-compose.yml:
# devices:
#   - /dev/dri:/dev/dri
```

## Resource Requirements

| Service | Min Memory | Recommended |
|---------|------------|-------------|
| Jellyfin | 512 MB | 1-2 GB |
| Sonarr | 128 MB | 256 MB |
| Radarr | 128 MB | 256 MB |
| Prowlarr | 64 MB | 128 MB |
| qBittorrent | 128 MB | 256 MB |
| Jellyseerr | 64 MB | 128 MB |
| **Total** | **1 GB** | **2-3 GB** |

## Security Notes

1. **Change default passwords** (especially qBittorrent)
2. **Use VPN** for torrenting (optional)
3. **Limit access** via Authentik (optional)
4. **Keep indexers private** (Prowlarr should not be public)

## License

MIT
