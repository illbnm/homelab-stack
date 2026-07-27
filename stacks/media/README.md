# 🎬 Media Stack (Jellyfin + Sonarr + Radarr + Prowlarr + qBittorrent + Jellyseerr)

This stack provides automated movie/TV show requests, indexing, torrent downloading, hardlink organization, and media streaming.

---

## 📦 Services Included

- **Jellyfin (`10.9.11`)**: Open-source media streaming server (`jellyfin.${DOMAIN}`).
- **Sonarr (`4.0.11`)**: TV series management (`sonarr.${DOMAIN}`).
- **Radarr (`5.8.1`)**: Movie management (`radarr.${DOMAIN}`).
- **Prowlarr (`1.22.0`)**: Torrent indexer proxy (`prowlarr.${DOMAIN}`).
- **qBittorrent (`4.6.7`)**: High-performance BitTorrent client (`qbittorrent.${DOMAIN}`).
- **Jellyseerr (`2.1.1`)**: User media request management (`requests.${DOMAIN}`).

---

## 📂 TRaSH Guides Folder Structure & Hardlinks

This setup follows [TRaSH Guides](https://trash-guides.info/Hardlinks/How-to-setup-for/Docker/) for instant atomic moves and zero disk duplication:

```
/data/
├── torrents/       <-- DOWNLOADS_ROOT
│   ├── movies/
│   └── tv/
└── media/          <-- MEDIA_ROOT
    ├── movies/
    └── tv/
```

---

## 🚀 Setup & Launch Instructions

```bash
docker compose -f stacks/media/docker-compose.yml up -d
```

### Sonarr & Radarr Connection Steps:
1. Open Sonarr/Radarr -> **Settings** -> **Download Clients** -> Add **qBittorrent**.
2. Host: `qbittorrent`, Port: `8080`.
3. Open Prowlarr -> **Settings** -> **Applications** -> Add **Sonarr** & **Radarr** for automatic indexer sync.
