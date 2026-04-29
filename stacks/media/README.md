# Media Stack

Complete media automation stack: request → search → download → stream.

## What's Included

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| Jellyfin | 10.9.11 | `jellyfin.<DOMAIN>` | Media streaming server |
| Sonarr | 4.0.11 | `sonarr.<DOMAIN>` | TV series management |
| Radarr | 5.8.1 | `radarr.<DOMAIN>` | Movie management |
| Prowlarr | 1.22.0 | `prowlarr.<DOMAIN>` | Indexer aggregation |
| qBittorrent | 4.6.7 | `bt.<DOMAIN>` | BitTorrent download client |
| Jellyseerr | 2.1.1 | `seerr.<DOMAIN>` | Media request management |

## Architecture

```
User ──► Jellyseerr (request a movie/show)
              │
              ▼
         Sonarr/Radarr (search + grab)
              │
              ├──► Prowlarr (find on indexers)
              │
              └──► qBittorrent (download)
                      │
                      ▼
              /data/torrents/  ← download location
                      │
                      └──► hardlink → /data/media/  ← Jellyfin library
                              │
                              ▼
                         Jellyfin (stream to devices)
```

## Prerequisites

- Base stack running (Traefik on `proxy` network)
- Docker Compose v2.20+
- Sufficient disk space for media

## Quick Start

```bash
cd stacks/media
cp .env.example .env
# Edit .env — set DOMAIN and MEDIA_ROOT
vim .env

# Create directory structure on host (TRaSH Guides layout)
sudo mkdir -p ${MEDIA_ROOT}/{torrents/{movies,tv},media/{movies,tv}}
sudo chown -R ${PUID}:${PGID} ${MEDIA_ROOT}

# Symlink shared .env from repo root (or use local .env)
# ln -sf ../../.env .env

docker compose up -d
```

## Directory Structure (TRaSH Guides Hardlink Layout)

Following [TRaSH Guides](https://trash-guides.info/Hardlinks/How-to-setup-for/Docker/) for optimal hardlink support — downloads and media live on the **same filesystem**, so Sonarr/Radarr can hardlink instead of copy, saving disk space and I/O.

```
Host path (${MEDIA_ROOT})       Container mount point
─────────────────────────       ─────────────────────
/opt/homelab/media/             /data/
├── torrents/                   ├── torrents/        ← qBittorrent downloads here
│   ├── movies/                 │   ├── movies/
│   └── tv/                     │   └── tv/
└── media/                      └── media/           ← Jellyfin reads from here
    ├── movies/                     ├── movies/
    └── tv/                         └── tv/
```

**Key**: Both `torrents/` and `media/` are under the same `MEDIA_ROOT` mount. Sonarr/Radarr see the entire `/data` tree, enabling hardlinks from `/data/torrents/tv/Show/` → `/data/media/tv/Show/`.

## Configuration

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `TZ` | ✅ | `Asia/Shanghai` | Timezone |
| `DOMAIN` | ✅ | — | Base domain (e.g. `home.example.com`) |
| `PUID` | ✅ | `1000` | User ID for file permissions |
| `PGID` | ✅ | `1000` | Group ID for file permissions |
| `MEDIA_ROOT` | ✅ | `/opt/homelab/media` | Host path for all media data |

### Service URLs

| Service | URL |
|---------|-----|
| Jellyfin | `https://jellyfin.<DOMAIN>` |
| Sonarr | `https://sonarr.<DOMAIN>` |
| Radarr | `https://radarr.<DOMAIN>` |
| Prowlarr | `https://prowlarr.<DOMAIN>` |
| qBittorrent | `https://bt.<DOMAIN>` |
| Jellyseerr | `https://seerr.<DOMAIN>` |

## Post-Deploy Setup

### 1. Prowlarr — Add Indexers

1. Open `https://prowlarr.<DOMAIN>`
2. Complete the setup wizard
3. Go to **Settings → Indexers → Add Torznab Indexer** (e.g. 1337x, RARBG)
4. Go to **Settings → Apps → Add Application**
   - Add Sonarr: Prowlarr Server = `http://prowlarr:9696`, Sonarr Server = `http://sonarr:8989`
   - Add Radarr: Prowlarr Server = `http://prowlarr:9696`, Radarr Server = `http://radarr:7878`

### 2. qBittorrent — Default Credentials

- Default username: `admin`
- Default password: `adminadmin` (change on first login)

### 3. Sonarr — Connect Download Client

1. Open `https://sonarr.<DOMAIN>`
2. **Settings → Download Clients → Add → qBittorrent**
   - Host: `qbittorrent`
   - Port: `8080`
   - Username: `admin`
   - Password: *(your qBittorrent password)*
3. **Settings → Media Management → Root Folder**
   - Add root folder: `/data/media/tv`

### 4. Radarr — Connect Download Client

1. Open `https://radarr.<DOMAIN>`
2. **Settings → Download Clients → Add → qBittorrent**
   - Host: `qbittorrent`
   - Port: `8080`
   - Username: `admin`
   - Password: *(your qBittorrent password)*
3. **Settings → Media Management → Root Folder**
   - Add root folder: `/data/media/movies`

### 5. Jellyfin — Add Media Libraries

1. Open `https://jellyfin.<DOMAIN>`
2. Complete the setup wizard
3. **Dashboard → Libraries → Add Media Library**
   - Movies: path `/data/media/movies`, type `Movies`
   - TV Shows: path `/data/media/tv`, type `Shows`

### 6. Jellyseerr — Link Services

1. Open `https://seerr.<DOMAIN>`
2. Set up wizard:
   - Jellyfin URL: `http://jellyfin:8096`
   - Sonarr URL: `http://sonarr:8989` + API key (from Sonarr → Settings → General)
   - Radarr URL: `http://radarr:7878` + API key (from Radarr → Settings → General)

## Startup Order

```
prowlarr (healthy) ──► sonarr (healthy) ──► jellyseerr (healthy)
                   ──► radarr  (healthy) ──► ▲
qbittorrent (healthy) ──► sonarr, radarr ──► ▲
jellyfin (healthy) ─────────────────────────► jellyseerr
```

Prowlarr and qBittorrent start first (no dependencies), then Sonarr/Radarr wait for both, then Jellyseerr waits for all three.

## CN Network Adaptation

The images `lscr.io/linuxserver/*` and `ghcr.io/*` may be slow in China. Set up Docker mirror:

```bash
# From repo root
./scripts/setup-cn-mirrors.sh
```

Alternative mirrors for LinuxServer images:
- `lscr.io` → `docker.m.daocloud.io/linuxserver/`
- Or set `CN_MODE=true` in `.env` and use the repo's mirror script

## Troubleshooting

### "Permission denied" on media files
```bash
sudo chown -R ${PUID}:${PGID} ${MEDIA_ROOT}
```

### Hardlinks not working (files being copied instead)
- Ensure `torrents/` and `media/` are on the **same filesystem** (same mount point)
- Verify with: `stat -f /path/to/torrents/file && stat -f /path/to/media/file` — same device ID = hardlinks work

### qBittorrent WebUI unreachable
- Check `WEBUI_PORT=8080` is set in environment
- Verify healthcheck passes: `docker compose ps qbittorrent`

### Jellyfin can't see new media
- Trigger a library scan: Dashboard → Libraries → ⟳
- Or restart: `docker compose restart jellyfin`

### Sonarr/Radarr can't connect to qBittorrent
- Use container hostname: `qbittorrent` (not `localhost`)
- Port inside container: `8080`

## Optional: Authentik Forward Auth

To protect services with SSO, add the Authentik middleware to any router label:

```yaml
- "traefik.http.routers.sonarr.middlewares=authentik@file,security-headers@file"
```

This requires the SSO stack to be running. See `stacks/sso/` for setup.
