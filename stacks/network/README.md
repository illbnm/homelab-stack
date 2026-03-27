# Network Infrastructure Stack

Self-hosted network services: DNS filtering, VPN, DDNS, and reverse proxy.

## What's Included

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| AdGuard Home | 0.107 | `adguard.<DOMAIN>` | DNS filtering + ad blocking |
| WireGuard Easy | 14 | `wg.<DOMAIN>` | VPN server with Web UI |
| Unbound | 1.21 | internal | Local recursive DNS resolver |
| Cloudflare DDNS | 1.14 | internal | Dynamic DNS updater |
| Nginx Proxy Manager | 2.11 | `npm.<DOMAIN>:8181` | Reverse proxy with Web UI |

## Architecture

```
Internet
    │
    ├──► adguard.<DOMAIN>  → AdGuard Home (DNS:53)
    │       └──► Unbound (upstream) → DNSSEC validation
    │
    ├──► wg.<DOMAIN>        → WireGuard Easy (VPN UDP:51820)
    │       └──► QR code / .conf export for WireGuard clients
    │
    └──► npm.<DOMAIN>:8181 → Nginx Proxy Manager (alternate reverse proxy)

Cloudflare DDNS → Updates DNS A/AAAA records automatically
```

## Prerequisites

- Base Infrastructure stack deployed first (creates `proxy` network)
- Port 53 available (run `scripts/fix-dns-port.sh --check`)
- WireGuard: UDP port 51820 open on firewall
- Cloudflare: API key + domain with Cloudflare

## Quick Start

```bash
cd stacks/network
cp .env.example .env
# Edit .env with your values

# Fix port 53 conflict if needed:
sudo ./scripts/fix-dns-port.sh --apply

docker compose up -d
```

## Configuration

### Environment Variables (`.env`)

| Variable | Required | Description |
|----------|----------|-------------|
| `DOMAIN` | ✅ | Base domain, e.g. `home.example.com` |
| `TZ` | ✅ | Timezone, e.g. `Asia/Shanghai` |
| `WG_HOST` | ✅ | Public IP or domain for WireGuard clients |
| `WG_CLIENT_DNS` | — | DNS pushed to VPN clients (default: 10.8.0.1 = AdGuard) |
| `CF_API_KEY` | ✅ (DDNS) | Cloudflare API key |
| `CF_API_EMAIL` | ✅ (DDNS) | Cloudflare account email |
| `CF_RECORD_TYPES` | — | DNS record types to update (default: A,AAAA) |

### Cloudflare DDNS Setup

1. Get Cloudflare API key from: https://dash.cloudflare.com/profile/api-tokens
2. Create a Global API Key or a custom token with `Zone.DNS: Edit` permission
3. Set `CF_API_KEY` and `CF_API_EMAIL` in `.env`
4. Cloudflare DDNS container will auto-detect your public IP and update records

### WireGuard Client DNS

Set `WG_CLIENT_DNS` to push custom DNS to VPN clients:
- `10.8.0.1` — Use AdGuard Home (filter ads network-wide over VPN)
- Or your preferred DNS server

## DNS Port Conflict Fix

On many Linux systems (Ubuntu, etc.), `systemd-resolved` occupies port 53.
Run the fix script before starting AdGuard Home:

```bash
# Check status
sudo ./scripts/fix-dns-port.sh --check

# Apply fix (disables systemd-resolved)
sudo ./scripts/fix-dns-port.sh --apply

# Restore later if needed
sudo ./scripts/fix-dns-port.sh --restore
```

## Router DNS Configuration

To use AdGuard Home as your network-wide DNS:

1. Log into your router's admin panel
2. Find DNS settings (usually under DHCP or Network settings)
3. Set primary DNS to your server's LAN IP
4. Set secondary DNS to a fallback (e.g., 1.1.1.1)

All devices on your network will now use AdGuard Home for DNS filtering.

## WireGuard Split Tunneling

To allow VPN clients to access both VPN network and local LAN:

```bash
# In .env, add:
WG_ALLOWED_IPS=10.8.0.0/24,192.168.1.0/24
```

This routes VPN subnet (10.8.0.x) and local LAN (192.168.1.x) through the VPN.
Default (0.0.0.0/0) routes ALL traffic through VPN.

## Service URLs

| Service | URL | Default Credentials |
|---------|-----|---------------------|
| AdGuard Home | `http://<server>:3053` (initial setup) | Set on first visit |
| WireGuard Easy | `https://wg.<DOMAIN>` | Set on first visit |
| Nginx Proxy Manager | `http://<server>:8181` | `admin@example.com` / `changeme` |

## Troubleshooting

### AdGuard Home not starting (port 53 conflict)
Run `sudo ./scripts/fix-dns-port.sh --check` to diagnose.
Run `sudo ./scripts/fix-dns-port.sh --apply` to fix.

### WireGuard clients can't connect
- Check UDP port 51820 is open on firewall
- Verify `WG_HOST` points to your actual public IP/domain
- Check WireGuard logs: `docker logs wireguard`

### Cloudflare DDNS not updating
- Verify CF_API_KEY and CF_API_EMAIL are correct
- Ensure the domain is managed by Cloudflare
- Check logs: `docker logs cloudflare-ddns`

### Nginx Proxy Manager vs Traefik

Both provide reverse proxy capabilities. Use NPM for:
- Projects requiring custom Nginx configs
- Quick setups without YAML

Use Traefik (base stack) for:
- Automatic HTTPS with Let's Encrypt
- Docker label-based routing
- Multi-user environments
