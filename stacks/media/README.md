# Media Stack — Jellyfin + Sonarr + Radarr + Prowlarr + qBittorrent + Jellyseerr

## TRaSH Guides Atomic Hardlink Directory Structure

```text
/data/
├── torrents/
│   ├── movies/
│   └── tv/
└── media/
    ├── movies/
    └── tv/
```

Because `sonarr` and `radarr` mount `/data` as a single volume (`${DATA_ROOT}:/data`), completed downloads in `/data/torrents/{movies,tv}` are atomically hardlinked into `/data/media/{movies,tv}` with zero duplicate disk usage.

## Startup Commands

```bash
mkdir -p /data/torrents/{movies,tv} /data/media/{movies,tv}
cp stacks/media/.env.example stacks/media/.env
docker compose -f stacks/media/docker-compose.yml up -d
```

## Connecting Sonarr / Radarr to qBittorrent

1. Open `https://qb.${DOMAIN}` and set download path to `/data/torrents`.
2. In `https://prowlarr.${DOMAIN}`, add indexers and link `http://sonarr:8989` and `http://radarr:7878`.
3. In Sonarr (`https://sonarr.${DOMAIN}`) and Radarr (`https://radarr.${DOMAIN}`), add Download Client -> qBittorrent (`host: qbittorrent`, `port: 8080`).
4. In Jellyfin (`https://jellyfin.${DOMAIN}`), add Libraries `/data/media/movies` and `/data/media/tv`.

## FAQ

- **Why hardlinks fail?** Ensure `DATA_ROOT` is on a single filesystem and mounted as `/data` inside Sonarr/Radarr.
