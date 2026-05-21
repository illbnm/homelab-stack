# Media Stack

Complete media automation stack for HomeLab Stack — streaming, content management, and download automation.

## What's Included

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| Jellyfin | 10.9.11 | `media.<DOMAIN>` | Media streaming server |
| Sonarr | 4.0.9 | `sonarr.<DOMAIN>` | TV series management |
| Radarr | 5.11.0 | `radarr.<DOMAIN>` | Movie management |
| Prowlarr | 1.24.3 | `prowlarr.<DOMAIN>` | Indexer manager |
| qBittorrent | 4.6.7 | `bt.<DOMAIN>` | Download client |
| Jellyseerr | 1.7.0 | `requests.<DOMAIN>` | Content request portal |

## Architecture

```
Users
  │
  ├──► media.<DOMAIN>     ── Jellyfin (watch movies/TV)
  ├──► requests.<DOMAIN>  ── Jellyseerr (request new content)
  │
  ┌─── Automation ───────────────────────────┐
  │  Jellyseerr → Sonarr/Radarr → Prowlarr   │
  │       ↓              ↓            ↓       │
  │  Request ──► Find ──► Index ──► Download  │
  │                                  ↓       │
  │                          qBittorrent     │
  └──────────────────────────────────────────┘
       │
  /downloads ──► Jellyfin auto-discovers new content
  /media
```

## Quick Start

```bash
# Ensure base stack is running
cd stacks/base && docker compose up -d

# Create media directories on host
mkdir -p /opt/homelab/media/{movies,tv,music}
mkdir -p /opt/homelab/downloads/{complete,incomplete}

# Start media stack
cd ../media
ln -sf ../../.env .env
# Edit .env — set MEDIA_PATH, DOWNLOAD_PATH, DOMAIN
docker compose up -d
```

## Configuration

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DOMAIN` | Yes | — | Base domain |
| `MEDIA_PATH` | Yes | — | Host path for media library |
| `DOWNLOAD_PATH` | Yes | — | Host path for downloads |
| `TZ` | No | `Asia/Shanghai` | Timezone |
| `PUID`/`PGID` | No | `1000` | User/Group ID for file permissions |

### Jellyfin Setup

1. Visit `https://media.<DOMAIN>`
2. Complete setup wizard
3. Add media libraries pointing to `/media/movies`, `/media/tv`, etc.
4. Enable hardware transcoding if GPU available

### *arr Stack Setup

1. **Prowlarr** (`prowlarr.<DOMAIN>`): Add indexers (torrent trackers)
2. **Sonarr** (`sonarr.<DOMAIN>`): Settings → Media Management → Add root folder `/media/tv`
3. **Radarr** (`radarr.<DOMAIN>`): Settings → Media Management → Add root folder `/media/movies`
4. Connect Sonarr/Radarr to Prowlarr: Settings → Indexers → Add Prowlarr
5. Connect Sonarr/Radarr to qBittorrent: Settings → Download Clients → Add qBittorrent (`bt:8080`, user `admin`, password `adminadmin`)

### Jellyseerr Setup

1. Visit `https://requests.<DOMAIN>`
2. Sign in with Jellyfin account
3. Configure Sonarr/Radarr connections
4. Users can now request movies/TV shows via the portal

### qBittorrent

1. Visit `https://bt.<DOMAIN>`
2. Default login: `admin` / `adminadmin`
3. Change password in Tools → Options → Web UI
4. Set download path to `/downloads`

## Directory Structure

```
${MEDIA_PATH}/
  ├── movies/    ← Radarr manages this
  ├── tv/        ← Sonarr manages this
  └── music/

${DOWNLOAD_PATH}/
  ├── complete/   ← completed downloads
  └── incomplete/ ← active downloads
```

## CN Network Adaptation

LinuxServer images (`lscr.io`) may need CN mirror. Jellyfin and Jellyseerr are on Docker Hub.

```bash
CN_MODE=true ./scripts/cn-pull.sh
```

## Health Check

```bash
docker compose ps --format "table {{.Name}}\t{{.Status}}"
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Permission denied on media files | Ensure `PUID`/`PGID` match host user; `chown -R 1000:1000 /opt/homelab` |
| Jellyfin can't see media | Check `${MEDIA_PATH}` is correctly mounted; Jellyfin reads `/media` |
| Downloads not importing | Sonarr/Radarr need access to both `/media` and `/downloads` volumes |
| *arr can't connect to qBittorrent | Use container name `qbittorrent:8080` not localhost |
| Jellyseerr can't find Jellyfin | Use `http://jellyfin:8096` as internal URL |
