# Media Stack

> Complete media management suite: Jellyfin · Sonarr · Radarr · Prowlarr · qBittorrent · Jellyseerr

## 🗂️ Directory Structure (TRaSH Guides)

```
/data/
├── media/              ← Jellyfin reads from here (read-only)
│   ├── movies/         ← Radarr hardlinks completed movies here
│   └── tv/             ← Sonarr hardlinks completed episodes here
└── torrents/
    ├── movies/         ← qBittorrent save location for movies category
    └── tv/             ← qBittorrent save location for tv category
```

**Critical:** `MEDIA_ROOT` and `DOWNLOADS_ROOT` must be on the **same filesystem** for hardlinks to function. Hardlinks let Sonarr/Radarr seed without copying files.

## 🚀 Startup

```bash
# 1. Copy and edit environment
cp .env.example .env
nano .env   # set DOMAIN, PUID, PGID, TZ, MEDIA_ROOT, DOWNLOADS_ROOT

# 2. Create directory structure
sudo mkdir -p /data/media/{movies,tv} /data/torrents/{movies,tv}
sudo chown -R $PUID:$PGID /data

# 3. Start stack
docker compose up -d

# 4. Check health
docker compose ps
```

## 🌐 Access URLs

| Service | URL | Default credentials |
|---------|-----|---------------------|
| Jellyfin | `https://jellyfin.DOMAIN` | Create account on first visit |
| Sonarr | `https://sonarr.DOMAIN` | `admin` / `admin123` |
| Radarr | `https://radarr.DOMAIN` | `admin` / `admin123` |
| Prowlarr | `https://prowlarr.DOMAIN` | `admin` / `admin123` |
| qBittorrent | `https://bt.DOMAIN` | `admin` / `adminadmin` |
| Jellyseerr | `https://requests.DOMAIN` | Connects to Jellyfin |

## ⚙️ Service Configuration

### Prowlarr (Indexer Aggregator)

1. Open `https://prowlarr.DOMAIN`
2. Go to **Settings → Indexers → Add**
3. Add your preferred indexers (Torrentio, Jackett, public trackers)
4. Go to **Settings → Apps → Add Sonarr/Radarr**
   - Sonarr URL: `http://sonarr:8989`
   - Radarr URL: `http://radarr:7878`
5. Sync to push indexers automatically

### qBittorrent

1. Open `https://bt.DOMAIN` → login
2. **Change default password immediately** (Options → Web UI)
3. Create category filters:
   - **Movies**: save path `/downloads/movies`, tag `radarr`
   - **TV**: save path `/downloads/tv`, tag `sonarr`
4. Set `torrent.content_layout = Original` in qBittorrent.conf if needed

### Sonarr → qBittorrent

1. Open Sonarr → **Settings → Download Clients → Add**
2. Select **qBittorrent**
   - Host: `qbittorrent`
   - Port: `8080`
   - Username: `admin`
   - Password: (your changed password)
3. **Settings → Media Management**
   - Root folder: `/tv`
   - TV naming: TRaSH naming format recommended
   - Import: ✅ Hardlinks, ⬜ Copy

### Radarr → qBittorrent

1. Open Radarr → **Settings → Download Clients → Add**
2. Select **qBittorrent**
   - Host: `qbittorrent`
   - Port: `8080`
   - Username: `admin`
   - Password: (your changed password)
3. **Settings → Media Management**
   - Root folder: `/movies`
   - Import: ✅ Hardlinks, ⬜ Copy

### Jellyfin Library Setup

1. Open `https://jellyfin.DOMAIN` → Add Library
2. **Movies**: add library pointing to `/media/movies`, enable "Scan my library automatically"
3. **TV Shows**: add library pointing to `/media/tv`
4. Sonarr can auto-update Jellyfin via [JellyfinNotifier](https://wiki.servarr.com/sonarr/custom-scripts#jellyfin-notifier) — set in Sonarr **Connect**

### Jellyseerr (Request Portal)

1. Open `https://requests.DOMAIN`
2. Login with Jellyfin account
3. Connect Jellyfin server: `http://jellyfin:8096`
4. Connect Sonarr/Radarr for auto-approve

## 🔄 Hardlink Flow

```
User requests movie in Jellyseerr
         ↓
Radarr searches via Prowlarr indexers
         ↓
qBittorrent downloads to /data/torrents/movies/
         ↓
Radarr imports (hardlinks) → /data/media/movies/
         ↓
Jellyfin sees new file instantly
```

## 🔧 FAQ

**Q: Hardlinks aren't working — files disappear after seed completes.**
A: `MEDIA_ROOT` and `DOWNLOADS_ROOT` must be on the same filesystem/mount. Run `df -T /data/media /data/torrents` to verify. NFS and some cloud mounts don't support hardlinks.

**Q: Traefik gives 502 Bad Gateway.**
A: Check that the `proxy` network exists: `docker network create proxy`. Verify service health with `docker compose ps`.

**Q: Sonarr/Radarr can't connect to qBittorrent.**
A: Use the **container name** `qbittorrent` as the host (not `localhost`). qBittorrent's WebUI must be bound to `0.0.0.0` (default).

**Q: Downloads complete but don't import.**
A: Check Sonarr/Radarr logs: `docker compose logs sonarr`. Verify qBittorrent category paths match `/downloads/movies` and `/downloads/tv`.

**Q: Jellyfin transcoding issues.**
A: Mount `/dev/dri` (if GPU available) or use Jellyfin's hardware acceleration. For no-transcode setup, ensure downloads match desired quality.

## 📁 Relevant Files

```
stacks/media/
├── docker-compose.yml   # All 6 services
├── .env.example         # Environment template
└── README.md            # This file
```
