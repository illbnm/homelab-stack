# Media Stack

Complete media management stack with Jellyfin, Sonarr, Radarr, Prowlarr, qBittorrent, and Jellyseerr.

## Services

| Service | Version | Description |
|---------|---------|-------------|
| Jellyfin | 10.9.11 | Media server |
| Sonarr | 4.0.11 | TV series management |
| Radarr | 5.8.1 | Movie management |
| Prowlarr | 1.22.0 | Indexer manager |
| qBittorrent | 4.6.7 | Download client |
| Jellyseerr | 2.1.1 | Media request management |

## Quick Start

```bash
# 1. Copy environment template
cp stacks/media/.env.example .env

# 2. Edit .env with your settings
nano .env

# 3. Create media directories
mkdir -p /opt/homelab/media/{movies,tv}
mkdir -p /opt/homelab/downloads/{movies,tv}

# 4. Start the media stack
docker compose -f stacks/media/docker-compose.yml up -d
```

## Directory Structure

Follows [TRaSH Guides](https://trash-guides.info/Hardlinks/How-to-setup-for/Docker/) hardlink best practices:

```
/opt/homelab/
├── media/
│   ├── movies/
│   └── tv/
└── downloads/
    ├── movies/
    └── tv/
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DOMAIN` | Your domain | `yourdomain.com` |
| `MEDIA_ROOT` | Media directory | `/opt/homelab/media` |
| `DOWNLOADS_ROOT` | Downloads directory | `/opt/homelab/downloads` |
| `TZ` | Timezone | `Asia/Shanghai` |
| `PUID` | User ID | `1000` |
| `PGID` | Group ID | `1000` |
| `QBITTORRENT_USER` | qBittorrent username | `admin` |
| `QBITTORRENT_PASSWORD` | qBittorrent password | - |

## Service URLs

| Service | URL |
|---------|-----|
| Jellyfin | https://jellyfin.${DOMAIN} |
| Sonarr | https://sonarr.${DOMAIN} |
| Radarr | https://radarr.${DOMAIN} |
| Prowlarr | https://prowlarr.${DOMAIN} |
| qBittorrent | https://qbittorrent.${DOMAIN} |
| Jellyseerr | https://jellyseerr.${DOMAIN} |

## Configuration

### Connect Sonarr to qBittorrent

1. Open Sonarr → Settings → Download Clients
2. Add qBittorrent
3. Settings:
   - Host: `qbittorrent`
   - Port: `8080`
   - Username: from .env
   - Password: from .env

### Connect Radarr to qBittorrent

Same as Sonarr but in Radarr settings.

### Connect Sonarr/Radarr to Prowlarr

1. Open Sonarr → Settings → Indexers
2. Add Prowlarr
3. URL: `http://prowlarr:9696`
4. API Key: from .env (`PROWLARR_API_KEY`)

### Add Jellyfin Media Library

1. Open Jellyfin → Library
2. Add Media Library
3. Select folder:
   - Movies: `/media/movies`
   - TV: `/media/tv`

### Configure Jellyseerr

1. Open Jellyseerr
2. Configure Jellyfin:
   - URL: `http://jellyfin:8096`
   - API Key: Get from Jellyfin dashboard → API

## CN Mirror Support

For users in China, add to your `.env`:

```bash
CN_MODE=true
```

This will use alternative image sources for lscr.io images.

## Health Checks

All services have health checks configured. Verify with:

```bash
docker compose -f stacks/media/docker-compose.yml ps
```

## Troubleshooting

### Services can't connect to each other

Ensure all services are on the same Docker network (`homelab_internal`).

### qBittorrent web UI not accessible

Check if the correct ports are mapped and credentials match `.env`.

### Media not showing in Jellyfin

Verify the media path is correctly mounted and permissions are set (PUID/PGID).

### Download permissions

Ensure the download directory has correct permissions:
```bash
chown -R 1000:1000 /opt/homelab/downloads
```

## API Keys

Generate secure API keys:

```bash
openssl rand -hex 32
```

## Security

- Change default qBittorrent credentials in `.env`
- All services exposed through Traefik with HTTPS
- Consider enabling Authentik Forward Auth for protected access
