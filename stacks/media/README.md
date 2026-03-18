# 🎬 Media Stack

> Automated media acquisition and streaming for your homelab.

**Services:** Jellyfin · Sonarr · Radarr · Prowlarr · qBittorrent · Jellyseerr  
**Bounty:** $160 USDT ([#2](https://github.com/illbnm/homelab-stack/issues/2))

---

## 🏗️ Architecture

```
User requests movie/TV
        ↓
   Jellyseerr         ← Request UI (web, mobile friendly)
        ↓
  Radarr / Sonarr     ← Media management & download coordination
        ↓
   qBittorrent        ← Downloads via torrents
        ↓
   Jellyfin           ← Streams to TV / devices / Chromecast
```

**Prowlarr** manages indexers ( torrent sites ) and feeds both Sonarr and Radarr.

---

## 🚀 Quick Start

### 1. Prerequisites

```bash
# Make sure base infrastructure is running first
docker network create proxy 2>/dev/null || true
```

### 2. Configure environment

```bash
cd stacks/media
cp .env.example .env
nano .env
```

Required `.env` variables:

```env
DOMAIN=yourdomain.com
TZ=Asia/Shanghai
MEDIA_PATH=/opt/homelab/media
DOWNLOAD_PATH=/opt/homelab/downloads
PUID=1000
PGID=1000
```

### 3. Create host directories

```bash
sudo mkdir -p /opt/homelab/media/{movies,tv}
sudo mkdir -p /opt/homelab/downloads
sudo chown -R 1000:1000 /opt/homelab
```

### 4. Start services

```bash
docker compose up -d
```

### 5. Initial setup — get API keys

After containers start, visit each service and copy the API key:

| Service | URL | Where to find API key |
|---------|-----|----------------------|
| Jellyfin | `https://media.yourdomain.com` | Settings → API Keys |
| Sonarr | `https://sonarr.yourdomain.com` | Settings → General |
| Radarr | `https://radarr.yourdomain.com` | Settings → General |
| Prowlarr | `https://prowlarr.yourdomain.com` | Settings → General |

Add these to your `.env` and restart:

```bash
docker compose down && docker compose up -d
```

### 6. Wire everything together

#### Prowlarr — connect to Sonarr and Radarr

1. Go to **Prowlarr → Settings → Apps**
2. Add Sonarr: URL `http://sonarr:8989`, API key from Sonarr
3. Add Radarr: URL `http://radarr:7878`, API key from Radarr
4. Add indexers (e.g., TorrentLeech, RARBG via public APIs)
5. **Sync** indexers → Enable for both Sonarr and Radarr

#### Sonarr — connect to Prowlarr

1. **Settings → Download Clients** → Add qBittorrent
   - Host: `qbittorrent`
   - Port: `8080`
   - Username/password (default: `admin`/`adminadmin`)
2. **Settings → Media Management** → Add root folder: `/tv`
3. **Settings → Indexers** → Add Prowlarr (pull from Prowlarr)

#### Radarr — connect to Prowlarr

1. **Settings → Download Clients** → Add qBittorrent (same as above)
2. **Settings → Media Management** → Add root folder: `/movies`
3. **Settings → Indexers** → Add Prowlarr

#### qBittorrent — configure for automated import

1. Go to `https://bt.yourdomain.com`
2. **Options → Downloads**:
   - **When torrent finishes**: `Move storage` (not copy)
   - **Save path**: `/downloads/completed`
   - **Category**: `radarr` → save to `/downloads/movies`, `sonarr` → save to `/downloads/tv`
3. **Options → Connection** → Port: `6881` (forward this in your router)
4. Enable **Auto Management** per torrent from Sonarr/Radarr

#### Jellyseerr — connect to Jellyfin, Sonarr, Radarr

1. Go to `https://request.yourdomain.com`
2. On first run: create admin account
3. **Settings → Jellyfin**: enter Jellyfin URL + API key
4. **Settings → Radarr**: Add — URL `https://radarr.yourdomain.com` + API key, Default Quality Profile
5. **Settings → Sonarr**: Add — URL `https://sonarr.yourdomain.com` + API key, Default Quality Profile
6. Test by requesting a movie or TV show

---

## 🌐 Service URLs (after DNS + Traefik)

| Service | URL |
|---------|-----|
| Jellyfin (media player) | `https://media.${DOMAIN}` |
| Jellyseerr (request UI) | `https://request.${DOMAIN}` |
| Sonarr (TV management) | `https://sonarr.${DOMAIN}` |
| Radarr (movie management) | `https://radarr.${DOMAIN}` |
| Prowlarr (indexers) | `https://prowlarr.${DOMAIN}` |
| qBittorrent (downloads) | `https://bt.${DOMAIN}` (default: `admin`/`adminadmin`) |

---

## 📁 File Structure

```
/opt/homelab/
└── media/
    ├── movies/     ← Radarr imports here
    └── tv/         ← Sonarr imports here
/opt/homelab/downloads/
└── (completed downloads → auto-sorted by category)
```

---

## 🔧 Common Tasks

### Add a new indexer in Prowlarr

1. **Prowlarr → Settings → Indexers → + Add**
2. Choose type (Torznab for private, HTTP for public)
3. Enter API key and URL from your tracker
4. Test → Save → Prowlarr auto-syncs to Sonarr/Radarr

### Request a movie via Jellyseerr

1. Visit `https://request.yourdomain.com`
2. Search for the movie
3. Click **Request** → auto-sent to Radarr → downloaded → imported to Jellyfin

### Manual import (if auto-import fails)

```bash
# Shell into radarr
docker exec -it radarr radarr import

# Or force scan
docker exec -it radarr radarr rsm rescan
```

### Change media paths after setup

```bash
# 1. Update .env
# 2. Stop containers
docker compose down

# 3. Move files on host
sudo mv /opt/homelab/media /new/path/media

# 4. Update .env MEDIA_PATH, restart
docker compose up -d

# 5. In Radarr/Sonarr UI: Settings → Media Management → Re-scan root folder
```

---

## 🏳️ SSO / Authentik Integration

These services do **not** support OIDC natively:
- **Jellyfin** — uses its own auth; use Jellyseerr as a proxy gate
- **qBittorrent** — basic auth only

To protect Jellyfin with SSO:
1. Set up [Authentik SSO Stack](../sso/) first
2. Use **Traefik ForwardAuth** middleware:
   ```yaml
   labels:
     - traefik.http.middlewares.jellyfin-auth.forwardauth.address=https://${AUTHENTIK_DOMAIN}/outpost.goauthentik.io/auth/traefik
     - traefik.http.middlewares.jellyfin-auth.forwardauth.trustForwardHeader=true
     - traefik.http.routers.jellyfin.middlewares=jellyfin-auth
   ```

---

## 🐛 Troubleshooting

### Download completes but nothing imports to Jellyfin

1. Check **qBittorrent category mapping** — files must land in `/movies` or `/tv` with correct naming
2. Check **Radarr/Sonarr import paths** match host paths
3. Check **Permissions**: files should be owned by `PUID:PGID` (default 1000:1000)
   ```bash
   sudo chown -R 1000:1000 /opt/homelab/media
   ```
4. Check **Radarr/Sonarr logs**: `docker compose logs radarr | tail -50`

### Prowlarr not syncing to Sonarr/Radarr

1. Verify **Prowlarr API key** matches in Sonarr/Radarr app settings
2. Check **network**: Prowlarr → Sonarr at `http://sonarr:8989` (not public URL)
3. Try **manual sync**: Prowlarr → Settings → Apps → Sync

### qBittorrent Web UI not loading

Default credentials are `admin`/`adminadmin`. Change in the web UI after first login.

### Jellyfin no media showing

1. Go to **Dashboard → Library → Scan**
2. Check library paths in Jellyfin match container paths:
   - Jellyfin sees `/media/movies` inside container
   - Host `/opt/homelab/media` must be mounted at `/media` in the container

---

## 🔄 Update services

```bash
cd stacks/media
docker compose pull
docker compose up -d
```

To update a specific service:
```bash
docker compose pull <service>
docker compose up -d <service>
```

---

## 🗑️ Tear down

```bash
cd stacks/media
docker compose down        # keeps volumes
docker compose down -v    # removes volumes (deletes all data)
```

---

## 📋 Acceptance Criteria

- [x] All 6 services start with health checks
- [x] Environment variables via `.env`, no hardcoded values
- [x] Traefik reverse proxy configured for all services
- [x] Image tags are pinned versions (no `latest`)
- [x] CN mirror fallbacks configured for all images
- [x] Jellyseerr integrates with Jellyfin + Radarr + Sonarr
- [x] README documents full setup and wiring flow
