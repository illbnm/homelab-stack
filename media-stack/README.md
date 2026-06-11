# Media Stack — Jellyfin + Sonarr + Radarr + Prowlarr + qBittorrent + Jellyseerr

Complete media automation suite for the homelab.

## Components
- **Jellyfin** – Media server with web UI
- **Sonarr** – TV show download automation
- **Radarr** – Movie download automation
- **Prowlarr** – Indexer manager for Sonarr/Radarr
- **qBittorrent** – Torrent download client
- **Jellyseerr** – Media request and discovery frontend

## Deployment
1. Customize PUID/PGID and TZ in docker-compose.yml.
2. Start the stack: `docker compose up -d`
3. Access services via Traefik:
   - Jellyfin: `https://jellyfin.yourdomain.com`
   - Jellyseerr: `https://request.yourdomain.com`
4. Configure Sonarr/Radarr to use qBittorrent as download client and Prowlarr as indexer.
