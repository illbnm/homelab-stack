# Media Stack

Complete self-hosted media management: stream, automate downloads, and organize movies & TV.

## Services

| Service | URL | Purpose |
|---------|-----|---------|
| Jellyfin | `https://media.${DOMAIN}` | Media streaming server |
| Sonarr | `https://sonarr.${DOMAIN}` | TV series automation |
| Radarr | `https://radarr.${DOMAIN}` | Movie automation |
| Prowlarr | `https://prowlarr.${DOMAIN}` | Indexer management |
| qBittorrent | `https://qbit.${DOMAIN}` | Download client |

## Quick Start

```bash
cp .env.example .env
nano .env   # Set DOMAIN, MEDIA_PATH, DOWNLOAD_PATH

# Create media directories
mkdir -p ${MEDIA_PATH}/movies ${MEDIA_PATH}/tv ${DOWNLOAD_PATH}

# Requires Traefik proxy network (from base stack):
docker network create proxy  # skip if already exists

docker compose up -d
```

## Post-Setup Configuration

1. **qBittorrent**: Change default password at `https://qbit.${DOMAIN}` (admin / adminadmin)
2. **Prowlarr**: Add indexers, then sync to Sonarr and Radarr via "Apps" settings
3. **Sonarr/Radarr**: Add qBittorrent as download client (host: `qbittorrent`, port: `8080`)
4. **Jellyfin**: Add media libraries pointing to `/media/movies` and `/media/tv`

## Optional: GPU Transcoding in Jellyfin

Uncomment the `deploy` section in the `jellyfin` service and ensure NVIDIA Container Toolkit is installed:

```bash
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | \
  sudo tee /etc/apt/sources.list.d/nvidia-docker.list
sudo apt-get update && sudo apt-get install -y nvidia-docker2
sudo systemctl restart docker
```

## Dependencies

- Traefik reverse proxy (base stack)
- Sufficient storage for media files
