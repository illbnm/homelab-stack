# Media Stack

Complete media services stack with Jellyfin, Sonarr, Radarr, Prowlarr, qBittorrent, and Jellyseerr.

## Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| Jellyfin | `jellyfin/jellyfin:10.9.11` | 8096 | Media server |
| Prowlarr | `lscr.io/linuxserver/prowlarr:1.22.0` | 9696 | Indexer manager |
| Sonarr | `lscr.io/linuxserver/sonarr:4.0.11` | 8989 | TV series management |
| Radarr | `lscr.io/linuxserver/radarr:5.8.1` | 7878 | Movie management |
| qBittorrent | `lscr.io/linuxserver/qbittorrent:4.6.7` | 8080 | Download client |
| Jellyseerr | `fallenbagel/jellyseerr:2.1.1` | 5055 | Request management |

## Quick Start

```bash
# Copy environment template
cp stacks/media/.env.example stacks/media/.env

# Edit .env with your configuration
vim stacks/media/.env

# Start the stack
docker compose -f stacks/media/docker-compose.yml up -d

# Check status
docker compose -f stacks/media/docker-compose.yml ps
```

## Directory Structure

Following [TRaSH Guides](https://trash-guides.info/Hardlinks/How-to-setup-for/Docker/) hardlink best practices:

```
/data/
├── torrents/
│   ├── movies/
│   └── tv/
└── media/
    ├── movies/
    └── tv/
```

Configure these paths in your `.env`:
- `MEDIA_PATH=/mnt/media`
- `DOWNLOAD_PATH=/mnt/downloads`

## Access URLs

| Service | URL |
|---------|-----|
| Jellyfin | `https://media.${DOMAIN}` |
| Prowlarr | `https://prowlarr.${DOMAIN}` |
| Sonarr | `https://sonarr.${DOMAIN}` |
| Radarr | `https://radarr.${DOMAIN}` |
| qBittorrent | `https://bt.${DOMAIN}` |
| Jellyseerr | `https://requests.${DOMAIN}` |

## Service Configuration

### Sonarr + qBittorrent

1. In Sonarr: Settings → Download Clients → Add qBittorrent
2. Host: `qbittorrent`
3. Port: `8080`
4. Username/Password: set in qBittorrent web UI

### Radarr + qBittorrent

1. In Radarr: Settings → Download Clients → Add qBittorrent
2. Same settings as Sonarr

### Prowlarr Integration

1. In Sonarr: Settings → Indexers → Add Prowlarr
2. In Radarr: Settings → Indexers → Add Prowlarr
3. Point to `http://prowlarr:9696`

### Jellyseerr Setup

1. First, generate an API key in Jellyfin:
   - Dashboard → API Keys → Create New Key
   - Name: `jellyseerr`
   - Set `JELLYFIN_API_KEY` in `.env`

2. Access Jellyseerr at `https://requests.${DOMAIN}`
3. Complete setup wizard:
   - Enter your Jellyfin URL: `http://jellyfin:8096`
   - Enter API key
   - Configure Radarr and Sonarr URLs

## Health Checks

All services have health checks configured. Verify:

```bash
docker compose -f stacks/media/docker-compose.yml ps
```

All services should show `healthy` status.

## Troubleshooting

### qBittorrent Web UI not accessible

Check that port 8080 is not already in use:
```bash
docker compose logs qbittorrent
```

### Sonarr/Radarr can't connect to qBittorrent

Ensure both services are on the same Docker network and qBittorrent is fully started.

### Jellyseerr can't connect to Jellyfin

Verify `JELLYFIN_API_KEY` is set correctly in `.env` and restart the container:

```bash
docker compose -f stacks/media/docker-compose.yml restart jellyseerr
```
