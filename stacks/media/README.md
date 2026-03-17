# Media Stack

> Complete media stack - Jellyfin, Sonarr, Radarr, Prowlarr, qBittorrent, Jellyseerr

## 💰 Bounty

**$200 USDT** - See [BOUNTY.md](../../BOUNTY.md)

## Services

| Service | Image | Purpose |
|---------|-------|---------|
| Jellyfin | `jellyfin/jellyfin:10.9.11` | Media server |
| Sonarr | `lscr.io/linuxserver/sonarr:4.0.11` | TV series management |
| Radarr | `lscr.io/linuxserver/radarr:5.8.1` | Movie management |
| Prowlarr | `lscr.io/linuxserver/prowlarr:1.22.0` | Indexer management |
| qBittorrent | `lscr.io/linuxserver/qbittorrent:4.6.7` | Torrent downloader |
| Jellyseerr | `fallenbagel/jellyseerr:2.1.1` | Media request management |

## Prerequisites

1. **Base Infrastructure** stack deployed (Traefik required)
2. **Docker & Docker Compose** installed
3. **Domain** configured in Base Infrastructure

## Quick Start

### 1. Configure environment

```bash
cd stacks/media
cp .env.example .env
# Edit .env with your settings
```

### 2. Create data directories

```bash
# Create media and downloads directories
mkdir -p data/media/movies
mkdir -p data/media/tv
mkdir -p data/downloads/movies
mkdir -p data/downloads/tv
```

### 3. Start services

```bash
docker compose up -d
```

### 4. Verify services

```bash
docker compose ps
```

## Configuration

### Required Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `DOMAIN` | Your domain | `example.com` |
| `PUID` | User ID | `1000` |
| `PGID` | Group ID | `1000` |
| `MEDIA_ROOT` | Media directory | `/data/media` |
| `DOWNLOADS_ROOT` | Downloads directory | `/data/downloads` |

### Get PUID/PGID

```bash
id your-username
# Output: uid=1000(username) gid=1000(group)
```

### Optional Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `TZ` | `Asia/Shanghai` | Timezone |
| `QB_USERNAME` | `admin` | qBittorrent username |
| `QB_PASSWORD` | `adminadmin` | qBittorrent password |

## Access URLs

After startup:

| Service | URL |
|---------|-----|
| Jellyfin | `https://jellyfin.yourdomain.com` |
| Sonarr | `https://sonarr.yourdomain.com` |
| Radarr | `https://radarr.yourdomain.com` |
| Prowlarr | `https://prowlarr.yourdomain.com` |
| qBittorrent | `https://qbittorrent.yourdomain.com` |
| Jellyseerr | `https://jellyseerr.yourdomain.com` |

## Directory Structure

```
data/
├── media/
│   ├── movies/
│   └── tv/
└── downloads/
    ├── movies/
    └── tv/
```

This follows [TRaSH Guides](https://trash-guides.info/Hardlinks/How-to-setup-for/Docker/) hardlink best practices.

## Service Configuration

### Prowlarr (Indexer Management)

1. Access Prowlarr at `https://prowlarr.yourdomain.com`
2. Go to **Settings → Indexers**
3. Add indexers (e.g.,rarbg, 1337x, etc.)
4. Configure API keys if required

### Sonarr (TV Series)

1. Access Sonarr at `https://sonarr.yourdomain.com`
2. Go to **Settings → Download Clients**
3. Add qBittorrent:
   - Host: `qbittorrent`
   - Port: `8080`
   - Username/Password from `.env`
4. Go to **Settings → Media Management**
5. Add root folder: `/data/media/tv`
6. Configure quality profiles

### Radarr (Movies)

1. Access Radarr at `https://radarr.yourdomain.com`
2. Go to **Settings → Download Clients**
3. Add qBittorrent (same as Sonarr)
4. Go to **Settings → Media Management**
5. Add root folder: `/data/media/movies`
6. Configure quality profiles

### qBittorrent (Downloads)

1. Access qBittorrent at `https://qbittorrent.yourdomain.com`
2. Default login: `admin` / `adminadmin` (change in `.env`)
3. Go to **Options → Downloads**
4. Set default save path: `/data/downloads`
5. Configure category mappings:
   - `/data/downloads/movies` → `movies`
   - `/data/downloads/tv` → `tv`

### Jellyfin (Media Server)

1. Access Jellyfin at `https://jellyfin.yourdomain.com`
2. Setup admin account
3. Add media library:
   - Content type: Movies
   - Folder: `/data/media/movies`
4. Add another library:
   - Content type: TV Shows
   - Folder: `/data/media/tv`

### Jellyseerr (Requests)

1. Access Jellyseerr at `https://jellyseerr.yourdomain.com`
2. Connect to Jellyfin:
   - URL: `http://jellyfin:8096`
   - API Key: Get from Jellyfin dashboard
3. Users can request movies/TV shows

## Health Checks

All services have health checks configured. Verify status:

```bash
docker compose ps
```

All services should show `healthy` status.

## Troubleshooting

### Check logs

```bash
# All services
docker compose logs -f

# Specific service
docker logs sonarr
docker logs radarr
docker logs qbittorrent
```

### Common issues

1. **Services can't connect to each other**
   - Ensure all are on `proxy` network
   - Use container names as hostnames

2. **qBittorrent Web UI not accessible**
   - Check `WEBUI_PORT=8080` is not conflicting
   - Verify Traefik labels

3. **Sonarr/Radarr can't download**
   - Verify qBittorrent is running
   - Check category mappings in qBittorrent
   - Ensure proper permissions (PUID/PGID)

4. **Jellyfin can't see media**
   - Check volume mounts are correct
   - Verify media directory permissions

5. **Can't connect to Prowlarr from Sonarr/Radarr**
   - Prowlarr API key needed
   - URL: `http://prowlarr:9696`

## Integration with Base Stack

The Media Stack uses the `proxy` network from Base Infrastructure. Ensure:

1. Base Infrastructure is deployed first
2. `proxy` network exists:
   ```bash
   docker network ls | grep proxy
   ```
3. If network doesn't exist, create it:
   ```bash
   docker network create proxy
   ```

## File Structure

```
stacks/media/
├── docker-compose.yml    # Main compose file
├── .env.example         # Environment template
└── README.md            # This file
```

## License

MIT
