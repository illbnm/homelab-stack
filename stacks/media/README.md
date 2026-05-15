# Media Stack

Complete media automation stack: Jellyfin + Sonarr + Radarr + Prowlarr + qBittorrent + Jellyseerr.

## Services

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| Jellyfin | 10.9.11 | `media.${DOMAIN}` | Media server |
| Jellyseerr | 2.1.1 | `requests.${DOMAIN}` | Media request management |
| Sonarr | 4.0.9 | `sonarr.${DOMAIN}` | TV series management |
| Radarr | 5.11.0 | `radarr.${DOMAIN}` | Movie management |
| Prowlarr | 1.24.3 | `prowlarr.${DOMAIN}` | Indexer management |
| qBittorrent | 4.6.7 | `bt.${DOMAIN}` | Torrent downloader |

## Quick Start

```bash
# 1. Set media paths in .env
echo 'MEDIA_PATH=/mnt/media' >> .env
echo 'DOWNLOAD_PATH=/mnt/downloads' >> .env

# 2. Create directory structure (TRaSH Guide layout)
mkdir -p \$MEDIA_PATH/{movies,tv,music}
mkdir -p \$DOWNLOAD_PATH/{torrents/{movies,tv,music},usenet/{movies,tv,music}}

# 3. Start
docker compose -f stacks/media/docker-compose.yml up -d
```

## Directory Layout (Hardlinks)

```
/media/{movies,tv}
/downloads/torrents/{movies,tv}  → hardlinked to /media
/downloads/usenet/{movies,tv}
```

## Post-Install

1. Access each service and complete initial setup
2. Configure Prowlarr indexers
3. Connect Sonarr/Radarr to Prowlarr + qBittorrent
4. Connect Jellyseerr to Jellyfin, Sonarr, Radarr
5. Apply TRaSH Guide recommendations
