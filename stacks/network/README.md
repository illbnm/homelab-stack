# Network Stack — DNS, VPN, DDNS

DNS filtering (AdGuard + Unbound), WireGuard VPN, and Cloudflare DDNS for dynamic IPs.

## Services

| Service | Image | URL | Purpose |
|---------|-------|-----|---------|
| AdGuard Home | `adguard/adguardhome:v0.107.55` | `https://adguard.DOMAIN` | DNS filter + ad blocking |
| Unbound | `mvance/unbound:1.21.1` | (internal) | Recursive DNS (upstream for AdGuard) |
| WireGuard Easy | `ghcr.io/wg-easy/wg-easy:14` | `https://vpn.DOMAIN` | VPN server with web UI |
| Cloudflare DDNS | `ghcr.io/favonia/cloudflare-ddns:1.14.0` | — | Dynamic DNS updater |

## Quick Start

```bash
# Fix DNS port 53 conflict
./scripts/fix-dns-port.sh --check
./scripts/fix-dns-port.sh --apply

# Start network stack
cd stacks/network && docker compose up -d

# AdGuard setup
# 1. Open https://adguard.${DOMAIN}
# 2. Setup wizard: set upstream DNS to http://unbound:53
# 3. Enable filters: AdGuard Base, EasyList, etc.

# WireGuard
# 1. Open https://vpn.${DOMAIN}
# 2. Login with WG_PASSWORD
# 3. Add client → download config or scan QR code
```

## DNS Configuration

### Set router DNS to AdGuard

1. Router admin → DHCP settings
2. Set DNS server to your HomeLab server IP
3. Clients will automatically use AdGuard for DNS

### AdGuard Upstream DNS

| Upstream | Address | Purpose |
|----------|---------|--------|
| Unbound (local) | `http://unbound:53` | Recursive, no logs |
| Cloudflare | `https://dns.cloudflare.com/dns-query` | Fast, encrypted |
| Quad9 | `https://dns.quad9.net/dns-query` | Security-focused |

### AdGuard Filter Lists (recommended)

```
https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt
https://easylist.to/easylist/easylist.txt
https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts
```

## WireGuard

### Client Setup

1. Open `https://vpn.${DOMAIN}` → Clients → Add
2. Download `.conf` file or scan QR code
3. Import into WireGuard app ([Android](https://play.google.com/store/apps/details?id=com.wireguard.android) / [iOS](https://apps.apple.com/app/wireguard/id1441195209))

### Split Tunneling

To route only HomeLab services through VPN (not all traffic):

Edit the client config, change `AllowedIPs`:
```
AllowedIPs = 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16
```

## Cloudflare DDNS

### Setup

1. Get API token from [Cloudflare Dashboard](https://dash.cloudflare.com/profile/api-tokens)
2. Set in `.env`:
```bash
CF_API_TOKEN=your_token
CF_ZONE_ID=your_zone_id
CF_RECORD_NAME=home.yourdomain.com
```

### Multiple Domains

Run additional containers with different `CF_RECORD_NAME`.

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `WG_HOST` | Yes | Public IP or domain for WireGuard |
| `WG_PASSWORD` | Yes | WireGuard web UI password |
| `WG_PORT` | No | WireGuard UDP port (default: 51820) |
| `CF_API_TOKEN` | Yes | Cloudflare API token |
| `CF_ZONE_ID` | Yes | Cloudflare zone ID |
| `CF_RECORD_NAME` | Yes | DNS record to update |

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| AdGuard can't start (port 53) | Run `./scripts/fix-dns-port.sh --apply` |
| WireGuard can't connect | Ensure port ${WG_PORT} is forwarded on router |
| DDNS not updating | Check CF_API_TOKEN has Zone:DNS:Edit permission |
| DNS not blocking ads | Add filter lists in AdGuard admin → Filters |