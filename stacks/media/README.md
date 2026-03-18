# Media Stack

Self-hosted media server with automated content management, following the [TRaSH Guides](https://trash-guides.info/) best practices for hardlinks and atomic moves.

## Architecture

```
Internet
  │
  ▼
Traefik (base stack)
  │
  ├─► media.${DOMAIN}     → Jellyfin      (media server)
  ├─► requests.${DOMAIN}  → Jellyseerr    (request management)
  ├─► sonarr.${DOMAIN}    → Sonarr        (TV series automation)
  ├─► radarr.${DOMAIN}    → Radarr        (movie automation)
  ├─► prowlarr.${DOMAIN}  → Prowlarr      (indexer management)
  └─► bt.${DOMAIN}        → qBittorrent   (download client)
```

## Services

| Service | Version | Port | Description |
|---------|---------|------|-------------|
| Jellyfin | 10.9.11 | 8096 | Media streaming server |
| Jellyseerr | 2.1.1 | 5055 | Media request & discovery |
| Sonarr | 4.0.11 | 8989 | TV series management |
| Radarr | 5.8.1 | 7878 | Movie management |
| Prowlarr | 1.22.0 | 9696 | Indexer aggregation |
| qBittorrent | 4.6.7 | 8080 | BitTorrent client |

## Quick Start

```bash
# 1. Create data directories (TRaSH Guides layout)
sudo mkdir -p /srv/data/{torrents/{movies,tv},media/{movies,tv}}
sudo chown -R 1000:1000 /srv/data

# 2. Configure environment
cp .env.example .env
nano .env      # Set DOMAIN, DATA_ROOT, etc.

# 3. Start all services
docker compose up -d

# 4. Check health
docker compose ps
```

## Directory Structure (TRaSH Guides)

The stack uses a **single root mount** (`DATA_ROOT`) so that Sonarr/Radarr can use **hardlinks** instead of copy+delete when importing completed downloads. This saves disk space and speeds up imports.

```
${DATA_ROOT}/
├── torrents/          ← qBittorrent downloads here
│   ├── movies/        ← Category: movies
│   └── tv/            ← Category: tv
└── media/             ← Organized media library
    ├── movies/        ← Radarr root folder
    └── tv/            ← Sonarr root folder
```

### Why This Matters

| Without hardlinks | With hardlinks (this setup) |
|---|---|
| Download → Copy → Delete original | Download → Hardlink (instant) |
| 2× disk usage during import | 1× disk usage always |
| Slow for large files | Instant regardless of size |

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DOMAIN` | `example.com` | Base domain for Traefik routing |
| `TZ` | `Asia/Shanghai` | Timezone |
| `PUID` | `1000` | Linux user ID (run `id -u`) |
| `PGID` | `1000` | Linux group ID (run `id -g`) |
| `DATA_ROOT` | `/srv/data` | Root data directory |

## Post-Deploy Configuration

### 1. qBittorrent

1. Open `bt.${DOMAIN}`
2. Default credentials: `admin` / check container logs for password:
   ```bash
   docker compose logs qbittorrent 2>&1 | grep "password"
   ```
3. **Settings → Downloads**:
   - Default Save Path: `/data/torrents`
   - Keep incomplete in: `/data/torrents/incomplete`
4. **Settings → Categories**:
   - Add `movies` → Save Path: `/data/torrents/movies`
   - Add `tv` → Save Path: `/data/torrents/tv`

### 2. Prowlarr

1. Open `prowlarr.${DOMAIN}`, create admin account
2. **Settings → Indexers**: Add your preferred indexers
3. **Settings → Apps**: Add Sonarr and Radarr:
   - Sonarr: `http://sonarr:8989`, API key from Sonarr settings
   - Radarr: `http://radarr:7878`, API key from Radarr settings

### 3. Sonarr

1. Open `sonarr.${DOMAIN}`, create admin account
2. **Settings → Media Management**:
   - Root Folder: `/data/media/tv`
   - Enable "Use Hardlinks instead of Copy"
3. **Settings → Download Clients**:
   - Add qBittorrent: Host `qbittorrent`, Port `8080`
   - Category: `tv`
4. **Settings → Profiles**: Configure quality profiles as needed

### 4. Radarr

1. Open `radarr.${DOMAIN}`, create admin account
2. **Settings → Media Management**:
   - Root Folder: `/data/media/movies`
   - Enable "Use Hardlinks instead of Copy"
3. **Settings → Download Clients**:
   - Add qBittorrent: Host `qbittorrent`, Port `8080`
   - Category: `movies`

### 5. Jellyfin

1. Open `media.${DOMAIN}`, complete setup wizard
2. **Add Media Libraries**:
   - Movies: `/data/media/movies`
   - TV Shows: `/data/media/tv`
3. Enable hardware transcoding if GPU available

### 6. Jellyseerr

1. Open `requests.${DOMAIN}`
2. Connect to Jellyfin: URL `http://jellyfin:8096`
3. Connect to Sonarr: URL `http://sonarr:8989` + API key
4. Connect to Radarr: URL `http://radarr:7878` + API key

## Authentik SSO Integration (Optional)

Jellyfin supports OIDC via plugin:

1. Install **SSO-Auth** plugin in Jellyfin (Dashboard → Plugins → Catalog)
2. In Authentik, create an OAuth2/OpenID provider:
   - Client ID: `jellyfin`
   - Redirect URI: `https://media.${DOMAIN}/sso/OID/redirect/authentik`
3. Configure SSO-Auth plugin with the provider details

For Sonarr/Radarr/Prowlarr, use Traefik forward auth with Authentik:

```yaml
# Add to each service's labels:
- traefik.http.routers.sonarr.middlewares=authentik@docker
```

## Startup Order

```
qBittorrent ──► Prowlarr
                  │
                  ├──► Sonarr ──┐
                  │              │
                  └──► Radarr ──┤
                                │
Jellyfin ──────► Jellyseerr ◄──┘
```

Services use `depends_on` with `condition: service_healthy` to ensure correct ordering.

## Troubleshooting

### Permission Denied on Media Files

```bash
# Ensure PUID/PGID match the data directory owner
id    # Check your UID/GID
ls -la /srv/data/
sudo chown -R 1000:1000 /srv/data
```

### Hardlinks Not Working

Hardlinks require the source and destination to be on the **same filesystem**. Verify:

```bash
df /srv/data/torrents /srv/data/media
# Both must show the same filesystem
```

If using separate mounts, consider using bind mounts to unify them under `DATA_ROOT`.

### qBittorrent Shows "Unauthorized"

First-time password is randomly generated. Retrieve it:

```bash
docker compose logs qbittorrent 2>&1 | grep -i "password"
```

### Jellyfin Transcoding Slow

Enable hardware acceleration:
- Intel QSV: Add `--device /dev/dri:/dev/dri` to Jellyfin
- NVIDIA: Use `runtime: nvidia` and install nvidia-container-toolkit

### CN Mirror Alternatives

```yaml
# Replace image sources for faster pulls in China:
# jellyfin:      registry.cn-hangzhou.aliyuncs.com/jellyfin/jellyfin:10.9.11
# linuxserver/*: Use ghcr.io mirrors or configure Docker registry mirror
```

## API Automation Example

```bash
# Search for a movie in Radarr
curl -s "http://radarr:7878/api/v3/movie/lookup?term=inception" \
  -H "X-Api-Key: YOUR_RADARR_API_KEY" | jq '.[0].title'

# Trigger a search in Sonarr
curl -s -X POST "http://sonarr:8989/api/v3/command" \
  -H "X-Api-Key: YOUR_SONARR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"name":"SeriesSearch","seriesId":1}'
```

---

Generated/reviewed with: claude-opus-4-6
