# Network Stack

> Network infrastructure stack - AdGuard Home, WireGuard, Cloudflare DDNS, Unbound

## 💰 Bounty

**$120 USDT** - See [BOUNTY.md](../../BOUNTY.md)

## Services

| Service | Image | Purpose |
|---------|-------|---------|
| AdGuard Home | `adguard/adguardhome:v0.107.52` | DNS filtering + ad blocking |
| WireGuard Easy | `ghcr.io/wg-easy/wg-easy:14` | VPN server |
| Cloudflare DDNS | `ghcr.io/favonia/cloudflare-ddns:1.14.0` | Dynamic DNS |
| Unbound | `mvance/unbound:1.21.1` | Recursive DNS resolver |

## Prerequisites

1. **Docker & Docker Compose** installed
2. **Cloudflare** account (for DDNS)
3. **Port 53** available (see [DNS Port Fix](#dns-port-fix))
4. **Port 51820** available for WireGuard

## Quick Start

### 1. Fix DNS port conflict

Port 53 is often used by systemd-resolved. Run:

```bash
# Check port 53 status
sudo ./scripts/fix-dns-port.sh --check

# Apply fix (disables systemd-resolved)
sudo ./scripts/fix-dns-port.sh --apply
```

### 2. Configure environment

```bash
cd stacks/network
cp .env.example .env
# Edit .env with your settings
```

### 3. Start services

```bash
docker compose up -d
```

### 4. Verify services

```bash
docker compose ps
```

## Configuration

### Required Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `WG_HOST` | Your public domain | `vpn.example.com` |
| `WG_PASSWORD` | Web UI password | `your-secure-password` |
| `CF_API_TOKEN` | Cloudflare API Token | `xxxx` |
| `CF_ZONE_ID` | Cloudflare Zone ID | `xxxx` |
| `CF_RECORD_NAME` | Domain to update | `vpn.example.com` |

### Optional Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `TZ` | `Asia/Shanghai` | Timezone |
| `WG_DEFAULT_DNS` | `172.20.0.3` | Client DNS (AdGuard) |
| `WG_DEFAULT_ADDRESS_RANGE` | `10.13.13.0/24` | VPN IP range |
| `WG_ALLOWED_IPS` | `0.0.0.0/0` | Allowed networks |
| `PROXIED` | `true` | Cloudflare proxy |
| `IP6_PREFIX` | - | IPv6 prefix |

## Access URLs

After startup:

| Service | URL |
|---------|-----|
| AdGuard Admin | `http://your-server:3000` |
| WireGuard Web UI | `http://your-server:51821` |

## DNS Port Fix

### Problem

systemd-resolved reserves port 53 for DNS, causing AdGuard Home to fail.

### Solution

Run the provided script:

```bash
# Check current status
sudo ./scripts/fix-dns-port.sh --check

# Apply fix (run as root)
sudo ./scripts/fix-dns-port.sh --apply

# Restore if needed
sudo ./scripts/fix-dns-port.sh --restore
```

The script will:
1. Stop systemd-resolved
2. Disable systemd-resolved from starting
3. Set fallback DNS (8.8.8.8, 8.8.4.4)

## Router DNS Configuration

To use AdGuard Home as your network's DNS server, configure your router:

### Common Router Settings

| Setting | Value |
|---------|-------|
| Primary DNS | Your Server IP (e.g., 192.168.1.100) |
| Secondary DNS | 8.8.8.8 (fallback) |

### Example: AdGuard Home Filter Lists

Recommended filter lists for AdGuard Home:

```
- AdGuard DNS filter
- AdAway Default Blocklist
- NoCoin Filter List
- EasyList (Ads)
- EasyPrivacy (Tracking)
```

## WireGuard Client Configuration

### Generate Client Config

1. Open WireGuard Web UI at `http://your-server:51821`
2. Login with password from `WG_PASSWORD`
3. Click "+" to add new client
4. Download the configuration file or scan QR code

### Connect Client

#### Windows/macOS/Linux
```bash
wg-quick up wg0
# Or import config file in WireGuard app
```

#### Mobile
1. Install WireGuard app
2. Scan QR code
3. Connect

### Split Tunneling

To only route specific traffic through VPN (not all traffic):

1. In WireGuard Web UI, edit client
2. Change `Allowed IPs` from `0.0.0.0/0` to specific subnets:
   ```
   192.168.1.0/24    # Your home network
   10.0.0.0/8        # Internal networks
   ```

## Cloudflare DDNS Setup

### 1. Get Cloudflare API Token

1. Go to Cloudflare Dashboard → Profile → API Tokens
2. Create Custom Token with:
   - **Permissions:** Zone - DNS - Edit
   - **Zone Resources:** All zones (or specific zone)
3. Copy the token

### 2. Get Zone ID

1. Go to your domain in Cloudflare Dashboard
2. Copy Zone ID from the right sidebar

### 3. Configure

Update `.env`:
```
CF_API_TOKEN=your-token
CF_ZONE_ID=your-zone-id
CF_RECORD_NAME=your-domain.com
```

## Unbound Configuration

Unbound runs as a local recursive DNS resolver. AdGuard Home uses Unbound as upstream DNS.

### Default Configuration

The container comes with a reasonable default configuration. To customize, edit:
```
config/unbound/a-records.conf
```

## Troubleshooting

### Check logs

```bash
# AdGuard
docker logs adguard

# WireGuard
docker logs wg-easy

# DDNS
docker logs cloudflare-ddns

# Unbound
docker logs unbound
```

### Common issues

1. **Port 53 in use**
   - Run `sudo ./scripts/fix-dns-port.sh --check`
   - Apply fix if needed

2. **WireGuard client can't connect**
   - Check if port 51820 is forwarded
   - Verify `WG_HOST` is correct (must be public IP/domain)

3. **DDNS not updating**
   - Verify Cloudflare API token has DNS:Edit permission
   - Check DDNS logs for errors

4. **AdGuard not filtering**
   - Ensure DNS port 53 is not used by another service
   - Check filter lists are enabled

## File Structure

```
stacks/network/
├── docker-compose.yml    # Main compose file
├── .env.example         # Environment template
└── README.md            # This file

scripts/
└── fix-dns-port.sh     # DNS port conflict fix
```

## Integration

### With Base Stack

To use with Base Infrastructure (Traefik), ensure both stacks use the same network:

```yaml
# In docker-compose.yml
networks:
  network:
    external: true
    name: proxy
```

Update AdGuard and WireGuard ports to avoid conflicts with Traefik.

## License

MIT
