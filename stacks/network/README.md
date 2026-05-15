# Network Stack

Network infrastructure for HomeLab — DNS filtering, VPN access, dynamic DNS, and reverse proxy.

## What's Included

| Service | Version | Purpose |
|---------|---------|---------|
| AdGuard Home | v0.107.52 | DNS filtering + ad blocking |
| WireGuard Easy | 14 | VPN server with Web UI |
| Cloudflare DDNS | 1.14.0 | Dynamic DNS updater |
| Unbound | 1.21.1 | Recursive DNS resolver |
| Nginx Proxy Manager | 2.11.3 | Reverse proxy + SSL management |

## Architecture

```
Internet
    │
    ├──► Cloudflare DDNS → keeps DNS records updated
    │
    ▼
[WireGuard :51820/UDP]  ← VPN clients connect here
    │
    ▼
[AdGuard Home :53]  ← DNS filtering (blocks ads/trackers)
    │  upstream DNS
    ▼
[Unbound :5335]  ← Recursive resolver (privacy, no forwarding)
    │
    ▼
Root DNS Servers

[Nginx Proxy Manager :80/:443/:81]  ← Reverse proxy + SSL certs
```

## DNS Chain Explanation

1. **Clients** (LAN devices or VPN clients) send DNS queries to AdGuard Home (`:53`)
2. **AdGuard Home** filters ads/trackers using filter lists, then forwards clean queries to Unbound
3. **Unbound** resolves recursively — no third-party DNS providers see your queries
4. **WireGuard VPN clients** are configured to use AdGuard Home as their DNS server

## Prerequisites

- Docker >= 24.0 with Compose v2 plugin
- Ports 53, 80, 443 available (see `fix-dns-port.sh` for systemd-resolved conflict)
- Port 51820/UDP open on firewall for WireGuard
- A Cloudflare account with API token (for DDNS)
- Base stack deployed first (for Traefik + `proxy` network)

## Quick Start

```bash
# From repo root
cd stacks/network

# Copy and edit environment
cp .env.example .env
nano .env

# Fix DNS port conflict (if systemd-resolved is using port 53)
../../scripts/fix-dns-port.sh --apply

# Create proxy network (if not exists)
docker network create proxy || true

# Launch
docker compose up -d

# Check status
docker compose ps
```

## Configuration

### Environment Variables (`.env`)

| Variable | Required | Description |
|----------|----------|-------------|
| `TZ` | ✅ | Timezone, e.g. `Asia/Shanghai` |
| `DOMAIN` | ✅ | Base domain, e.g. `home.example.com` |
| `WG_HOST` | ✅ | Public IP or domain for WireGuard |
| `WG_PASSWORD_HASH` | ✅ | bcrypt hash for WireGuard Web UI password |
| `WG_PORT` | — | WireGuard UDP port (default: 51820) |
| `WG_DNS` | — | DNS for VPN clients (default: 10.8.0.1) |
| `WG_ALLOWED_IPS` | — | VPN routing (default: `192.168.0.0/16`) |
| `CF_API_TOKEN` | ✅ | Cloudflare API token |
| `CF_DOMAINS` | ✅ | Domain(s) to update |
| `CF_PROXIED` | — | Cloudflare proxy mode (default: `true`) |

### Generate WireGuard Password Hash

```bash
# Method 1: Using wg-easy container
docker run -it ghcr.io/wg-easy/wg-easy wgpw 'YOUR_PASSWORD'

# Method 2: Using htpasswd
echo $(htpasswd -nbB admin 'YOUR_PASSWORD') | sed -e 's/\$/\$\$/g'
```

### Cloudflare API Token Setup

1. Go to https://dash.cloudflare.com/profile/api-tokens
2. Create token with permissions:
   - **Zone > DNS > Edit**
   - **Zone > Zone > Read** (for zone selection)
3. Set zone restrictions to your domain(s)
4. Copy token to `CF_API_TOKEN` in `.env`

### AdGuard Home Initial Setup

1. Access `http://your.server.ip:3000` (first-run wizard)
2. Set admin username/password
3. Configure upstream DNS servers:
   ```
   127.0.0.1:5335
   ```
4. Add filter lists (recommended lists are pre-configured):
   - AdGuard DNS filter
   - EasyList
   - Peter Lowe's Ad and tracking server list
   - Steven Black's unified hosts list

### WireGuard Split Tunneling vs Full Tunnel

**Split Tunnel** (default — only LAN traffic goes through VPN):
```env
WG_ALLOWED_IPS=192.168.0.0/16
```

**Full Tunnel** (all traffic routes through VPN — more secure):
```env
WG_ALLOWED_IPS=0.0.0.0/0
```

### Router DNS Configuration

To use AdGuard Home for your entire network, configure your router:

1. Access your router admin panel
2. Find DHCP/DNS settings
3. Set primary DNS server to your HomeLab server IP
4. Set secondary DNS to `127.0.0.1` or a public DNS (fallback)
5. Renew DHCP leases on client devices

**For popular routers:**

- **OpenWrt**: Network → DHCP and DNS → DNS Forwardings → add `your.server.ip`
- **pfSense**: Services → DNS Resolver → Custom Options → forward to `your.server.ip`
- **UniFi**: Settings → Networks → DHCP Name Server → set to server IP
- **MikroTik**: IP → DNS → Servers → add `your.server.ip`

## Multi-Domain DDNS Configuration

For multiple domains, space-separate them in `CF_DOMAINS`:

```env
CF_DOMAINS=home.example.com vpn.example.com nas.example.com
```

Each domain will be updated with your current public IP every 5 minutes.

## IPv6 Support

Cloudflare DDNS automatically detects and updates both A (IPv4) and AAAA (IPv6) records. Ensure your host has IPv6 connectivity for dual-stack support.

## Firewall Rules

```bash
# WireGuard VPN
sudo ufw allow 51820/udp

# DNS (if serving external clients)
sudo ufw allow 53/tcp
sudo ufw allow 53/udp

# Web UIs (if not behind Traefik)
sudo ufw allow 3000/tcp    # AdGuard setup wizard
sudo ufw allow 8181/tcp    # Nginx Proxy Manager
```

## Troubleshooting

### Port 53 Conflict (systemd-resolved)

```bash
# Check if systemd-resolved is using port 53
sudo ss -tlnp | grep :53

# Use the fix script
../../scripts/fix-dns-port.sh --check    # Check only
../../scripts/fix-dns-port.sh --apply    # Apply fix
../../scripts/fix-dns-port.sh --restore  # Restore original
```

### AdGuard Home Not Starting

```bash
# Check if port 53 is available
sudo ss -tlnp | grep :53

# Check AdGuard logs
docker logs adguardhome

# Verify Unbound is running
docker exec unbound nslookup example.com 127.0.0.1
```

### WireGuard Client Can't Connect

```bash
# Verify WireGuard is running
docker logs wireguard

# Check firewall allows UDP port 51820
sudo ufw status

# Verify WG_HOST is correct (your public IP)
curl -s https://api.ipify.org
```

### DDNS Not Updating

```bash
# Check Cloudflare DDNS logs
docker logs cloudflare-ddns

# Verify API token has correct permissions
curl -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
  -H "Authorization: Bearer YOUR_TOKEN"
```
