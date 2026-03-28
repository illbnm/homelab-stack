# Network Stack

AdGuard Home + WireGuard + Nginx Proxy Manager for DNS filtering, VPN access, and reverse proxy management.

## Services

| Service | Port | URL | Purpose |
|---------|------|-----|---------|
| AdGuard Home | 53 (TCP/UDP), 3000 | `http://adguard.DOMAIN:3000` | DNS sinkhole + ad blocking |
| WireGuard Easy | 51820 (UDP), 51821 (HTTP) | `http://wireguard.DOMAIN:51821` | VPN server with Web UI |
| Nginx Proxy Manager | 8181 (HTTP), 8143 (SSL) | `http://nginx.DOMAIN:8181` | Reverse proxy GUI |

## Quick Start

```bash
cd stacks/network
ln -sf ../../.env .env

# Add network-specific variables to .env:
#   WG_HOST=your-public-ip-or-domain.example.com
#   WG_EASY_PASSWORD=your_strong_password
#   DOMAIN=home.example.com

docker compose up -d
```

## DNS Configuration

### Router-Level (Recommended)

Set your router's DNS server to your HomeLab server's IP address. All devices on the network will automatically use AdGuard Home for DNS filtering.

### Device-Level

Point individual device DNS to `<home-lab-ip>:53`.

### systemd-resolved Conflict

On Ubuntu/Debian with systemd-resolved, port 53 is already in use. Fix it:

```bash
# Check the conflict
sudo ./scripts/fix-dns-port.sh --check

# Apply the fix (disables systemd-resolved)
sudo ./scripts/fix-dns-port.sh --apply
# Reboot required after this step
```

## WireGuard VPN

### First-Time Setup

1. Access WireGuard Web UI at `http://wireguard.DOMAIN:51821`
2. Login with `admin@example.com` and your `WG_EASY_PASSWORD`
3. Create client configurations and share QR codes or config files

### Client Configuration

Clients will receive an IP in the `10.8.0.x` range. The VPN tunnel DNS is set to AdGuard Home (`10.8.0.1`) so VPN clients also benefit from ad blocking.

### Split Tunneling

By default, all traffic routes through the VPN (`WG_ALLOWED_IPS=10.8.0.0/24,192.168.0.0/16,172.16.0.0/12`). To allow split tunneling, set `WG_ALLOWED_IPS` to only the internal network ranges you need.

## Nginx Proxy Manager

### First-Time Setup

1. Access NPM at `http://nginx.DOMAIN:8181`
2. Login with default credentials: `admin@example.com` / `changeme`
3. Change the admin password immediately
4. Add proxy hosts by going to "Proxy Hosts" → "Add Proxy Host"

### Integration with Traefik

NPM can run alongside Traefik as a secondary reverse proxy. To avoid port conflicts:
- Traefik uses ports 80/443 (external)
- NPM uses ports 8181/8143 (direct access or via Traefik)

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `DOMAIN` | ✅ | Base domain for service URLs |
| `TZ` | ✅ | Timezone |
| `WG_HOST` | ✅ | Public IP or domain for WireGuard |
| `WG_EASY_PASSWORD` | ✅ | Web UI password (generate: `openssl rand -base64 24`) |
