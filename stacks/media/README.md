# Media Stack

A complete media automation and streaming solution combining Jellyfin media server with automated content acquisition through Sonarr, Radarr, and qBittorrent.

## Services Overview

### Jellyfin
- **Purpose**: Media server for streaming movies, TV shows, music, and other content
- **Port**: 8096
- **Features**: Web interface, mobile apps, transcoding, user management
- **Storage**: `/data/media` for content, `/data/jellyfin` for configuration

### Sonarr
- **Purpose**: TV show management and automation
- **Port**: 8989
- **Features**: Series monitoring, episode tracking, quality profiles, release management
- **Integration**: Connects to qBittorrent for downloads, Jellyfin for library updates

### Radarr
- **Purpose**: Movie management and automation
- **Port**: 7878
- **Features**: Movie monitoring, quality profiles, release management, collection tracking
- **Integration**: Connects to qBittorrent for downloads, Jellyfin for library updates

### qBittorrent
- **Purpose**: BitTorrent client for downloading content
- **Port**: 8080
- **Features**: Web interface, RSS feeds, category management, bandwidth controls
- **Default Credentials**: admin/adminpass (change immediately)

## Quick Setup

1. **Deploy the stack:**
   ```bash
   docker-compose up -d
   ```

2. **Initial Access:**
   - Jellyfin: http://localhost:8096
   - Sonarr: http://localhost:8989
   - Radarr: http://localhost:7878
   - qBittorrent: http://localhost:8080

3. **Complete setup wizard for each service**

## Configuration Guide

### 1. qBittorrent Setup

1. **Initial Login:**
   - Navigate to http://localhost:8080
   - Login with `admin/adminpass`
   - **Immediately change default password** in Tools > Options > Web UI

2. **Configure Download Paths:**
   - Go to Tools > Options > Downloads
   - Set "Default Save Path" to `/downloads/complete`
   - Set "Temp folder" to `/downloads/incomplete`
   - Enable "Create subfolders for torrents with multiple files"

3. **Categories Setup:**
   - Right-click in torrents area > Add Category
   - Add categories: `movies`, `tv-shows`
   - Set paths:
     - movies: `/downloads/complete/movies`
     - tv-shows: `/downloads/complete/tv-shows`

### 2. Sonarr Configuration

1. **Access Sonarr** at http://localhost:8989

2. **Add Download Client:**
   - Settings > Download Clients > Add > qBittorrent
   - Host: `qbittorrent`
   - Port: `8080`
   - Username/Password: your qBittorrent credentials
   - Category: `tv-shows`
   - Test connection

3. **Configure Root Folders:**
   - Settings > Media Management > Root Folders
   - Add `/data/media/tv-shows`

4. **Remote Path Mappings:**
   - Settings > Download Clients > Remote Path Mappings
   - Add mapping:
     - Host: `qbittorrent`
     - Remote Path: `/downloads/complete/tv-shows`
     - Local Path: `/downloads/complete/tv-shows`

### 3. Radarr Configuration

1. **Access Radarr** at http://localhost:7878

2. **Add Download Client:**
   - Settings > Download Clients > Add > qBittorrent
   - Host: `qbittorrent`
   - Port: `8080`
   - Username/Password: your qBittorrent credentials
   - Category: `movies`
   - Test connection

3. **Configure Root Folders:**
   - Settings > Media Management > Root Folders
   - Add `/data/media/movies`

4. **Remote Path Mappings:**
   - Settings > Download Clients > Remote Path Mappings
   - Add mapping:
     - Host: `qbittorrent`
     - Remote Path: `/downloads/complete/movies`
     - Local Path: `/downloads/complete/movies`

### 4. Jellyfin Setup

1. **Initial Setup:**
   - Navigate to http://localhost:8096
   - Create admin account
   - Skip remote access setup (configure later if needed)

2. **Add Media Libraries:**
   - Dashboard > Libraries > Add Media Library
   - **Movies:**
     - Content type: Movies
     - Display name: Movies
     - Folders: `/data/media/movies`
   - **TV Shows:**
     - Content type: Shows
     - Display name: TV Shows
     - Folders: `/data/media/tv-shows`

3. **Configure Library Settings:**
   - Enable "Real time monitoring" for automatic updates
   - Set appropriate metadata downloaders
   - Configure image fetchers

### 5. Indexers Configuration

For both Sonarr and Radarr, you'll need to add indexers:

1. **Built-in Indexers:**
   - Settings > Indexers > Add > Select from presets
   - Configure public trackers if needed

2. **Private Trackers:**
   - Add your private tracker indexers with API keys
   - Configure RSS feeds if supported

## File Structure

```
/data/
├── media/
│   ├── movies/
│   └── tv-shows/
├── downloads/
│   ├── complete/
│   │   ├── movies/
│   │   └── tv-shows/
│   └── incomplete/
├── jellyfin/
├── sonarr/
├── radarr/
└── qbittorrent/
```

## Quality Profiles

### Sonarr Quality Profile
1. Settings > Profiles > Quality Profiles
2. Create profile with desired quality tiers:
   - HDTV-720p
   - WEBDL-720p
   - HDTV-1080p
   - WEBDL-1080p

### Radarr Quality Profile
1. Settings > Profiles > Quality Profiles
2. Similar setup with movie-appropriate qualities

## Maintenance

### Regular Tasks
- Monitor disk space usage
- Clean up completed downloads periodically
- Update quality profiles as needed
- Check for service updates

### Backup Important Data
- Jellyfin configuration: `/data/jellyfin`
- Sonarr configuration: `/data/sonarr`
- Radarr configuration: `/data/radarr`
- qBittorrent configuration: `/data/qbittorrent`

## Troubleshooting

### Common Issues

**Q: Downloads not moving to media folders**
- Check Remote Path Mappings in Sonarr/Radarr
- Verify download client category settings
- Ensure proper permissions on folders

**Q: Jellyfin not detecting new content**
- Enable real-time monitoring in library settings
- Manually scan libraries: Dashboard > Libraries > Scan All Libraries
- Check file permissions and ownership

**Q: Cannot connect to qBittorrent from Sonarr/Radarr**
- Verify qBittorrent Web UI is enabled
- Check Docker network connectivity
- Confirm username/password are correct
- Ensure qBittorrent container is running

**Q: Downloads stuck in incomplete folder**
- Check qBittorrent settings for "Move completed downloads"
- Verify category paths are configured correctly
- Monitor qBittorrent logs for errors

**Q: High CPU usage from Jellyfin**
- Disable hardware acceleration if causing issues
- Limit concurrent transcoding streams
- Check client playback capabilities vs. media formats

### Log Locations
- Jellyfin: `/data/jellyfin/log/`
- Sonarr: `/data/sonarr/logs/`
- Radarr: `/data/radarr/logs/`
- qBittorrent: Container logs via `docker logs qbittorrent`

### Performance Optimization
- Use hardware acceleration for Jellyfin transcoding if supported
- Set appropriate quality profiles to avoid unnecessary large files
- Configure bandwidth limits in qBittorrent
- Use SSD storage for Jellyfin metadata and database

### Security Considerations
- Change default qBittorrent password immediately
- Use strong passwords for all services
- Consider using a VPN with qBittorrent
- Restrict access to services via firewall rules
- Keep all services updated

## Advanced Configuration

### VPN Integration
To use a VPN with qBittorrent, modify the docker-compose.yml:
```yaml
qbittorrent:
  network_mode: "container:vpn-container"
  depends_on:
    - vpn-container
```

### Reverse Proxy
Configure Nginx or Traefik for domain-based access and SSL termination.

### External Access
Use Jellyfin's built-in remote access or set up port forwarding with proper security measures.