# Network Stack

Complete home network infrastructure stack with DNS filtering, VPN, DDNS, and reverse proxy.

## Services

| Service | Port | Purpose |
|---------|------|---------|
| **Unbound** | 53 (UDP+TCP) | Recursive DNS resolver |
| **AdGuard Home** | 3000 (Web UI) | DNS filtering + ad blocking |
| **WireGuard Easy** | 51820 (VPN), 51821 (Web UI) | VPN server |
| **Cloudflare DDNS** | — | Dynamic DNS updater |
| **Nginx Proxy Manager** | 80, 443, 81 | Reverse proxy + SSL |

## Quick Start

```bash
# 1. Edit wireguard env vars
#    - WG_HOST: your public IP or domain
#    - PASSWORD_HASH: generate with `docker run ghcr.io/wg-easy/wg-easy:14 wgpw YOUR_PASSWORD`

# 2. Edit Cloudflare DDNS env vars
#    - CF_API_TOKEN: your Cloudflare API token
#    - DOMAINS: your domain(s)

# 3. Disable systemd-resolved (Linux only)
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved

# 4. Start
docker compose up -d
```

## DNS Flow

```
Client → AdGuard Home (filter) → Unbound (recursive) → Root DNS
```

## Access After Startup

- AdGuard Home: http://localhost:3000
- WireGuard UI: http://localhost:51821
- Nginx Proxy Manager: http://localhost:81
