# Media Stack

This stack provides a complete, automated media management and streaming solution using the [TRaSH Guides](https://trash-guides.info/) methodology for hardlinking.

## Included Services

| Service | Function | URL |
|---------|----------|-----|
| **Jellyfin** | Media Server (Streaming) | `https://jellyfin.${DOMAIN}` |
| **Sonarr** | TV Show Management | `https://sonarr.${DOMAIN}` |
| **Radarr** | Movie Management | `https://radarr.${DOMAIN}` |
| **Prowlarr** | Indexer Manager | `https://prowlarr.${DOMAIN}` |
| **qBittorrent** | Torrent Downloader | `https://bt.${DOMAIN}` |
| **Jellyseerr** | Media Request Management | `https://jellyseerr.${DOMAIN}` |

## Directory Structure (Hardlinks)

To ensure that hardlinking works (which saves space by not duplicating files between your downloads and media folders), both `MEDIA_ROOT` and `DOWNLOADS_ROOT` **MUST** reside on the same underlying physical mount on the host.

Example host directory structure:
```
/data/
├── torrents/       <-- Set DOWNLOADS_ROOT to this
│   ├── movies/
│   └── tv/
└── media/          <-- Set MEDIA_ROOT to this
    ├── movies/
    └── tv/
```

Inside the containers, these are mounted as `/data/torrents` and `/data/media`, ensuring atomic moves and hardlinks work seamlessly across all *arr apps.

## Quick Start

1. Copy the example environment file:
   ```bash
   cp .env.example .env
   ```
2. Edit `.env` and set your `DOMAIN`, `PUID`, `PGID`, `MEDIA_ROOT`, and `DOWNLOADS_ROOT`.
3. Start the stack:
   ```bash
   docker compose up -d
   ```

## Configuration Steps

### 1. Connecting qBittorrent to Sonarr/Radarr

1. Open **Sonarr** / **Radarr** and go to `Settings` > `Download Clients`.
2. Add a new `qBittorrent` client.
3. Configure the connection:
   - **Host**: `qbittorrent` (use the internal Docker DNS name)
   - **Port**: `8080`
   - **Username/Password**: Use your qBittorrent credentials (default is usually `admin` / `adminadmin` unless changed in qBittorrent logs).
4. Save and Test.

### 2. Adding Media Libraries in Jellyfin

1. Open **Jellyfin** and go to the Admin Dashboard > `Libraries`.
2. Add a new library (e.g., "Movies").
3. For the folder path, browse to `/data/media/movies` (this maps to your host's `MEDIA_ROOT/movies`).
4. Add another library (e.g., "TV Shows") and map it to `/data/media/tv`.
5. Run a library scan.

## FAQ

**Q: Why are my files taking up double the space?**
A: Hardlinking is not working. Ensure that `MEDIA_ROOT` and `DOWNLOADS_ROOT` are on the exact same disk/partition on your host machine.

**Q: Why can't Sonarr/Radarr import downloaded files?**
A: Check permissions. The `PUID` and `PGID` set in the `.env` file must own the directories defined in `MEDIA_ROOT` and `DOWNLOADS_ROOT` on the host.
