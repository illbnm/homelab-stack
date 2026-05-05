

# Media Automation Stack

This stack provides a complete media automation solution with Jellyfin, Sonarr, Radarr, and qBittorrent.

## Setup Instructions

1. Copy `.env.example` to `.env` and customize the values:
   ```bash
   cp .env.example .env
   ```

2. Edit the `.env` file to set your specific values:
   - `PUID` and `PGID`: User and group IDs for file permissions
   - `TZ`: Your timezone
   - `DOMAIN`: Your domain for Traefik routing
   - `DATA_DIR`: Host path to your media data directory

3. Create the required directory structure:
   ```bash
   mkdir -p data/{downloads,media}
   ```

4. Start the stack:
   ```bash
   docker-compose up -d
   ```

## Library Configuration

After starting the services, you'll need to configure the library paths:

1. **Jellyfin**:
   - Add libraries pointing to `/data/media` (e.g., `/data/media/movies`, `/data/media/tv`)

2. **Sonarr**:
   - Set root folder to `/data/media/tv`
   - Configure download client to use qBittorrent

3. **Radarr**:
   - Set root folder to `/data/media/movies`
   - Configure download client to use qBittorrent

4. **qBittorrent**:
   - Set default save path to `/data/downloads`
   - Configure completed download handling to move files to `/data/media`

## Accessing Services

All services are accessible through Traefik at the following URLs:
- Jellyfin: https://jellyfin.yourdomain.com
- Sonarr: https://sonarr.yourdomain.com
- Radarr: https://radarr.yourdomain.com
- qBittorrent: https://qbittorrent.yourdomain.com

## Notes

- The stack uses a single root volume strategy (`/data`) for atomic moves between services
- All services are connected to the external `proxy` network for Traefik integration
- Health checks are configured for all services
- File permissions are managed through PUID/PGID environment variables

