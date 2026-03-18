# Network Stack

Network-wide DNS ad blocking, VPN access, and recursive DNS resolution.

**Components:**
- [AdGuard Home](https://adguard.com/en/adguard-home/overview.html) — DNS-based ad and tracker blocker for all LAN devices
- [WireGuard](https://www.wireguard.com/) (via [wg-easy](https://github.com/wg-easy/wg-easy)) — Modern VPN for secure remote access
- [Unbound](https://nlnetlabs.nl/projects/unbound/) — Recursive DNS resolver (no third-party DNS dependency)

## Quick Start

```bash
cp .env.example .env
nano .env  # Set DOMAIN, WG_HOST, and WG_DASHBOARD_PASSWORD_HASH

# Create WireGuard password hash:
docker run --rm ghcr.io/wg-easy/wg-easy wgpw YOUR_PASSWORD

docker compose up -d
```

## Configuration

### Router DNS

Point your router's DNS server to the host IP to enable network-wide blocking:

```
Router DNS: 192.168.1.x (your server's LAN IP)
```

### AdGuard Setup

1. First startup: navigate to `http://<host>:3000` to complete setup
2. Set upstream DNS to `unbound:5335` for recursive resolution
3. After setup: access via `https://adguard.${DOMAIN}`

### WireGuard VPN

1. Access `https://wg.${DOMAIN}` after startup
2. Create clients via the web UI — QR codes for mobile
3. Port 51820/UDP must be forwarded on your router

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `DOMAIN` | Your base domain (e.g. `home.example.com`) | Yes |
| `WG_HOST` | Public IP or domain for WireGuard | Yes |
| `WG_DASHBOARD_PASSWORD_HASH` | bcrypt hash of WireGuard UI password | Yes |
| `TZ` | Timezone (e.g. `Europe/Berlin`) | Yes |

## Ports

| Port | Protocol | Service |
|------|----------|---------|
| 53 | TCP/UDP | DNS (AdGuard) |
| 853 | TCP | DNS over TLS |
| 51820 | UDP | WireGuard VPN |
